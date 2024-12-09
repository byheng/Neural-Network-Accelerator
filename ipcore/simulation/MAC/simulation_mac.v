/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

module simulation_mac #(
    parameter DATA_A    = 8,
    parameter DATA_B    = 8,        
    parameter SIGNED_A  = 0,
    parameter SIGNED_B  = 0,
    parameter stage     = 1
)
(              
    input  wire                     clk    , // Clock    
    input  wire                     rst_n  , // Reset
    input  wire [DATA_A-1:0]        a      , // Input A
    input  wire [DATA_B-1:0]        b      , // Input B
    input  wire                     pulse  , // Pulse signal
    output wire [DATA_A+DATA_B-1:0] p        // Output product
);

// 处理输入信号，无符号表示正整数
wire signed [DATA_A:0] input_a;
wire signed [DATA_B:0] input_b;
generate
    if (SIGNED_A == 1) begin : signed_a
        assign input_a = {a[DATA_A-1], a};
    end
    else begin : unsigned_a
        assign input_a = {1'b0, a};
    end

    if (SIGNED_B == 1) begin : signed_b
        assign input_b = {b[DATA_B-1], b};
    end
    else begin : unsigned_b
        assign input_b = {1'b0, b};
    end
endgenerate

reg signed [DATA_A+DATA_B+1:0] product;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        product <= 0;
    end
    else if (pulse) begin
        product <= input_a * input_b;
    end
end

reg [DATA_A+DATA_B+1:0] product_reg[stage-1:0];
wire[DATA_A+DATA_B+1:0] product_tmp[stage:0];
assign product_tmp[0] = product;
generate
    for (genvar i=0; i<stage; i=i+1) begin : stage_reg
        if (i == 0) begin
            always @(posedge clk) begin
                product_reg[0] <= product;
            end
        end
        else begin
            always @(posedge clk) begin
                product_reg[i] <= product_reg[i-1];
            end
        end
        assign product_tmp[i+1] = product_reg[i];
    end
endgenerate

assign p = product_tmp[stage-1][DATA_A+DATA_B-1:0];

endmodule