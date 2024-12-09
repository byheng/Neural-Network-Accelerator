/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module add_tree #(
    parameter STAGES_NUM        = 4,
    parameter MAC_OUTPUT_WIDTH  = `MAC_OUTPUT_WIDTH
)(
    input                               system_clk ,       
    input                               rst_n      ,       
    input  [16*MAC_OUTPUT_WIDTH-1 : 0]  in_data    ,       
    output [MAC_OUTPUT_WIDTH-1 : 0]     data_out   
);

// 缓存数据
reg  signed[MAC_OUTPUT_WIDTH-1:0] data_reg   [15:0];
wire [MAC_OUTPUT_WIDTH-1:0]       data_spilt [15:0];

generate
    genvar i;
    for (i = 0; i < 16; i=i+1) begin : stage1_gen
        assign data_spilt[i] = in_data[MAC_OUTPUT_WIDTH*(i+1)-1:MAC_OUTPUT_WIDTH*i];
        always @(posedge system_clk or negedge rst_n) begin
            if (!rst_n) begin
                data_reg[i] <= 1'b0;
            end
            else begin
                data_reg[i] <= data_spilt[i];
            end
        end
    end
endgenerate

// stage 1
reg signed[MAC_OUTPUT_WIDTH-1:0] data_stage1 [7:0];

generate
    for (i = 0; i < 8; i=i+1) begin : stage1
        always @(posedge system_clk or negedge rst_n) begin
            if (!rst_n) begin
                data_stage1[i] <= 1'b0;
            end
            else begin
                data_stage1[i] <= data_reg[i*2] + data_reg[i*2+1];
            end
        end
    end
endgenerate

// stage 2
reg signed[MAC_OUTPUT_WIDTH-1:0] data_stage2 [3:0];

generate
    for (i = 0; i < 4; i=i+1) begin : stage2
        always @(posedge system_clk or negedge rst_n) begin
            if (!rst_n) begin
                data_stage2[i] <= 1'b0;
            end
            else begin
                data_stage2[i] <= data_stage1[i*2] + data_stage1[i*2+1];
            end
        end
    end
endgenerate

// stage 3
reg signed[MAC_OUTPUT_WIDTH-1:0] data_stage3 [1:0];

generate
    for (i = 0; i < 2; i=i+1) begin : stage3
        always @(posedge system_clk or negedge rst_n) begin
            if (!rst_n) begin
                data_stage3[i] <= 1'b0;
            end
            else begin
                data_stage3[i] <= data_stage2[i*2] + data_stage2[i*2+1];
            end
        end
    end
endgenerate

// stage 3
reg signed[MAC_OUTPUT_WIDTH-1:0] data_stage4;

always @(posedge system_clk or negedge rst_n) begin
    if (!rst_n) begin
        data_stage4 <= 1'b0;
    end
    else begin
        data_stage4 <= data_stage3[0] + data_stage3[1];
    end
end

// output
assign data_out = data_stage4;

endmodule