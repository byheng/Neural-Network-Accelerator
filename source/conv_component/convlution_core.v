/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
    module_intro: make a 3*3 kernel to convolution
    state       : simulation finish
                  LION WORK FINISH
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module convolution_core #(
    parameter FEATURE_WIDTH       = `FEATURE_WIDTH, // 16
    parameter WEIGHT_WIDTH        = `WEIGHT_WIDTH,  // 16
    parameter PE_NUM_PRE_CORE     = `PE_NUM_PRE_CORE, // 3
    parameter PE_ARRAY_TOTAL_SIZE = PE_NUM_PRE_CORE * PE_NUM_PRE_CORE, // 9
    parameter MAC_OUTPUT_WIDTH    = `MAC_OUTPUT_WIDTH, // 36
    parameter PE_CORE_NUM         = `PE_CORE_NUM, // 16
    parameter BIAS_WIDTH          = WEIGHT_WIDTH + FEATURE_WIDTH // 32
)(
    input                                                   DSP_clk     ,
    input                                                   rst_n       , 
    input [WEIGHT_WIDTH*PE_CORE_NUM-1:0]                    weight      , // 16个 weight 数据, 
    input [7:0]                                             weight_valid, // 8 个 weight_valid 信号   
    input [FEATURE_WIDTH*PE_NUM_PRE_CORE*PE_CORE_NUM-1:0]   feature_in  , // 多个特征图数据，特征图位宽 * PE_NUM_PRE_CORE * PE_CORE_NUM
    input [BIAS_WIDTH*8-1:0]                                bias        , // 8 个 bias 数据
    input                                                   bias_valid  ,
    input [MAC_OUTPUT_WIDTH*8-1:0]                          adder_feature, // 8 个 adder_feature 数据
    input                                                   bias_or_adder_feature,
    input                                                   pulse       ,        
    output[MAC_OUTPUT_WIDTH*8-1:0]                          feature_out 
);

wire [MAC_OUTPUT_WIDTH*PE_CORE_NUM-1:0] feature_out_temp[7:0]; // 8 个 PE_array 的输出，每个 PE_array 输出 MAC_OUTPUT_WIDTH*PE_CORE_NUM 位宽数据

/*
时分复用的权重加载机制
weight_valid[i]信号控制每个PE_array在不同时刻加载权重：
当weight_valid[0]=1时，PE_array[0]加载当前的weight数据
当weight_valid[1]=1时，PE_array[1]加载当前的weight数据
以此类推...
这意味着每个PE_array在不同时间加载不同的卷积核权重。

所有PE_array同时处理相同的feature_in 但使用各自存储的不同卷积核进行计算
输入特征图 (共享) → PE_array[0] (卷积核0) → 输出通道0
                → PE_array[1] (卷积核1) → 输出通道1  
                → PE_array[2] (卷积核2) → 输出通道2
                → ...
                → PE_array[7] (卷积核7) → 输出通道7
*/
genvar i;
generate
    for(i = 0; i < 8; i = i + 1) begin: PE_core_gen
        PE_array u_PE_array(
            .DSP_clk      	        ( DSP_clk                                               ),
            .rst_n        	        ( rst_n                                                 ),
            .weight       	        ( weight                                                ),
            .weight_valid 	        ( weight_valid[i]                                       ),
            .feature_in   	        ( feature_in                                            ),
            .bias         	        ( bias[i*BIAS_WIDTH+:BIAS_WIDTH]                        ),
            .adder_feature	        ( adder_feature[i*MAC_OUTPUT_WIDTH+:MAC_OUTPUT_WIDTH]   ),
            .bias_or_adder_feature  ( bias_or_adder_feature                                 ),
            .bias_valid   	        ( bias_valid                                            ),
            .pulse        	        ( pulse                                                 ),
            .feature_out  	        ( feature_out_temp[i]                                   )  
        );

        add_tree u_add_tree(
            .system_clk 	( DSP_clk                                           ),
            .rst_n      	( rst_n                                             ),
            .in_data    	( feature_out_temp[i]                               ),
            .data_out   	( feature_out[i*MAC_OUTPUT_WIDTH+:MAC_OUTPUT_WIDTH] )                
        );
    end
endgenerate

// just for debug
wire [MAC_OUTPUT_WIDTH-1:0] debug_feature_out[7:0];
generate if (`debug == 1)
    for(i=0;i<8;i=i+1) begin: debug_gen
        assign debug_feature_out[i] = feature_out[i*MAC_OUTPUT_WIDTH+:MAC_OUTPUT_WIDTH];
    end
endgenerate

endmodule