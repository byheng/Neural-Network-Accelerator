/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
    module_intro: make a 3*3 kernel to convolution
    state       : simulation finish
                  LION WORK FINISH
                  NEUFLOW
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module PE_array #(
    parameter FEATURE_WIDTH       = `FEATURE_WIDTH, // 16
    parameter WEIGHT_WIDTH        = `WEIGHT_WIDTH, // 16
    parameter PE_NUM_PRE_CORE     = `PE_NUM_PRE_CORE, // 3
    parameter PE_ARRAY_TOTAL_SIZE = PE_NUM_PRE_CORE * PE_NUM_PRE_CORE, // 9
    parameter MAC_OUTPUT_WIDTH    = `MAC_OUTPUT_WIDTH,
    parameter PE_CORE_NUM         = `PE_CORE_NUM, // 16 
    parameter BIAS_WIDTH          = WEIGHT_WIDTH + FEATURE_WIDTH // 32
)
(
    input                                                   DSP_clk     ,
    input                                                   rst_n       , 
    input [WEIGHT_WIDTH*PE_CORE_NUM-1:0]                    weight      , // 多个 weight 数据，PE_CORE_NUM 个 weight
    input                                                   weight_valid,     
    input [FEATURE_WIDTH*PE_NUM_PRE_CORE*PE_CORE_NUM-1:0]   feature_in  , // 多个特征图数据，特征图位宽 * PE_NUM_PRE_CORE * PE_CORE_NUM      
    input [BIAS_WIDTH-1:0]                                  bias        ,
    input [MAC_OUTPUT_WIDTH-1:0]                            adder_feature, // adder_feature可能用于残差连接?
    input                                                   bias_or_adder_feature,     
    input                                                   bias_valid  , 
    input                                                   pulse       ,           
    output[MAC_OUTPUT_WIDTH*PE_CORE_NUM-1:0]                feature_out  
);

wire [MAC_OUTPUT_WIDTH-1:0]                 feature_out_core  [PE_CORE_NUM-1:0]; // 16个PE_core的输出
wire [WEIGHT_WIDTH-1:0]                     weight_distribute [PE_CORE_NUM-1:0]; // 16个PE_core的weight输入, 每个PE_core的weight打拍输入
wire [FEATURE_WIDTH*PE_NUM_PRE_CORE-1:0]    feature_in_core   [PE_CORE_NUM-1:0]; // 16个PE_core的 feature_in 输入，每个PE_core列方向上的 feature_in 一次性输入

// 将 weight 分配给 16 个 PE_core
genvar i;
generate
    for(i=0; i<PE_CORE_NUM; i=i+1) begin : weight_core_gen
        assign weight_distribute[i] = weight[(i+1)*WEIGHT_WIDTH-1:i*WEIGHT_WIDTH];
    end
endgenerate

// 实例化 16 个 PE_core
generate
    for(i=0; i<PE_CORE_NUM; i=i+1) begin : PE_array_gen
        // 每个 PE_core 的 feature_in 输入, 每个 PE_core 列方向上的 feature_in(3个feature) 一次性输入
        assign feature_in_core[i]   = feature_in[(i+1)*FEATURE_WIDTH*PE_NUM_PRE_CORE-1:i*FEATURE_WIDTH*PE_NUM_PRE_CORE];
        if (i==0) begin
            PE_core u_PE_core(
                .DSP_clk                ( DSP_clk             ),
                .rst_n                  ( rst_n               ),
                .weight                 ( weight_distribute[i]),
                .weight_valid           ( weight_valid        ),
                .feature_in             ( feature_in_core[i]  ),
                .bias                   ( bias                ), // 只有第一个 PE_core 需要 bias 输入，每个输出通道只需要添加一次偏置值
                .bias_valid             ( bias_valid          ),
                .adder_feature          ( adder_feature       ), // 第一个的 PE_core 需要 adder_feature 输入
                .bias_or_adder_feature  ( bias_or_adder_feature),
                .pulse                  ( pulse               ),
                .feature_out            ( feature_out_core[i] )
            );
        end
        else begin
            PE_core u_PE_core(
                .DSP_clk                ( DSP_clk                   ),
                .rst_n                  ( rst_n                     ),
                .weight                 ( weight_distribute[i]      ),
                .weight_valid           ( weight_valid              ),
                .feature_in             ( feature_in_core[i]        ),
                .bias                   ( {{BIAS_WIDTH{1'b0}}}      ), // 其他的 PE_core 不需要 bias 输入
                .bias_valid             ( 1'b0                      ),
                .adder_feature          ( {{MAC_OUTPUT_WIDTH{1'b0}}}), // 其他的 PE_core 不需要 adder_feature 输入
                .bias_or_adder_feature  ( 1'b0                      ),
                .pulse                  ( pulse                     ),
                .feature_out            ( feature_out_core[i]       )
            );
        end
    end
endgenerate

// assign feature_out = {feature_out_core[7], feature_out_core[6], feature_out_core[5], feature_out_core[4], feature_out_core[3], feature_out_core[2], feature_out_core[1], feature_out_core[0]};

// 将 16 个 PE_core 的输出 feature_out_core 拼接成最终的 feature_out 输出
generate
    for (i=0; i<PE_CORE_NUM; i=i+1) begin : feature_out_assign_gen
        assign feature_out[(i+1)*MAC_OUTPUT_WIDTH-1:i*MAC_OUTPUT_WIDTH] = feature_out_core[i];
    end
endgenerate

endmodule