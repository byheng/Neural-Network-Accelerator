/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module sim_mul_tb ();

reg system_clk, rst_n;
reg [15:0]  w, x;
reg [35:0]  b;
reg [47:0]  PCIN;
wire[35:0]  out;
wire[47:0]  PCOUT;
reg         pulse;
initial begin
    system_clk = 1;
    forever #5 system_clk = ~system_clk;
end

initial begin
    rst_n = 0;
    pulse = 0;
    #10 rst_n = 1;
end    

initial begin
    w = -10;
    x = -5;
    PCIN = -20;
    #100
    w = 10;
    x = -5;
    PCIN = -10;
    #10
    w = -8;
    x = 2;
    PCIN = -30;
end

always @(posedge system_clk or negedge rst_n) begin
    if (!rst_n) begin
        pulse <= 0;
    end
    else pulse <= 1'b1;
end
MulAdder muladder_inst (
    .CLK        (system_clk),
    .CE         (pulse),
    .SCLR       (1'b0),
    .A          (w),
    .B          (x),    
    .C          (PCIN),
    .SUBTRACT   (1'b0),
    .P          (out),
    .PCOUT      (PCOUT)
);

endmodule