/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>

    state       : LION WORK FINISH
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module MAC_PE #(
    parameter FEATURE_WIDTH      = `FEATURE_WIDTH,
    parameter WEIGHT_WIDTH       = `WEIGHT_WIDTH,
    parameter MAC_WIDTH          = `MAC_WIDTH,
    parameter MAC_OVERFLOW_WIDTH = `MAC_OVERFLOW_WIDTH,
    parameter MAC_OUTPUT_WIDTH   = `MAC_OUTPUT_WIDTH,
    parameter SIGNED_FEATURE     = `SIGNED_FEATURE,
    parameter SIGNED_WEIGHT      = `SIGNED_WEIGHT,
    parameter BIAS_WIDTH         = WEIGHT_WIDTH + FEATURE_WIDTH
)
(
    input                               DSP_clk,
    input                               rst_n,
    input                               pulse,      // enable output
    input signed [WEIGHT_WIDTH-1:0]     w,          // weight
    input signed [FEATURE_WIDTH-1:0]    x,          // input data
    input signed [MAC_OUTPUT_WIDTH-1:0] b,          // bias\
    input signed [47:0]                 PCIN,       // Cascade Input
    output signed[MAC_OUTPUT_WIDTH-1:0] out,        // output data
    output signed[47:0]                 PCOUT       // Cascade Output
);

/*--------------------------- for fast simulation ----------------------*/
// MAC IP : P = P + w * x
reg signed [MAC_WIDTH-1:0] p;
initial p = 'd0;

always @(posedge DSP_clk) begin
    if (pulse) begin
        p <= w * x;
    end
end

// ouput data
reg signed [47:0] out_reg;
reg               pulse_reg;
always @(posedge DSP_clk) begin
    pulse_reg <= pulse;
end

always @(posedge DSP_clk) begin
    if (pulse_reg) begin
        out_reg <= PCIN + p;
    end
end

assign out = {out_reg[47], out_reg[34:0]};
assign PCOUT = out;

// /*--------------------------- for real hardware ----------------------*/

// MulAdder muladder_inst (
//     .CLK        (DSP_clk),
//     .CE         (pulse),
//     .SCLR       (1'b0),
//     .A          (w),
//     .B          (x),    
//     .C          (),
//     .PCIN       (PCIN),
//     .SUBTRACT   (1'b0),
//     .P          (out),
//     .PCOUT      (PCOUT)
// );

endmodule