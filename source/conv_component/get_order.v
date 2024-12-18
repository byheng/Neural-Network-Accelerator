/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module get_order(
    input                   system_clk,
    input                   rst_n,
	output reg              task_start,
    input                   calculate_finish,
    output reg              calculate_start,
    // parameters
    output [2:0]            order						,
	output [31:0]           feature_input_base_addr		,
	output [7:0]            feature_input_patch_num		,
	output [7:0]            feature_output_patch_num	,
	output                  feature_double_patch		,
	output [31:0]           feature_patch_num			,
	output [9:0]            row_size					,
	output [9:0]            col_size					,
	output [3:0]            weight_quant_size			,
	output [3:0]            fea_in_quant_size			,
	output [3:0]            fea_out_quant_size			,
	output                  stride						,
	output [31:0]           return_addr					,
	output [15:0]           return_patch_num			,
	output [2:0]            padding_size				,
	output [31:0]			weight_data_length			,
	output                  activate   					,
	output [31:0]			id
);

parameter LAYER_NUM = 0;

initial begin
	task_start <= 0;
	#100
	task_start <= 1;
	#10
	task_start <= 0;
end

reg [32*32-1:0] order_data_array[127:0];
reg [6:0]       order_addr;
wire[32*32-1:0] order_data;
wire[31:0]      order_data_depacked[31:0];
reg             calculate_finish_r1, calculate_finish_r2;

initial begin
    $readmemh("F:/FPGA/accelerator_core/script/order.txt", order_data_array);
end

assign order_data = order_data_array[order_addr];
wire change_order;

genvar i;
generate
	for(i=0;i<32;i=i+1) begin:order_depack
		assign order_data_depacked[i] = order_data[32*i+:32];
	end
endgenerate

assign change_order = calculate_finish & ~calculate_finish_r1;

always @(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        order_addr <= LAYER_NUM;
    end 
	else if (change_order) begin
        order_addr <= order_addr + 1;
    end
end

always @(posedge system_clk or negedge rst_n) begin
	calculate_finish_r1 <= calculate_finish;
	calculate_finish_r2 <= calculate_finish_r1;
	calculate_start     <= calculate_finish_r2;
end

assign order					= order_data_depacked[0];
assign feature_input_base_addr	= order_data_depacked[1];	
assign feature_input_patch_num	= order_data_depacked[2];		
assign feature_output_patch_num	= order_data_depacked[3];		
assign feature_double_patch		= order_data_depacked[4];		
assign feature_patch_num		= order_data_depacked[5];		
assign row_size					= order_data_depacked[6];		
assign col_size					= order_data_depacked[7];	
assign weight_quant_size		= order_data_depacked[8];		
assign fea_in_quant_size		= order_data_depacked[9];			
assign fea_out_quant_size		= order_data_depacked[10];		
assign stride					= order_data_depacked[11];	
assign return_addr				= order_data_depacked[12];	
assign return_patch_num		   	= order_data_depacked[13];	
assign padding_size				= order_data_depacked[14];	       
assign weight_data_length		= order_data_depacked[15];	 
assign activate					= order_data_depacked[16];	
assign id						= order_data_depacked[17];	                	     	           

endmodule