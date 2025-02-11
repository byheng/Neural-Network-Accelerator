/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
    “人猿相揖别，只几个石头磨过”
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module feature_add #(
    parameter FEATURE_WIDTH     = `FEATURE_WIDTH
)(
    input                       system_clk,
    input                       rst_n,
    input [FEATURE_WIDTH*8-1:0] feature_x1_in,
    input [FEATURE_WIDTH*8-1:0] feature_x2_in,
    input                       feature_x_valid_in,

    output[FEATURE_WIDTH*8-1:0] feature_data_out,
    output                      feature_data_valid_out
);

wire [FEATURE_WIDTH-1:0]    feature_x1_depacked[7:0];
wire [FEATURE_WIDTH-1:0]    feature_x2_depacked[7:0];

genvar i;
generate
    for (i=0; i<8; i=i+1) begin : depack_feature
        assign feature_x1_depacked[i] = feature_x1_in[FEATURE_WIDTH*i+:FEATURE_WIDTH];
        assign feature_x2_depacked[i] = feature_x2_in[FEATURE_WIDTH*i+:FEATURE_WIDTH];
    end
endgenerate

reg [FEATURE_WIDTH-1:0] feature_data_out_reg[7:0];
reg                     feature_data_valid_out_reg;

generate
    for (i=0; i<8; i=i+1) begin : add_feature
        always @(posedge system_clk or negedge rst_n) begin
            if (!rst_n) begin
                feature_data_out_reg[i] <= 'd0;
            end
            else begin
                feature_data_out_reg[i] <= feature_x1_depacked[i] + feature_x2_depacked[i];
            end
        end
    end
endgenerate

assign feature_data_out = {feature_data_out_reg[7], feature_data_out_reg[6], feature_data_out_reg[5], feature_data_out_reg[4], feature_data_out_reg[3], feature_data_out_reg[2], feature_data_out_reg[1], feature_data_out_reg[0]};

always @(posedge system_clk) begin
    feature_data_valid_out_reg <= feature_x_valid_in;
end

assign feature_data_valid_out = feature_data_valid_out_reg;

endmodule