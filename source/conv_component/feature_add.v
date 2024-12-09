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

    input                       feature_add,
    output[FEATURE_WIDTH*8-1:0] feature_data_out,
    output                      feature_data_valid_out,

    input [2:0]                 fea_relative_quant,         // relative quantization size of two features to be added
    input                       fea_relative_quant_polar,   // the polar of relative quantization size, 0: x1 plus x2, 1: x1 minus x2
    input                       fea_over_flow               // 1: feature overflow
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

reg [FEATURE_WIDTH-1:0]  feature_x1_cut[7:0];
reg [FEATURE_WIDTH-1:0]  feature_x2_cut[7:0];

generate
    for (i=0; i<8; i=i+1) begin : cut_feature
        always @(posedge system_clk or negedge rst_n) begin
            if (!rst_n) begin
                feature_x1_cut[i] <= 'd0;
            end
            else if (!fea_relative_quant_polar) begin
                case (fea_relative_quant)
                    3'd0 : begin
                        feature_x1_cut[i] <= feature_x1_depacked[i];
                    end
                    3'd1 : begin
                        feature_x1_cut[i] <= {1'b0, feature_x1_depacked[i][FEATURE_WIDTH-1:1]};
                    end
                    3'd2 : begin
                        feature_x1_cut[i] <= {2'b0, feature_x1_depacked[i][FEATURE_WIDTH-1:2]};
                    end
                    3'd3 : begin
                        feature_x1_cut[i] <= {3'b0, feature_x1_depacked[i][FEATURE_WIDTH-1:3]};
                    end
                    3'd4 : begin
                        feature_x1_cut[i] <= {4'b0, feature_x1_depacked[i][FEATURE_WIDTH-1:4]};
                    end
                    3'd5 : begin
                        feature_x1_cut[i] <= {5'b0, feature_x1_depacked[i][FEATURE_WIDTH-1:5]};
                    end
                    3'd6 : begin
                        feature_x1_cut[i] <= {6'b0, feature_x1_depacked[i][FEATURE_WIDTH-1:6]};
                    end
                    3'd7 : begin
                        feature_x1_cut[i] <= {7'b0, feature_x1_depacked[i][FEATURE_WIDTH-1:7]};
                    end
                endcase
            end
            else begin
                feature_x1_cut[i] <= feature_x1_depacked[i];
            end
        end

        always @(posedge system_clk or negedge rst_n) begin
            if (!rst_n) begin
                feature_x2_cut[i] <= 8'b0;
            end
            else if (fea_relative_quant_polar) begin
                case (fea_relative_quant)
                    3'd0 : begin
                        feature_x2_cut[i] <= feature_x2_depacked[i];
                    end
                    3'd1 : begin
                        feature_x2_cut[i] <= {1'b0, feature_x2_depacked[i][FEATURE_WIDTH-1:1]};
                    end
                    3'd2 : begin
                        feature_x2_cut[i] <= {2'b0, feature_x2_depacked[i][FEATURE_WIDTH-1:2]};
                    end
                    3'd3 : begin
                        feature_x2_cut[i] <= {3'b0, feature_x2_depacked[i][FEATURE_WIDTH-1:3]};
                    end
                    3'd4 : begin
                        feature_x2_cut[i] <= {4'b0, feature_x2_depacked[i][FEATURE_WIDTH-1:4]};
                    end
                    3'd5 : begin
                        feature_x2_cut[i] <= {5'b0, feature_x2_depacked[i][FEATURE_WIDTH-1:5]};
                    end
                    3'd6 : begin
                        feature_x2_cut[i] <= {6'b0, feature_x2_depacked[i][FEATURE_WIDTH-1:6]};
                    end
                    3'd7 : begin
                        feature_x2_cut[i] <= {7'b0, feature_x2_depacked[i][FEATURE_WIDTH-1:7]};
                    end
                endcase
            end
            else begin
                feature_x2_cut[i] <= feature_x2_depacked[i];
            end
        end
    end
endgenerate

reg [FEATURE_WIDTH:0]   feature_data_out_reg[7:0];
wire[FEATURE_WIDTH-1:0] feature_data_overflow_check[7:0];
reg [1:0]               feature_data_valid_out_reg;

generate
    for (i=0; i<8; i=i+1) begin : add_feature
        always @(posedge system_clk or negedge rst_n) begin
            if (!rst_n) begin
                feature_data_out_reg[i] <= 'd0;
            end
            else begin
                feature_data_out_reg[i] <= feature_x1_cut[i] + feature_x2_cut[i];
            end
        end
        assign feature_data_overflow_check[i] = (fea_over_flow) ? feature_data_out_reg[i][FEATURE_WIDTH:1] : feature_data_out_reg[i][FEATURE_WIDTH-1:0];
    end
endgenerate

assign feature_data_out = {feature_data_overflow_check[7], feature_data_overflow_check[6], feature_data_overflow_check[5], feature_data_overflow_check[4], feature_data_overflow_check[3], feature_data_overflow_check[2], feature_data_overflow_check[1], feature_data_overflow_check[0]};

always @(posedge system_clk or negedge rst_n) begin
    feature_data_valid_out_reg <= {feature_data_valid_out_reg[0], feature_x_valid_in};
end

assign feature_data_valid_out = feature_data_valid_out_reg[1];

endmodule