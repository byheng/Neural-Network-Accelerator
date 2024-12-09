/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module feature_row_Cache #(
    parameter FEATURE_WIDTH     = `FEATURE_WIDTH,
    parameter PE_CORE_NUM       = `PE_CORE_NUM,
    parameter FETURE_DATA_WIDTH = `PE_CORE_NUM * `FEATURE_WIDTH
)(
    input                           system_clk            ,
    input                           rst_n                 ,
    // input data path
    input [FETURE_DATA_WIDTH-1:0]   feature_output_data   ,
    input                           feature_output_valid  ,
    // output data path
    output[FETURE_DATA_WIDTH*3-1:0] feature_cache_data    ,
    output                          feature_cache_valid   ,
    // input control signal
    input                           rebuild_structure     ,
    input [9:0]                     col_size              
);

wire [FEATURE_WIDTH-1:0]    feature_data_depacked[PE_CORE_NUM-1:0];
wire [FEATURE_WIDTH*2-1:0]  feature_data_cache_in[PE_CORE_NUM-1:0];
wire [FEATURE_WIDTH*2-1:0]  feature_data_cache_out[PE_CORE_NUM-1:0];

// depack input data
genvar i;
generate
    for (i=0; i<PE_CORE_NUM; i=i+1) begin : gen_depack
        assign feature_data_depacked[i] = feature_output_data[(i+1)*FEATURE_WIDTH-1:i*FEATURE_WIDTH];
    end
endgenerate

// Cache fifo
generate
    for (i=0; i<PE_CORE_NUM; i=i+1) begin : gen_fifo
        ram_base_shift_register_for_cache u_ram_base_shift_register_for_cache(
            .system_clk 	( system_clk                ),
            .rst_n      	( rst_n                     ),
            .wr_en      	( feature_output_valid      ),
            .wr_data    	( feature_data_cache_in[i]  ),
            .rd_data    	( feature_data_cache_out[i] ),
            .shift_size 	( col_size                  )
        );

        if (i<8) begin
            assign feature_data_cache_in[i] = {feature_data_cache_out[i][FEATURE_WIDTH-1:0], feature_data_depacked[i]};
        end
        else begin
            assign feature_data_cache_in[i] = (rebuild_structure) ? {feature_data_cache_out[i][FEATURE_WIDTH-1:0], feature_data_cache_out[i-8][2*FEATURE_WIDTH-1:FEATURE_WIDTH]} : {feature_data_cache_out[i][FEATURE_WIDTH-1:0], feature_data_depacked[i]};
        end
        assign feature_cache_data[(i+1)*FEATURE_WIDTH*3-1:i*FEATURE_WIDTH*3] = {feature_data_cache_out[i], feature_data_depacked[i]};
    end
endgenerate

assign feature_cache_valid = feature_output_valid;

// just for debug
wire [FEATURE_WIDTH*3-1:0] feature_cache_data_depacked[PE_CORE_NUM-1:0];
wire [FEATURE_WIDTH-1:0] feature_cache_data_depacked_line[2:0];
generate if (`debug == 1)
    for (i=0; i<PE_CORE_NUM; i=i+1) begin : gen_depack_cache_data
        assign feature_cache_data_depacked[i] = feature_cache_data[(i+1)*FEATURE_WIDTH*3-1:i*FEATURE_WIDTH*3];
    end

    for (i=0; i<3; i=i+1) begin : gen_depack_cache_data_line
        assign feature_cache_data_depacked_line[i] = feature_cache_data_depacked[0][i*FEATURE_WIDTH+:FEATURE_WIDTH];
    end
endgenerate

endmodule