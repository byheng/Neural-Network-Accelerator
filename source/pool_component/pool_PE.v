/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../../parameters.v"

module pool_PE #(
    parameter DATA_WIDTH        = `MAC_PE_DATA_WIDTH,
    parameter MAC_OUTPUT_WIDTH  = `MAC_OUTPUT_WIDTH
)
(
    input                    DSP_clk,
    input                    rst_n,
    input                    pulse,     // enable output
    input  [DATA_WIDTH-1:0]  x1_,        // x1_
    input  [DATA_WIDTH-1:0]  x2_,        // x2_
    output [DATA_WIDTH-1:0]  out        // output data
);

// ouput data
reg [DATA_WIDTH-1:0] out_reg;
always @(posedge DSP_clk or negedge rst_n) begin
    if (~rst_n) begin
        out_reg <= 'd0;
    end
    else if (pulse) begin
        out_reg <= (x1_ > x2_) ? x1_ : x2_;
    end
end

assign out = out_reg;

endmodule