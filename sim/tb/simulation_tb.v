/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module conv_control_tb ();

reg system_clk, rst_n;
initial begin
    system_clk = 0;
    forever #5 system_clk = ~system_clk;
end
initial begin
    rst_n = 0;
    #10 rst_n = 1;
end       

// outports wire
wire [31:0]  s_axi_awaddr;
wire [7:0]   s_axi_awlen;
wire [2:0]   s_axi_awsize;
wire [1:0]   s_axi_awburst;
wire         s_axi_awlock;
wire [3:0]   s_axi_awcache;
wire [2:0]   s_axi_awprot;
wire         s_axi_awvalid;
wire         s_axi_awready;
wire [511:0] s_axi_wdata;
wire [63:0]  s_axi_wstrb;
wire         s_axi_wlast;
wire         s_axi_wvalid;
wire         s_axi_wready;
wire [1:0]   s_axi_bresp;
wire         s_axi_bvalid;
wire         s_axi_bready;
wire [7:0]   s_axi_arid;
wire [31:0]  s_axi_araddr;
wire [7:0]   s_axi_arlen;
wire [2:0]   s_axi_arsize;
wire [1:0]   s_axi_arburst;
wire         s_axi_arlock;
wire [3:0]   s_axi_arcache;
wire [2:0]   s_axi_arprot;
wire         s_axi_arvalid;
wire         s_axi_arready;
wire [7:0]   s_axi_rid;
wire [511:0] s_axi_rdata;
wire [1:0]   s_axi_rresp;
wire         s_axi_rlast;
wire         s_axi_rvalid;
wire         s_axi_rready;

