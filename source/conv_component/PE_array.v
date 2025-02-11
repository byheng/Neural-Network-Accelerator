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
    parameter FEATURE_WIDTH       = `FEATURE_WIDTH,
    parameter WEIGHT_WIDTH        = `WEIGHT_WIDTH,
    parameter PE_NUM_PRE_CORE     = `PE_NUM_PRE_CORE,
    parameter PE_ARRAY_TOTAL_SIZE = PE_NUM_PRE_CORE * PE_NUM_PRE_CORE,
    parameter MAC_OUTPUT_WIDTH    = `MAC_OUTPUT_WIDTH,
    parameter PE_CORE_NUM         = `PE_CORE_NUM,
    parameter BIAS_WIDTH          = WEIGHT_WIDTH + FEATURE_WIDTH
)
(
    input                                                   DSP_clk     ,
    input                                                   rst_n       , 
    input [WEIGHT_WIDTH*PE_CORE_NUM-1:0]                    weight      , 
    input                                                   weight_valid,     
    input [FEATURE_WIDTH*PE_NUM_PRE_CORE*PE_CORE_NUM-1:0]   feature_in  ,      
    input [BIAS_WIDTH-1:0]                                  bias        ,
    input [MAC_OUTPUT_WIDTH-1:0]                            adder_feature, 
    input                                                   bias_or_adder_feature,     
    input                                                   bias_valid  , 
    input                                                   pulse       ,           
    output[MAC_OUTPUT_WIDTH*PE_CORE_NUM-1:0]                feature_out  
);

wire [MAC_OUTPUT_WIDTH-1:0]                 feature_out_core  [PE_CORE_NUM-1:0];
wire [WEIGHT_WIDTH-1:0]                     weight_distribute [PE_CORE_NUM-1:0];
wire [FEATURE_WIDTH*PE_NUM_PRE_CORE-1:0]    feature_in_core   [PE_CORE_NUM-1:0];

genvar i;
generate
    for(i=0; i<PE_CORE_NUM; i=i+1) begin : weight_core_gen
        assign weight_distribute[i] = weight[(i+1)*WEIGHT_WIDTH-1:i*WEIGHT_WIDTH];
    end
endgenerate

generate
    for(i=0; i<PE_CORE_NUM; i=i+1) begin : PE_array_gen
        assign feature_in_core[i]   = feature_in[(i+1)*FEATURE_WIDTH*PE_NUM_PRE_CORE-1:i*FEATURE_WIDTH*PE_NUM_PRE_CORE];
        if (i==0) begin
            PE_core u_PE_core(
                .DSP_clk                ( DSP_clk             ),
                .rst_n                  ( rst_n               ),
                .weight                 ( weight_distribute[i]),
                .weight_valid           ( weight_valid        ),
                .feature_in             ( feature_in_core[i]  ),
                .bias                   ( bias                ),
                .bias_valid             ( bias_valid          ),
                .adder_feature          ( adder_feature       ),
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
                .bias                   ( {{BIAS_WIDTH{1'b0}}}      ),
                .bias_valid             ( 1'b0                      ),
                .adder_feature          ( {{MAC_OUTPUT_WIDTH{1'b0}}}),
                .bias_or_adder_feature  ( 1'b0                      ),
                .pulse                  ( pulse                     ),
                .feature_out            ( feature_out_core[i]       )
            );
        end
    end
endgenerate

// assign feature_out = {feature_out_core[7], feature_out_core[6], feature_out_core[5], feature_out_core[4], feature_out_core[3], feature_out_core[2], feature_out_core[1], feature_out_core[0]};

generate
    for (i=0; i<PE_CORE_NUM; i=i+1) begin : feature_out_assign_gen
        assign feature_out[(i+1)*MAC_OUTPUT_WIDTH-1:i*MAC_OUTPUT_WIDTH] = feature_out_core[i];
    end
endgenerate

endmodule