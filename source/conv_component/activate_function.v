/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module activate_function #(
    parameter ACTIVATE_TYPE     = `ACTIVATE_TYPE, // 0: ReLU, 1: Leaky ReLU
    parameter MAC_OUTPUT_WIDTH  = `MAC_OUTPUT_WIDTH, // 36
    parameter FEATURE_WIDTH     = `FEATURE_WIDTH // 16
)
(
    input                           system_clk,
    input                           rst_n,
    input  [MAC_OUTPUT_WIDTH*8-1:0] data_for_act, // <-- convolution_core, 8 个 MAC 输出
    input                           data_for_act_valid,

    output [FEATURE_WIDTH*8-1:0]    act_data,
    output                          act_data_valid,
    input  [3:0]                    fea_in_quant_size, // 输入特征量化位数
    input  [3:0]                    fea_out_quant_size, // 期望输出特征量化位数
    input  [3:0]                    weight_quant_size, // 权重量化位数
    input                           activate, // 是否激活
    input  [MAC_OUTPUT_WIDTH-1:0]   negedge_threshold // 负阈值, 符号位扩展到 MAC_OUTPUT_WIDTH 位宽
);

reg [MAC_OUTPUT_WIDTH-1:0]          activate_reg[7:0];
reg [FEATURE_WIDTH-1:0]             quant_reg[7:0];
wire[MAC_OUTPUT_WIDTH-1:0]          data_for_act_depacked[7:0]; // 拆分 8 个 MAC 输出
wire[MAC_OUTPUT_WIDTH-1:0]          data_before_act[7:0];
reg [4:0]                           quant_size;

genvar i;
// activate function
generate  
    for (i=0; i<8; i=i+1) begin : activate_gen
        assign data_for_act_depacked[i] = data_for_act[i*MAC_OUTPUT_WIDTH+:MAC_OUTPUT_WIDTH]; // 拆分 8 个 MAC 输出
        assign data_before_act[i] = data_for_act_depacked[i] - negedge_threshold; // 实现与负阈值的比较
        if (ACTIVATE_TYPE == 0) begin // ReLU
            always @(posedge system_clk) begin
                if (activate) begin
                    activate_reg[i] <= (data_before_act[i][MAC_OUTPUT_WIDTH-1]) ? 36'h0 : data_before_act[i]; // 负数置零, 正数不变
                end
                else begin
                    activate_reg[i] <= data_before_act[i];
                end
            end
        end
        else if (ACTIVATE_TYPE == 1) begin // Leaky ReLU
            always @(posedge system_clk) begin
                if (activate) begin
                    activate_reg[i] <= (data_before_act[i][MAC_OUTPUT_WIDTH-1]) ? 
                        {{3{data_before_act[i][MAC_OUTPUT_WIDTH-1]}}, data_before_act[i][MAC_OUTPUT_WIDTH-1:3]} : // 负数乘以 0.125, 右移 3 位, 符号位扩展
                        data_before_act[i]; // 正数不变
                end
                else begin
                    activate_reg[i] <= data_before_act[i];
                end
            end
        end
    end
endgenerate

always @(posedge system_clk or negedge rst_n) begin
    if (!rst_n) begin
        quant_size <= 0;
    end
    else begin
        quant_size <= fea_in_quant_size + weight_quant_size - fea_out_quant_size; // 计算量化位数
    end
end

// cut down, 根据量化位数截断，保留符号位和高位，低位舍弃
generate
    for (i=0; i<8; i=i+1) begin : cut_down_gen
        always @(posedge system_clk or negedge rst_n) begin
            if (!rst_n) begin
                quant_reg[i] <= 16'h0;
            end
            else begin
                case (quant_size)
                    0: quant_reg[i]  <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][1 +:(FEATURE_WIDTH-1)]};
                    1: quant_reg[i]  <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][2 +:(FEATURE_WIDTH-1)]};
                    2: quant_reg[i]  <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][3 +:(FEATURE_WIDTH-1)]};
                    3: quant_reg[i]  <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][4 +:(FEATURE_WIDTH-1)]};
                    4: quant_reg[i]  <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][5 +:(FEATURE_WIDTH-1)]};
                    5: quant_reg[i]  <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][6 +:(FEATURE_WIDTH-1)]};
                    6: quant_reg[i]  <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][7 +:(FEATURE_WIDTH-1)]};
                    7: quant_reg[i]  <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][8 +:(FEATURE_WIDTH-1)]};
                    8: quant_reg[i]  <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][9 +:(FEATURE_WIDTH-1)]};
                    9: quant_reg[i]  <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][10+:(FEATURE_WIDTH-1)]};
                    10: quant_reg[i] <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][11+:(FEATURE_WIDTH-1)]};
                    11: quant_reg[i] <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][12+:(FEATURE_WIDTH-1)]};
                    12: quant_reg[i] <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][13+:(FEATURE_WIDTH-1)]};
                    13: quant_reg[i] <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][14+:(FEATURE_WIDTH-1)]};
                    14: quant_reg[i] <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][15+:(FEATURE_WIDTH-1)]};
                    15: quant_reg[i] <= {activate_reg[i][MAC_OUTPUT_WIDTH-1], activate_reg[i][16+:(FEATURE_WIDTH-1)]};
                    default: quant_reg[i] <= 16'h0;
                endcase
            end 
        end
    end
endgenerate

// 合并 8 个量化后的输出
assign act_data = {quant_reg[7], quant_reg[6], quant_reg[5], quant_reg[4], quant_reg[3], quant_reg[2], quant_reg[1], quant_reg[0]};

reg data_in_valid_r1, data_in_valid_r2;

always @(posedge system_clk or negedge rst_n) begin
    if (!rst_n) begin
        data_in_valid_r1 <= 0;
        data_in_valid_r2 <= 0;
    end
    else begin
        data_in_valid_r1 <= data_for_act_valid;
        data_in_valid_r2 <= data_in_valid_r1;
    end
end

assign act_data_valid = data_in_valid_r2; // 输出数据有效信号, 延迟两个时钟周期

endmodule