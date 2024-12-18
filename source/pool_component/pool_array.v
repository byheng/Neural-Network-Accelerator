/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module pool_array #(
    parameter FEATURE_WIDTH = `FEATURE_WIDTH,
    parameter MAXPOOL_SIZE  = `MAXPOOL_SIZE,
    parameter PE_ARRAY_SIZE = `PE_ARRAY_SIZE,
    parameter FEATURE_TOTAL_WIDTH = FEATURE_WIDTH*MAXPOOL_SIZE*PE_ARRAY_SIZE
)(
    input                                   DSP_clk,
    input                                   rst_n, 
    input [FEATURE_TOTAL_WIDTH-1:0]         feature,      
    input                                   pulse,
    output[FEATURE_WIDTH*PE_ARRAY_SIZE-1:0] feature_out
);

genvar i;
wire [FEATURE_WIDTH*MAXPOOL_SIZE-1:0] feature_depacked[PE_ARRAY_SIZE-1:0];
wire [FEATURE_WIDTH-1:0]              feature_out_packed[PE_ARRAY_SIZE-1:0];
generate
    for(i=0;i<PE_ARRAY_SIZE;i=i+1) begin:feature_depack
        assign feature_depacked[i] = feature[i*FEATURE_WIDTH*MAXPOOL_SIZE+:FEATURE_WIDTH*MAXPOOL_SIZE];
        assign feature_out[i*FEATURE_WIDTH+:FEATURE_WIDTH] = feature_out_packed[i];
    end
endgenerate

// POOLING ARRAY
generate
    for(i=0;i<PE_ARRAY_SIZE;i=i+1) begin:pool_array_inst
        pool_core pool_core_inst (
            .DSP_clk        ( DSP_clk               ),
            .rst_n          ( rst_n                 ), 
            .feature        ( feature_depacked[i]   ),      
            .pulse          ( pulse                 ),
            .feature_out    ( feature_out_packed[i] )
        );
    end
endgenerate

// just for debug
wire [FEATURE_WIDTH-1:0] feature_in_debug[4:0];
generate if (`debug == 1)
    for(i=0;i<5;i=i+1) begin:feature_in_debug_assign
        assign feature_in_debug[i] = feature_depacked[0][i*FEATURE_WIDTH+:FEATURE_WIDTH];
    end
endgenerate

endmodule