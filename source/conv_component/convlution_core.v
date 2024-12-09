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
    parameter FEATURE_WIDTH       = `FEATURE_WIDTH,
    parameter WEIGHT_WIDTH        = `WEIGHT_WIDTH,
    parameter PE_NUM_PRE_CORE     = `PE_NUM_PRE_CORE,
    parameter PE_ARRAY_TOTAL_SIZE = PE_NUM_PRE_CORE * PE_NUM_PRE_CORE,
    parameter MAC_OUTPUT_WIDTH    = `MAC_OUTPUT_WIDTH,
    parameter PE_CORE_NUM         = `PE_CORE_NUM,
    parameter BIAS_WIDTH          = WEIGHT_WIDTH + FEATURE_WIDTH
)(
    input                                                   DSP_clk     ,
    input                                                   rst_n       , 
    input [WEIGHT_WIDTH*PE_CORE_NUM-1:0]                    weight      , 
    input [7:0]                                             weight_valid,     
    input [FEATURE_WIDTH*PE_NUM_PRE_CORE*PE_CORE_NUM-1:0]   feature_in  ,      
    input [BIAS_WIDTH*8-1:0]                                bias        ,
    input                                                   bias_valid  ,
    input [MAC_OUTPUT_WIDTH*8-1:0]                          adder_feature,
    input                                                   bias_or_adder_feature,
    input                                                   pulse       ,        
    output[MAC_OUTPUT_WIDTH*8-1:0]                          feature_out 
);

wire [MAC_OUTPUT_WIDTH*PE_CORE_NUM-1:0] feature_out_temp[7:0];

genvar i;
generate
    for(i=0;i<8;i=i+1) begin: PE_core_gen
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