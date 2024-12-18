/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module pool_core #(
    parameter FEATURE_WIDTH = `FEATURE_WIDTH,
    parameter MAXPOOL_SIZE  = `MAXPOOL_SIZE,
    parameter PE_NUM        = MAXPOOL_SIZE * MAXPOOL_SIZE
)(
    input                                   DSP_clk,
    input                                   rst_n, 
    input [FEATURE_WIDTH*MAXPOOL_SIZE-1:0]  feature,      
    input                                   pulse,
    output[FEATURE_WIDTH-1:0]               feature_out
);

wire signed[FEATURE_WIDTH-1:0] pool_out   [PE_NUM-1:0];
wire signed[FEATURE_WIDTH-1:0] pool_in_x1 [PE_NUM-1:0];
wire signed[FEATURE_WIDTH-1:0] pool_in_x2 [PE_NUM-1:0];
reg  signed[FEATURE_WIDTH-1:0] max1[2:0], max2[1:0], max3;

genvar i, j;
generate
    for (i = 0; i < MAXPOOL_SIZE; i=i+1) begin : Pool_array_line_gen
        for (j = 0; j < MAXPOOL_SIZE; j=j+1) begin : Pool_array_col_gen
            localparam index = i*MAXPOOL_SIZE + j;
            assign pool_in_x1[index] = feature[FEATURE_WIDTH*i+:FEATURE_WIDTH];
            
            if (j==0) begin
                assign pool_in_x2[index] = 0;
            end
            else begin
                assign pool_in_x2[index] = pool_out[index-1];
            end

            pool_PE u_pool_PE(
                .DSP_clk 	( DSP_clk           ),
                .rst_n   	( rst_n             ),
                .pulse   	( pulse             ),
                .x1_     	( pool_in_x1[index] ),
                .x2_     	( pool_in_x2[index] ),
                .out     	( pool_out[index]   )
            );
        end
    end
endgenerate

// compare the 5 man in each row last
always @ (posedge DSP_clk or negedge rst_n) begin
    if (!rst_n) begin
        max1[0] <= 0;
        max1[1] <= 0;
        max1[2] <= 0;
    end
    else begin
        max1[0] <= (pool_out[4] > pool_out[9]) ? pool_out[4] : pool_out[9];
        max1[1] <= (pool_out[14] > pool_out[19]) ? pool_out[14] : pool_out[19];
        max1[2] <= pool_out[24];
    end
end

always @ (posedge DSP_clk or negedge rst_n) begin
    if (!rst_n) begin
        max2[0] <= 0;
        max2[1] <= 0;
    end
    else begin
        max2[0] <= (max1[0] > max1[1]) ? max1[0] : max1[1];
        max2[1] <= max1[2];
    end
end

always @ (posedge DSP_clk or negedge rst_n) begin
    if (!rst_n) begin
        max3 <= 0;
    end
    else begin
        max3 <= (max2[0] > max2[1]) ? max2[0] : max2[1];
    end
end

assign feature_out = max3;

endmodule