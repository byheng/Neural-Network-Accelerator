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
reg signed [MAC_WIDTH-1:0] p; // 存储两个16位乘法结果，需要32位
initial p = 'd0;

always @(posedge DSP_clk) begin
    if (pulse) begin
        p <= w * x;  // 当 pulse 信号输入时，进行乘法运算
    end
end

// ouput data
reg signed [47:0] out_reg; // 存储多个32位数累加结果，预留16位
reg               pulse_reg;
always @(posedge DSP_clk) begin
    pulse_reg <= pulse; // pulse 信号延迟一拍
end

always @(posedge DSP_clk) begin
    if (pulse_reg) begin
        out_reg <= PCIN + p;  // 累加操作需要延迟一拍，因为需要先进行乘法运算
    end
end

assign out = {out_reg[47], out_reg[34:0]}; // 保留符号位，截断处理
assign PCOUT = out; // PCOUT 和 out 输出的内容其实是一样的

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