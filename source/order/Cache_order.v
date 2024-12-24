/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

module Cache_order(
    input                   clk                        ,
    input                   rst_n                      ,
    output                  order_in_ready             ,
    output                  order_out_ready            ,
    input                   push_order_en              ,
    input                   pop_order_en               ,
    output                  order_valid                ,
    output reg              order_valid_r              ,

    input [2:0]             x_order                    ,
    input [31:0]            x_feature_input_base_addr  ,
    input [7:0]             x_feature_input_patch_num  ,
    input [7:0]             x_feature_output_patch_num ,
    input                   x_feature_double_patch     ,
    input [31:0]            x_feature_patch_num        ,
    input [9:0]             x_row_size                 ,
    input [9:0]             x_col_size                 ,
    input [3:0]             x_weight_quant_size        ,
    input [3:0]             x_fea_in_quant_size        ,
    input [3:0]             x_fea_out_quant_size       ,
    input                   x_stride                   ,
    input [31:0]            x_return_addr              ,
    input [15:0]            x_return_patch_num         ,
    input [2:0]             x_padding_size             ,
    input [31:0]            x_weight_data_length       ,
    input                   x_activate                 ,
    input [31:0]            x_id                       ,
    

    output reg [2:0]            order                    ,
    output reg [31:0]           feature_input_base_addr  ,
    output reg [7:0]            feature_input_patch_num  ,
    output reg [7:0]            feature_output_patch_num ,
    output reg                  feature_double_patch     ,
    output reg [31:0]           feature_patch_num        ,
    output reg [9:0]            row_size                 ,
    output reg [9:0]            col_size                 ,
    output reg [3:0]            weight_quant_size        ,
    output reg [3:0]            fea_in_quant_size        ,
    output reg [3:0]            fea_out_quant_size       ,
    output reg                  stride                   ,
    output reg [31:0]           return_addr              ,
    output reg [15:0]           return_patch_num         ,
    output reg [2:0]            padding_size             ,
    output reg [31:0]           weight_data_length       ,
    output reg                  activate                 ,
    output reg [31:0]           id                       
);

assign order_in_ready = 1'b1;

// 缓存两段指令
wire [255:0] order_fifo_in;
wire [255:0] order_fifo_out;
wire         order_fifo_almost_full;
wire         order_fifo_empty;

assign order_in_ready = ~order_fifo_almost_full;

assign order_fifo_in = {x_id, x_activate, x_weight_data_length, x_return_addr, x_return_patch_num, x_padding_size, x_stride, x_fea_out_quant_size, x_fea_in_quant_size, x_weight_quant_size, x_col_size, x_row_size, x_feature_patch_num, x_feature_double_patch, x_feature_output_patch_num, x_feature_input_patch_num, x_feature_input_base_addr, x_order};

order_cache order_cache_inst (
    .clk            (clk),
    .srst           (~rst_n),
    .din            (order_fifo_in),
    .wr_en          (push_order_en),
    .rd_en          (pop_order_en),
    .dout           (order_fifo_out),
    .full           (),
    .almost_full    (order_fifo_almost_full),
    .empty          (order_fifo_empty)
);

assign order_valid = pop_order_en & ~order_fifo_empty;

always @(posedge clk) begin
    order_valid_r <= order_valid;
end

always @(posedge clk) begin
    if (order_valid_r) begin
        {id, activate, weight_data_length, return_addr, return_patch_num, padding_size, stride, fea_out_quant_size, fea_in_quant_size, weight_quant_size, col_size, row_size, feature_patch_num, feature_double_patch, feature_output_patch_num, feature_input_patch_num, feature_input_base_addr, order} <= order_fifo_out;
    end
end

endmodule
