
`timescale 1 ns / 1 ps

module get_order #
(
	// Parameters of Axi Slave Bus Interface S00_AXI
	parameter integer C_S00_AXI_DATA_WIDTH	= 32,
	parameter integer C_S00_AXI_ADDR_WIDTH	= 8
)
(
	// Users to add ports here
	input                   system_clk					,
	input                   rst_n						,
	output                  task_start					,	
	output                  task_finish					,
	output reg              accelerator_restart			,
	input  				 	calculate_finish			,
	output reg				calculate_start				,

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
	output reg[31:0]		weight_data_length			,
	output                  activate   					,
	output [31:0]			id							,
	// User ports ends
	// Do not modify the ports beyond this line
	// Ports of Axi Slave Bus Interface S00_AXI
	input wire  s00_axi_aclk,
	input wire  s00_axi_aresetn,
	input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
	input wire [2 : 0] s00_axi_awprot,
	input wire  s00_axi_awvalid,
	output wire  s00_axi_awready,
	input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
	input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
	input wire  s00_axi_wvalid,
	output wire  s00_axi_wready,
	output wire [1 : 0] s00_axi_bresp,
	output wire  s00_axi_bvalid,
	input wire  s00_axi_bready,
	input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
	input wire [2 : 0] s00_axi_arprot,
	input wire  s00_axi_arvalid,
	output wire  s00_axi_arready,
	output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
	output wire [1 : 0] s00_axi_rresp,
	output wire  s00_axi_rvalid,
	input wire  s00_axi_rready
);

wire [2:0]            x_order					;
wire [31:0]           x_feature_input_base_addr	;
wire [7:0]            x_feature_input_patch_num	;
wire [7:0]            x_feature_output_patch_num;
wire                  x_feature_double_patch	;
wire [31:0]           x_feature_patch_num		;
wire [9:0]            x_row_size				;
wire [9:0]            x_col_size				;
wire [3:0]            x_weight_quant_size		;
wire [3:0]            x_fea_in_quant_size		;
wire [3:0]            x_fea_out_quant_size		;
wire                  x_stride					;
wire [31:0]           x_return_addr				;
wire [15:0]           x_return_patch_num		;
wire [2:0]            x_padding_size			;
wire [31:0]			  x_weight_data_length		;
wire                  x_activate   				;
wire [31:0]			  x_id						;
wire                  push_order_en				;
wire                  order_in_ready			;
wire                  order_valid				;
wire                  order_valid_r 			;
reg  [31:0]			  finish_layer 				;
reg  [31:0]			  push_layer 				;
reg  [31:0]			  valid_layer 				;
wire                  task_start_axi			;
wire                  task_finish_axi			;
wire                  accelerator_restart_axi	;
reg                   task_start_r1,task_start_r2	;
reg                   task_finish_r1,task_finish_r2	;
reg [2:0]             rst_cnt;

always @(posedge system_clk) begin
	task_start_r1 <= task_start_axi;
	task_finish_r1 <= task_finish_axi;
	task_start_r2 <= task_start_r1;
	task_finish_r2 <= task_finish_r1;
end

assign task_start = task_start_r1 & ~task_start_r2;
assign task_finish = task_finish_r1 & ~task_finish_r2;

always @(posedge s00_axi_aclk or negedge s00_axi_aresetn) begin
	if (~s00_axi_aresetn) begin
		accelerator_restart <= 0;
	end
	else if (accelerator_restart_axi) begin
		accelerator_restart <= 1;
	end
	else if (rst_cnt == 7) begin
		accelerator_restart <= 0;
	end
end

always @(posedge s00_axi_aclk or negedge s00_axi_aresetn) begin
	if (~s00_axi_aresetn) begin
		rst_cnt <= 0;
	end
	else if (accelerator_restart) begin
		rst_cnt <= rst_cnt + 1;
	end
	else begin
		rst_cnt <= 0;
	end
end

reg calculate_finish_r1;
wire next_calculate_application;
reg next_calculate_application_r;

// Instantiation of Axi Bus Interface S00_AXI
set_accelerator_reg_axi # ( 
	.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
	.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
) set_accelerator_reg_axi_inst (
	.order						(x_order					),
	.feature_input_base_addr	(x_feature_input_base_addr	),
	.feature_input_patch_num	(x_feature_input_patch_num	),
	.feature_output_patch_num	(x_feature_output_patch_num	),
	.feature_double_patch		(x_feature_double_patch		),
	.feature_patch_num			(x_feature_patch_num		),
	.row_size					(x_row_size					),
	.col_size					(x_col_size					),
	.weight_quant_size			(x_weight_quant_size		),
	.fea_in_quant_size			(x_fea_in_quant_size		),
	.fea_out_quant_size			(x_fea_out_quant_size		),
	.stride						(x_stride					),
	.return_addr				(x_return_addr				),
	.return_patch_num			(x_return_patch_num			),
	.padding_size				(x_padding_size				),
	.weight_data_length			(x_weight_data_length		),
	.activate   				(x_activate   				),
	.id							(x_id						),
	.push_order_en				(push_order_en				),
	.task_start					(task_start_axi				),	
	.task_finish				(task_finish_axi			),
	.accelerator_restart		(accelerator_restart_axi	),
	.order_in_ready				(order_in_ready				),
	.finish_layer				(finish_layer				),	
	.push_layer					(push_layer					),
	.valid_layer				(valid_layer				),
	.S_AXI_ACLK					(s00_axi_aclk				),
	.S_AXI_ARESETN				(s00_axi_aresetn			),
	.S_AXI_AWADDR				(s00_axi_awaddr				),
	.S_AXI_AWPROT				(s00_axi_awprot				),
	.S_AXI_AWVALID				(s00_axi_awvalid			),
	.S_AXI_AWREADY				(s00_axi_awready			),
	.S_AXI_WDATA				(s00_axi_wdata				),
	.S_AXI_WSTRB				(s00_axi_wstrb				),
	.S_AXI_WVALID				(s00_axi_wvalid				),
	.S_AXI_WREADY				(s00_axi_wready				),
	.S_AXI_BRESP				(s00_axi_bresp				),
	.S_AXI_BVALID				(s00_axi_bvalid				),
	.S_AXI_BREADY				(s00_axi_bready				),
	.S_AXI_ARADDR				(s00_axi_araddr				),
	.S_AXI_ARPROT				(s00_axi_arprot				),
	.S_AXI_ARVALID				(s00_axi_arvalid			),
	.S_AXI_ARREADY				(s00_axi_arready			),
	.S_AXI_RDATA				(s00_axi_rdata				),
	.S_AXI_RRESP				(s00_axi_rresp				),
	.S_AXI_RVALID				(s00_axi_rvalid				),
	.S_AXI_RREADY				(s00_axi_rready				)
);

	// Add user logic here
Cache_order Cache_order_inst(
    .axi_clk                    (s00_axi_aclk				),
	.axi_rst_n                  (s00_axi_aresetn			),
	.system_clk                 (system_clk					),
	.rst_n                      (rst_n						),
    .order_in_ready             (order_in_ready				),
    .order_out_ready            (),
    .push_order_en              (push_order_en				),
    .pop_order_en               (next_calculate_application_r),
    .order_valid                (order_valid				),
	.order_valid_r				(order_valid_r				),
    .x_order                    (x_order					),
    .x_feature_input_base_addr  (x_feature_input_base_addr	),
    .x_feature_input_patch_num  (x_feature_input_patch_num	),
    .x_feature_output_patch_num (x_feature_output_patch_num	),
    .x_feature_double_patch     (x_feature_double_patch		),
    .x_feature_patch_num        (x_feature_patch_num		),
    .x_row_size                 (x_row_size					),
    .x_col_size                 (x_col_size					),
    .x_weight_quant_size        (x_weight_quant_size		),
    .x_fea_in_quant_size        (x_fea_in_quant_size		),
    .x_fea_out_quant_size       (x_fea_out_quant_size		),
    .x_stride                   (x_stride					),
    .x_return_addr              (x_return_addr				),
    .x_return_patch_num         (x_return_patch_num			),
    .x_padding_size             (x_padding_size				),
    .x_activate                 (x_activate   				),
    .x_id                       (x_id						),
    .order                      (order						),
    .feature_input_base_addr    (feature_input_base_addr	),
    .feature_input_patch_num    (feature_input_patch_num	),
    .feature_output_patch_num   (feature_output_patch_num	),
    .feature_double_patch       (feature_double_patch		),
    .feature_patch_num          (feature_patch_num			),
    .row_size                   (row_size					),
    .col_size                   (col_size					),
    .weight_quant_size          (weight_quant_size			),
    .fea_in_quant_size          (fea_in_quant_size			),
    .fea_out_quant_size         (fea_out_quant_size			),
    .stride                     (stride						),
    .return_addr                (return_addr				),
    .return_patch_num           (return_patch_num			),
    .padding_size               (padding_size				),
    .activate                   (activate   				),
    .id                         (id							)
);
// User logic ends
// 取finish的上升沿得到下一次计算的申请信号
always @(posedge system_clk) begin
	calculate_finish_r1 <= calculate_finish;
end
assign next_calculate_application = ~calculate_finish_r1 & calculate_finish;
// 保持申请信号直到下一次指令读出
always @(posedge system_clk or negedge rst_n) begin
	if (~rst_n) begin
		next_calculate_application_r <= 1'b0;
	end
	else if(next_calculate_application | task_start) begin
		next_calculate_application_r <= 1'b1;
	end
	else if (order_valid)begin
		next_calculate_application_r <= 1'b0;
	end
end
// order valid打一拍作为calculate start信号
always @(posedge system_clk) begin
	calculate_start <= order_valid_r;
end

always @(posedge system_clk or negedge rst_n) begin
	if (~rst_n) begin
		finish_layer <= 32'h0;
	end
	else if (task_start) begin
		finish_layer <= 32'h0;
	end
	else if (next_calculate_application) begin
		finish_layer <= finish_layer + 1;
	end
end

always @(posedge s00_axi_aclk or negedge s00_axi_aresetn) begin
	if (~s00_axi_aresetn) begin
		push_layer <= 32'h0;
	end
	else if (task_start_axi) begin
		push_layer <= 32'h0;
	end
	else if (push_order_en) begin
		push_layer <= push_layer + 1;
	end
end

always @(posedge system_clk or negedge rst_n) begin
	if (~rst_n) begin
		valid_layer <= 32'h0;
	end
	else if (task_start) begin
		valid_layer <= 32'h0;
	end
	else if (calculate_start) begin
		valid_layer <= valid_layer + 1;
	end
end

always @(posedge system_clk) begin
	weight_data_length <= x_weight_data_length;
end

endmodule
