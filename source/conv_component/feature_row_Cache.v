/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module feature_row_Cache #(
    parameter FEATURE_WIDTH     = `FEATURE_WIDTH,     // 单个特征的位宽
    parameter PE_CORE_NUM       = `PE_CORE_NUM,      // PE核心数量（16个）
    parameter FETURE_DATA_WIDTH = `PE_CORE_NUM * `FEATURE_WIDTH, // 总特征数据位宽
    parameter POOL_DATA_WIDTH   = 5 * `FEATURE_WIDTH // 池化数据位宽（5行特征）
)(
    input                           system_clk            ,
    input                           rst_n                 ,
    // input data path
    input [FETURE_DATA_WIDTH-1:0]   feature_output_data   , // 来自 feature_buffer 的16通道特征数据
    input                           feature_output_valid  , // feature_output_data 有效标志
    // output data path
    output[FETURE_DATA_WIDTH*3-1:0] feature_cache_data    , // 3行卷积缓存数据（16通道 × 3行），每个PE分配三个特征数据
    output[POOL_DATA_WIDTH*8-1:0]   pool_cache_data       , // 池化缓存数据（5行特征 × 8个通道）
    output                          feature_cache_valid   , // feature_cache_data 有效标志
    // input control signal
    input                           rebuild_structure     , // 重构结构控制信号，用于池化模式
    input [9:0]                     col_size                // 特征数据的列数（宽度），决定移位寄存器的深度
);

wire [FEATURE_WIDTH-1:0]    feature_data_depacked[PE_CORE_NUM-1:0]; // 分解后每个PE的特征数据
wire [FEATURE_WIDTH*2-1:0]  feature_data_cache_in[PE_CORE_NUM-1:0];
wire [FEATURE_WIDTH*2-1:0]  feature_data_cache_out[PE_CORE_NUM-1:0];

// depack input data
// 将 feature_output_data 分解为每个 PE 核的特征数据
genvar i;
generate
    for (i=0; i<PE_CORE_NUM; i=i+1) begin : gen_depack
        assign feature_data_depacked[i] = feature_output_data[(i+1)*FEATURE_WIDTH-1:i*FEATURE_WIDTH];
    end
endgenerate

// Cache fifo
generate
    for (i=0; i<PE_CORE_NUM; i=i+1) begin : gen_fifo
        // 每个 PE 都有一个基于RAM的移位寄存器
        ram_base_shift_register_for_cache u_ram_base_shift_register_for_cache(
            .system_clk 	( system_clk                ),
            .rst_n      	( rst_n                     ),
            .wr_en      	( feature_output_valid      ),
            .wr_data    	( feature_data_cache_in[i]  ),
            .rd_data    	( feature_data_cache_out[i] ),
            .shift_size 	( col_size                  )
        );

        if (i<8) begin
            // 前8个PE直接使用当前行数据
            assign feature_data_cache_in[i] = {feature_data_cache_out[i][FEATURE_WIDTH-1:0], feature_data_depacked[i]};
        end
        else begin
            assign feature_data_cache_in[i] = (rebuild_structure) ? 
                {feature_data_cache_out[i][FEATURE_WIDTH-1:0], feature_data_cache_out[i-8][2*FEATURE_WIDTH-1:FEATURE_WIDTH]} : // 重构结构时复用前8个PE的数据
                {feature_data_cache_out[i][FEATURE_WIDTH-1:0], feature_data_depacked[i]}; // 正常情况下使用当前行数据
        end
        assign feature_cache_data[(i+1)*FEATURE_WIDTH*3-1:i*FEATURE_WIDTH*3] = // 为每个PE分配三个特征数据
            {feature_data_depacked[i], 
            feature_data_cache_out[i][FEATURE_WIDTH-1:0], 
            feature_data_cache_out[i][2*FEATURE_WIDTH-1:FEATURE_WIDTH]};
    end
endgenerate

assign feature_cache_valid = feature_output_valid;

// just for debug
wire [FEATURE_WIDTH*3-1:0] feature_cache_data_depacked[PE_CORE_NUM-1:0];
wire [FEATURE_WIDTH-1:0] feature_cache_data_depacked_line[2:0];
wire [FEATURE_WIDTH-1:0] feature_cache_data_depacked_line2[2:0];
generate if (`debug == 1)
    for (i=0; i<PE_CORE_NUM; i=i+1) begin : gen_depack_cache_data
        assign feature_cache_data_depacked[i] = feature_cache_data[(i+1)*FEATURE_WIDTH*3-1:i*FEATURE_WIDTH*3];
    end

    for (i=0; i<3; i=i+1) begin : gen_depack_cache_data_line
        assign feature_cache_data_depacked_line[i] = feature_cache_data_depacked[0][i*FEATURE_WIDTH+:FEATURE_WIDTH];
        assign feature_cache_data_depacked_line2[i] = feature_cache_data_depacked[8][i*FEATURE_WIDTH+:FEATURE_WIDTH];
    end
endgenerate

// 5-row pool cache output
wire [POOL_DATA_WIDTH-1:0] pool_cache_data_depacked[7:0];
generate
    for (i=0; i<8; i=i+1) begin : gen_depack_pool_data
        assign pool_cache_data_depacked[i] = {feature_data_cache_out[8+i][2*FEATURE_WIDTH-1:FEATURE_WIDTH], feature_data_cache_out[8+i][FEATURE_WIDTH-1:0], feature_data_cache_out[i][2*FEATURE_WIDTH-1:FEATURE_WIDTH], feature_data_cache_out[i][FEATURE_WIDTH-1:0], feature_data_depacked[i]};
        assign pool_cache_data[i*POOL_DATA_WIDTH+:POOL_DATA_WIDTH] = pool_cache_data_depacked[i];
    end
endgenerate


endmodule