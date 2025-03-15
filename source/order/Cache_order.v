/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module Cache_order(
    input                   axi_clk                    ,
    input                   axi_rst_n                  ,
    input                   system_clk                 ,
    input                   rst_n                      ,
    input                   refresh_order_ram          ,
    input                   push_order_en              ,
    input                   pop_order_en               ,
    input                   task_start                 ,
    output reg              calculate_start            ,

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
    input [31:0]            x_return_addr              ,
    input [15:0]            x_return_patch_num         ,
    input [2:0]             x_padding_size             ,
    input [31:0]            x_weight_data_length       ,
    input                   x_activate                 ,
    input [7:0]             x_id                       ,    
    input [31:0]            x_negedge_threshold        ,
    input                   x_output_to_video          ,
    input [7:0]             x_mask_stride              ,

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
    output reg [31:0]           return_addr              ,
    output reg [15:0]           return_patch_num         ,
    output reg [2:0]            padding_size             ,
    output reg [31:0]           weight_data_length       ,
    output reg                  activate                 ,
    output reg [7:0]            id                       ,
    output reg [31:0]           negedge_threshold        ,
    output reg                  output_to_video          ,
    output reg [7:0]            mask_stride             
);

// 缓存两段指令
wire [255:0] order_fifo_in;
wire [255:0] order_fifo_out;
reg  [8:0]   write_addr;
reg  [8:0]   read_addr;

assign order_fifo_in = {x_output_to_video, x_negedge_threshold, x_id, x_activate, x_return_addr, x_return_patch_num, x_padding_size, x_mask_stride, x_fea_out_quant_size, x_fea_in_quant_size, x_weight_quant_size, x_col_size, x_row_size, x_feature_patch_num, x_feature_double_patch, x_feature_output_patch_num, x_feature_input_patch_num, x_feature_input_base_addr, x_order};

generate
    if (`device == "xilinx") begin
        order_cache order_cache_inst (
            .clka   (axi_clk        ),
            .wea    (push_order_en  ),
            .addra  (write_addr     ),
            .dina   (order_fifo_in  ),
            .clkb   (system_clk     ),
            .addrb  (read_addr      ),
            .doutb  (order_fifo_out )
        );     
    end
    else if (`device == "simulation") begin
        // simulation_ram #(
        //     .DATA_W    	( 256      ),
        //     .DATA_R    	( 256      ),
        //     .DEPTH_W   	( 9        ),
        //     .DEPTH_R   	( 9        ),
        //     .INIT_FILE 	( ""       ),
        //     .DELAY     	( 0        ))
        // u_simulation_ram(
        //     .w_clk     	( axi_clk       ),
        //     .i_wren  	( push_order_en ),
        //     .i_waddr 	( write_addr    ),
        //     .i_wdata 	( order_fifo_in ),
        //     .r_clk     	( system_clk    ),
        //     .i_raddr 	( read_addr     ),
        //     .o_rdata 	( order_fifo_out)
        // );

        DPRAM #(
            .WIDTH 	( 256    ),
            .DEPTH 	( 2**9  ))
        u_DPRAM(
            .clka  	( axi_clk       ),
            .ena   	( 1'b1          ),
            .wea   	( push_order_en ),
            .addra 	( write_addr    ),
            .dina  	( order_fifo_in ),
            .douta 	(               ),
            .clkb  	( system_clk    ),
            .enb   	( 1'b1          ),
            .web   	( 1'b0          ),
            .addrb 	( read_addr     ),
            .dinb  	(               ),
            .doutb 	( order_fifo_out)
        );

    end
endgenerate

always@ (posedge axi_clk or negedge axi_rst_n) begin
    if(~axi_rst_n) begin
        write_addr <= 0;
    end
    else if (refresh_order_ram) begin
        write_addr <= 0;
    end
    else if (push_order_en) begin
        write_addr <= write_addr + 1;
    end
end

always@ (posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        read_addr <= 0;
    end
    else if (order == 5) begin
        read_addr <= 0;
    end
    else if (pop_order_en) begin
        read_addr <= read_addr + 1;
    end
end

always@ (posedge system_clk) begin
    if (order == 5) begin
        order <= 0;
    end
    else if (pop_order_en) begin
        {output_to_video, negedge_threshold, id, activate, return_addr, return_patch_num, padding_size, mask_stride, fea_out_quant_size, fea_in_quant_size, weight_quant_size, col_size, row_size, feature_patch_num, feature_double_patch, feature_output_patch_num, feature_input_patch_num, feature_input_base_addr, order} <= order_fifo_out;
    end
end

always@ (posedge system_clk) begin
    calculate_start <= pop_order_en;
end

endmodule