axi_ram u_axi_ram(
	.clk           	( system_clk     ),    
	.rst           	( ~rst_n         ),
	.s_axi_awid    	( 8'd0           ),  
	.s_axi_awaddr  	( s_axi_awaddr   ),
	.s_axi_awlen   	( s_axi_awlen    ),
	.s_axi_awsize  	( s_axi_awsize   ),
	.s_axi_awburst 	( s_axi_awburst  ),
	.s_axi_awlock  	( s_axi_awlock   ),
	.s_axi_awcache 	( s_axi_awcache  ),
	.s_axi_awprot  	( s_axi_awprot   ),
	.s_axi_awvalid 	( s_axi_awvalid  ),
	.s_axi_awready 	( s_axi_awready  ),
	.s_axi_wdata   	( s_axi_wdata    ),
	.s_axi_wstrb   	( s_axi_wstrb    ),
	.s_axi_wlast   	( s_axi_wlast    ),
	.s_axi_wvalid  	( s_axi_wvalid   ),
	.s_axi_wready  	( s_axi_wready   ),
	.s_axi_bid     	(                ),
	.s_axi_bresp   	( s_axi_bresp    ),
	.s_axi_bvalid  	( s_axi_bvalid   ),
	.s_axi_bready  	( s_axi_bready   ),
	.s_axi_arid    	( 8'd0           ),
	.s_axi_araddr  	( s_axi_araddr   ),
	.s_axi_arlen   	( s_axi_arlen    ),
	.s_axi_arsize  	( s_axi_arsize   ),
	.s_axi_arburst 	( s_axi_arburst  ),
	.s_axi_arlock  	( s_axi_arlock   ),
	.s_axi_arcache 	( s_axi_arcache  ),
	.s_axi_arprot  	( s_axi_arprot   ),
	.s_axi_arvalid 	( s_axi_arvalid  ),
	.s_axi_arready 	( s_axi_arready  ),
	.s_axi_rid     	(                ),
	.s_axi_rdata   	( s_axi_rdata    ),
	.s_axi_rresp   	( s_axi_rresp    ),
	.s_axi_rlast   	( s_axi_rlast    ),
	.s_axi_rvalid  	( s_axi_rvalid   ),
	.s_axi_rready  	( s_axi_rready   )
);

// outports wire
wire        	task_start;
wire        	task_finish;
wire        	calculate_start;
wire          	calculate_finish;
wire [2:0]  	order;
wire [31:0] 	feature_input_base_addr;
wire [7:0]  	feature_input_patch_num;
wire [7:0]  	feature_output_patch_num;
wire        	feature_double_patch;
wire [31:0] 	feature_patch_num;
wire [9:0]  	row_size;
wire [9:0]  	col_size;
wire [3:0]  	weight_quant_size;
wire [3:0]  	fea_in_quant_size;
wire [3:0]  	fea_out_quant_size;
wire        	stride;
wire [31:0] 	return_addr;
wire [15:0] 	return_patch_num;
wire [2:0]  	padding_size;
wire [31:0] 	weight_data_length;

get_order u_get_order(
	.system_clk               	( system_clk                ),
	.rst_n                    	( rst_n                     ),
	.task_start               	( task_start                ),
	.calculate_finish         	( calculate_finish          ),
	.calculate_start          	( calculate_start           ),
	.order                    	( order                     ),
	.feature_input_base_addr  	( feature_input_base_addr   ),
	.feature_input_patch_num  	( feature_input_patch_num   ),
	.feature_output_patch_num 	( feature_output_patch_num  ),
	.feature_double_patch     	( feature_double_patch      ),
	.feature_patch_num        	( feature_patch_num         ),
	.row_size                 	( row_size                  ),
	.col_size                 	( col_size                  ),
	.weight_quant_size        	( weight_quant_size         ),
	.fea_in_quant_size        	( fea_in_quant_size         ),
	.fea_out_quant_size       	( fea_out_quant_size        ),
	.stride                   	( stride                    ),
	.return_addr              	( return_addr               ),
	.return_patch_num         	( return_patch_num          ),
	.padding_size             	( padding_size              ),
	.weight_data_length       	( weight_data_length        )
);

accelerator_control u_accelerator_control(
	.system_clk               	( system_clk                ),
	.rst_n                    	( rst_n                     ),
	.task_start               	( task_start                ),
	.task_finish              	( task_finish               ),
	.calculate_finish         	( calculate_finish          ),
	.calculate_start          	( calculate_start           ),
	.order                    	( order                     ),
	.feature_input_base_addr  	( feature_input_base_addr   ),
	.feature_input_patch_num  	( feature_input_patch_num   ),
	.feature_output_patch_num 	( feature_output_patch_num  ),
	.feature_double_patch     	( feature_double_patch      ),
	.feature_patch_num        	( feature_patch_num         ),
	.row_size                 	( row_size                  ),
	.col_size                 	( col_size                  ),
	.weight_quant_size        	( weight_quant_size         ),
	.fea_in_quant_size        	( fea_in_quant_size         ),
	.fea_out_quant_size       	( fea_out_quant_size        ),
	.stride                   	( stride                    ),
	.return_addr              	( return_addr               ),
	.return_patch_num         	( return_patch_num          ),
	.padding_size             	( padding_size              ),
	.weight_data_length       	( weight_data_length        ),
	.m00_axi_araddr           	( s_axi_araddr            	),
	.m00_axi_arlen            	( s_axi_arlen             	),
	.m00_axi_arsize           	( s_axi_arsize            	),
	.m00_axi_arburst          	( s_axi_arburst           	),
	.m00_axi_arlock           	( s_axi_arlock            	),
	.m00_axi_arcache          	( s_axi_arcache           	),
	.m00_axi_arprot           	( s_axi_arprot            	),
	.m00_axi_arqos            	(              				),
	.m00_axi_arvalid          	( s_axi_arvalid           	),
	.m00_axi_arready          	( s_axi_arready           	),
	.m00_axi_rdata            	( s_axi_rdata             	),
	.m00_axi_rresp            	( s_axi_rresp             	),
	.m00_axi_rlast            	( s_axi_rlast             	),
	.m00_axi_rvalid           	( s_axi_rvalid            	),
	.m00_axi_rready           	( s_axi_rready            	),
	.m00_axi_awaddr           	( s_axi_awaddr              ),
	.m00_axi_awlen            	( s_axi_awlen               ),
	.m00_axi_awsize           	( s_axi_awsize              ),
	.m00_axi_awburst          	( s_axi_awburst             ),
	.m00_axi_awlock           	( s_axi_awlock              ),
	.m00_axi_awcache          	( s_axi_awcache             ),
	.m00_axi_awprot           	( s_axi_awprot            	),
	.m00_axi_awqos            	(              			 	),
	.m00_axi_awvalid          	( s_axi_awvalid           	),
	.m00_axi_awready          	( s_axi_awready           	),
	.m00_axi_wdata            	( s_axi_wdata               ),
	.m00_axi_wstrb            	( s_axi_wstrb             	),
	.m00_axi_wlast            	( s_axi_wlast             	),
	.m00_axi_wvalid           	( s_axi_wvalid            	),
	.m00_axi_wready           	( s_axi_wready            	),
	.m00_axi_bresp            	( s_axi_bresp             	),
	.m00_axi_bvalid           	( s_axi_bvalid            	),
	.m00_axi_bready           	( s_axi_bready            	)
);



endmodule