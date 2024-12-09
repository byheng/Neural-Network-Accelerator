/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
    module_intro: total accelerator control module
    “二十万军重入赣，风烟滚滚来天半
    唤起工农千百万，同心干，不周山下红旗乱”
*/
`timescale 1ns/100fs

`include "../parameters.v"

module accelerator_control #(
    parameter MEM_ADDR_WIDTH    = `MEM_ADDR_WIDTH,
    parameter MEM_DATA_WIDTH    = `MEM_DATA_WIDTH,
    parameter FEATURE_WIDTH     = `FEATURE_WIDTH,
    parameter PE_CORE_NUM       = `PE_CORE_NUM,
    parameter WEIGHT_WIDTH      = `WEIGHT_WIDTH,
    parameter FETURE_DATA_WIDTH = `PE_CORE_NUM * `FEATURE_WIDTH,
    parameter WEIGHT_DATA_WIDTH = `PE_CORE_NUM * WEIGHT_WIDTH,
    parameter MAC_OUTPUT_WIDTH  = `MAC_OUTPUT_WIDTH
)
(
    input                           system_clk,
    input                           rst_n,
    // patch convolution parameters
	input                           task_start,
    input                           task_finish,
    output                          calculate_finish,
    input                           calculate_start,

    // accelerator core parameters (when simulation finish, it will be change to AXI-lite interface)
    input  [2:0]            		order,
	input  [31:0]           		feature_input_base_addr,
	input  [7:0]            		feature_input_patch_num,
	input  [7:0]            		feature_output_patch_num,
	input                   		feature_double_patch,
	input  [31:0]           		feature_patch_num,
	input  [9:0]            		row_size,
	input  [9:0]            		col_size,
	input  [3:0]            		weight_quant_size,
	input  [3:0]            		fea_in_quant_size,
	input  [3:0]            		fea_out_quant_size,
	input                   		stride,
	input  [31:0]           		return_addr,
	input  [15:0]           		return_patch_num,
	input  [2:0]            		padding_size,
	input  [31:0]					weight_data_length,
    // AXI-signal for ddr port
    // AXI-4 Only read
    output  [MEM_ADDR_WIDTH-1:0]    m00_axi_araddr,     // 操控
    output  [7:0]                   m00_axi_arlen,      // 操控
    output  [2:0]                   m00_axi_arsize, 
    output  [1:0]                   m00_axi_arburst,
    output                          m00_axi_arlock,
    output  [3:0]                   m00_axi_arcache,
    output  [2:0]                   m00_axi_arprot,
    output  [3:0]                   m00_axi_arqos,
    output                          m00_axi_arvalid,    // 操控
    input                           m00_axi_arready,    // 操控
    input   [MEM_DATA_WIDTH-1:0]    m00_axi_rdata,      // 操控
    input   [1:0]                   m00_axi_rresp,
    input                           m00_axi_rlast,      // 操控
    input                           m00_axi_rvalid,     // 操控
    output                          m00_axi_rready,     // 操控  
    // AXI-4 only for write
    output [MEM_ADDR_WIDTH-1:0]     m00_axi_awaddr,
    output [7:0]                    m00_axi_awlen,
    output [2:0]                    m00_axi_awsize,
    output [1:0]                    m00_axi_awburst,
    output                          m00_axi_awlock,
    output [3:0]                    m00_axi_awcache,
    output [2:0]                    m00_axi_awprot,
    output [3:0]                    m00_axi_awqos,
    output                          m00_axi_awvalid,
    input                           m00_axi_awready,
    output [MEM_DATA_WIDTH-1:0]     m00_axi_wdata,
    output [63:0]                   m00_axi_wstrb,
    output                          m00_axi_wlast,
    output                          m00_axi_wvalid,
    input                           m00_axi_wready,
    input  [1:0]                    m00_axi_bresp,
    input                           m00_axi_bvalid,
    output                          m00_axi_bready
);

// local parameter declaration
localparam [2:0] WAIT_TASK_BEGIN         = 3'd0,
                 WAIT_ORDER              = 3'd1,
                 WAIT_CONVOLUTION_FINISH = 3'd2;
localparam [2:0] CONVOLUTION = 3'd1;

localparam [2:0] WAIT_CONVOLUTION_BEGIN  = 3'd0,
				 CHANGE_WEIGHT_BIAS      = 3'd1,
			     WAIT_BIAS_WEIGHT_READY  = 3'd2,
				 WAIT_CALCULATION_DONE   = 3'd3,
				 CHECK_INPUT_PATCH_NUM   = 3'd4,
				 WAIT_RETURN_FINISH      = 3'd5,
				 CHECK_OUTPUT_PATCH_NUM  = 3'd6,
                 CONVOLUTION_FINISH      = 3'd7;


// variables declaration
reg  [2:0]                      task_state;
reg  [2:0]                      convolution_state;
wire                            feature_buffer_1_valid;
wire                            feature_buffer_2_valid;
wire                            feature_buffer_1_ready;
wire                            feature_buffer_2_ready;
wire [MEM_DATA_WIDTH-1:0]		feature_data;	
wire [FETURE_DATA_WIDTH-1:0]    feature_output_data;
wire                            feature_output_valid;
wire                            feature_output_ready;
wire [MEM_DATA_WIDTH-1:0]       weight_and_bias_data; 
wire                            weight_and_bias_valid;
wire                            weight_buffer_ready; 
wire [WEIGHT_DATA_WIDTH-1:0]    weight_bias_output_data; 
wire [8:0]                      weight_bias_output_valid;   
wire [WEIGHT_DATA_WIDTH-1:0]    weight;
wire [7:0]                      weight_valid;
wire [WEIGHT_DATA_WIDTH-1:0]    bias;
wire                            bias_valid;
wire [MAC_OUTPUT_WIDTH*8-1:0]   data_for_act;
wire                            data_for_act_valid;
wire [FEATURE_WIDTH*8-1:0]      act_data;
wire                            act_data_valid;
wire [FEATURE_WIDTH*8-1:0]      return_data;
wire                            return_data_valid;
wire                            return_buffer_ready;
wire                            weight_and_bias_ready;
reg  [1:0]						change_weight_bias;
reg  [7:0]						input_patch_cnt;
reg  [7:0]						output_patch_cnt;
wire                            convolution_calculate_begin;	
wire                            convolution_calculate_finish;
reg                             return_req;	
reg      						pull_out_req;
wire                            return_finish;
wire                            pull_finish;
reg                             load_feature_begin;
reg                             free_feature_read_addr;
reg                             refresh_return_addr;
wire [FETURE_DATA_WIDTH*3-1:0]	feature_cache_data;
wire [MAC_OUTPUT_WIDTH*8-1:0]	adder_feature;
wire [MAC_OUTPUT_WIDTH*8-1:0]	feature_out;
wire                            rebuild_structure;
wire                            bias_or_adder_feature;
wire                            convolution_valid;
wire                            feature_valid;
wire                            refresh_req;
reg                             pull_where;
wire                            pull_ready;
wire                            direct_out;
wire [MAC_OUTPUT_WIDTH*8-1:0]   data_to_act_func;
wire                            data_to_act_func_valid;
wire                            output_buffer_done;
wire                            adder_pulse;

/*------------------------------- accelerator control logic ------------------------------*/
// ------------------- task state machine -------------------
always@(posedge system_clk or negedge rst_n) begin
    if (!rst_n) begin
        task_state <= WAIT_TASK_BEGIN;
    end else begin
        case (task_state)
            WAIT_TASK_BEGIN: begin
                if (task_start) begin
                    task_state <= WAIT_ORDER;
                end
            end

            WAIT_ORDER: begin
                if (calculate_start) begin
                    case (order)
                        CONVOLUTION: begin
                            task_state <= WAIT_CONVOLUTION_FINISH;
                        end
                    endcase
                end
                else if (task_finish) begin
                    task_state <= WAIT_TASK_BEGIN;
                end
            end

            WAIT_CONVOLUTION_FINISH: begin
                if (convolution_state == CONVOLUTION_FINISH) begin
                    task_state <= WAIT_ORDER;
                end
            end
        endcase
    end
end

/*-------------------------------- convolution state machine --------------------------*/
always@(posedge system_clk or negedge rst_n) begin
    if (!rst_n) begin
        convolution_state <= WAIT_CONVOLUTION_BEGIN;
    end
    else begin
        case (convolution_state)
			WAIT_CONVOLUTION_BEGIN: begin
                if (task_state == WAIT_CONVOLUTION_FINISH) begin
					convolution_state <= CHANGE_WEIGHT_BIAS;
				end
			end

			CHANGE_WEIGHT_BIAS: begin
				convolution_state <= WAIT_BIAS_WEIGHT_READY;
			end

			WAIT_BIAS_WEIGHT_READY: begin
				if (weight_and_bias_ready) begin
					convolution_state <= WAIT_CALCULATION_DONE;
				end
			end

			WAIT_CALCULATION_DONE: begin
				if (convolution_calculate_finish) begin
					convolution_state <= CHECK_INPUT_PATCH_NUM;
				end
			end

			CHECK_INPUT_PATCH_NUM: begin
				if (input_patch_cnt == feature_input_patch_num) begin
					convolution_state <= WAIT_RETURN_FINISH;
				end
				else begin
					convolution_state <= CHANGE_WEIGHT_BIAS;
				end
			end

			WAIT_RETURN_FINISH: begin
				if (return_finish) begin
					convolution_state <= CHECK_OUTPUT_PATCH_NUM;
				end
			end

			CHECK_OUTPUT_PATCH_NUM: begin
				if (output_patch_cnt == feature_output_patch_num) begin
					convolution_state <= CONVOLUTION_FINISH;
				end
				else begin
					convolution_state <= CHANGE_WEIGHT_BIAS;
				end
			end

			CONVOLUTION_FINISH: begin
				convolution_state <= WAIT_CONVOLUTION_BEGIN;
			end
		endcase
    end
end

always@(posedge system_clk or negedge rst_n) begin
    if (!rst_n) begin
		change_weight_bias<= 2'b0;
	end
	else if (convolution_state == CHANGE_WEIGHT_BIAS) begin
		if (change_weight_bias==2'b0) begin
			if (input_patch_cnt == 8'd0) begin
				change_weight_bias <= 2'b11;
			end
			else begin
				change_weight_bias <= 2'b01;
			end
		end
	end
	else begin
		change_weight_bias<= 2'b0;
	end
end

always@(posedge system_clk or negedge rst_n) begin
    if (!rst_n) begin
        input_patch_cnt <= 8'd0;
	end
	else if (convolution_state == WAIT_CONVOLUTION_BEGIN) begin
		input_patch_cnt <= 8'd0;
	end 
	else if ((convolution_state == WAIT_CALCULATION_DONE) & convolution_calculate_finish) begin
		input_patch_cnt <= input_patch_cnt + 8'd1;
	end
	else if ((convolution_state == CHECK_INPUT_PATCH_NUM) && (input_patch_cnt == feature_input_patch_num)) begin
		input_patch_cnt <= 8'd0;
	end
end

always@(posedge system_clk or negedge rst_n) begin
	if (!rst_n) begin
        output_patch_cnt <= 8'd0;
	end
	else if ((convolution_state == WAIT_RETURN_FINISH) & return_finish) begin
		output_patch_cnt <= output_patch_cnt + 8'd1;
	end
	else if (convolution_state == CONVOLUTION_FINISH) begin
		output_patch_cnt <= 8'd0;
	end
end

always@(posedge system_clk or negedge rst_n) begin
	if (!rst_n) begin
		load_feature_begin <= 0;
	end
	else if (change_weight_bias) begin
		load_feature_begin <= 1;
	end
	else begin
		load_feature_begin <= 0;
	end
end

always@(posedge system_clk or negedge rst_n) begin
	if (!rst_n) begin
		free_feature_read_addr <= 0;
	end
	else if ((convolution_state == CHECK_INPUT_PATCH_NUM) && (input_patch_cnt == feature_input_patch_num)) begin
		free_feature_read_addr <= 1;
	end
	else begin
		free_feature_read_addr <= 0;
	end
end

always@(posedge system_clk or negedge rst_n) begin
	if (!rst_n) begin
        return_req <= 0;
	end
	// else if ((convolution_state == CHECK_INPUT_PATCH_NUM) && (input_patch_cnt == feature_input_patch_num) && (~direct_out)) begin
	// 	return_req <= 1;
	// end
	else if ((convolution_state == CHANGE_WEIGHT_BIAS) && (direct_out)) begin
		return_req <= 1;
	end
	else begin
		return_req <= 0;
	end
end

always@(posedge system_clk or negedge rst_n) begin
	if (!rst_n) begin
		pull_out_req <= 0;
	end
	// else if ((convolution_state == CHECK_INPUT_PATCH_NUM) && (input_patch_cnt == feature_input_patch_num) && !direct_out) begin
	// 	pull_out_req <= 1;
	// end
	else begin
		pull_out_req <= 0;
	end
end

always@(posedge system_clk or negedge rst_n) begin
	if (!rst_n) begin
		refresh_return_addr <= 0;
	end
	else if (return_req & output_patch_cnt == 0) begin
		refresh_return_addr <= 1;
	end
	else begin
		refresh_return_addr <= 0;
	end
end

always@(posedge system_clk or negedge rst_n) begin
	if (!rst_n) begin
		pull_where <= 0;
	end
	else if (return_req) begin
		pull_where <= 1;
	end
	else if (return_finish) begin
		pull_where <= 0;
	end
end

// assign signals
assign weight            = weight_bias_output_data;
assign weight_valid      = weight_bias_output_valid[7:0];
assign bias              = weight_bias_output_data;
assign bias_valid        = weight_bias_output_valid[8];
assign return_data       = act_data;
assign return_data_valid = act_data_valid;

assign convolution_calculate_begin = (convolution_state == WAIT_BIAS_WEIGHT_READY) & weight_and_bias_ready;

assign calculate_finish = (task_state == WAIT_ORDER) | (task_state == WAIT_TASK_BEGIN);

assign feature_output_ready = (task_state == WAIT_CONVOLUTION_FINISH) ? return_buffer_ready : 1'b0;

assign rebuild_structure = 1'b0;

assign bias_or_adder_feature = (input_patch_cnt == 0) ? 1'b1 : 1'b0;

assign feature_valid = convolution_valid;

assign refresh_req = |change_weight_bias;

assign pull_ready = return_buffer_ready;

assign direct_out = (input_patch_cnt == feature_input_patch_num - 1);

assign output_buffer_done = (direct_out) ? (convolution_state == WAIT_RETURN_FINISH) : pull_finish;

// instantiate
read_ddr_control u_read_ddr_control(
	.system_clk              	( system_clk               ),
	.rst_n                   	( rst_n                    ),
	.task_start              	( task_start               ),
	.weight_data_length      	( weight_data_length       ),
	.weight_and_bias_data    	( weight_and_bias_data     ),
	.weight_and_bias_valid   	( weight_and_bias_valid    ),
	.weight_buffer_ready     	( weight_buffer_ready      ),
	.feature_output_data     	( feature_data      	   ),
	.feature_buffer_1_valid  	( feature_buffer_1_valid   ),
	.feature_buffer_2_valid  	( feature_buffer_2_valid   ),
	.feature_buffer_1_ready  	( feature_buffer_1_ready   ),
	.feature_buffer_2_ready  	( feature_buffer_2_ready   ),
	.feature_double_patch    	( feature_double_patch     ),
	.feature_input_base_addr 	( feature_input_base_addr  ),
	.feature_patch_num      	( feature_patch_num        ),
	.load_feature_begin      	( load_feature_begin       ),
	.free_feature_read_addr  	( free_feature_read_addr   ),
	.m00_axi_araddr          	( m00_axi_araddr           ),
	.m00_axi_arlen           	( m00_axi_arlen            ),
	.m00_axi_arsize          	( m00_axi_arsize           ),
	.m00_axi_arburst         	( m00_axi_arburst          ),
	.m00_axi_arlock          	( m00_axi_arlock           ),
	.m00_axi_arcache         	( m00_axi_arcache          ),
	.m00_axi_arprot          	( m00_axi_arprot           ),
	.m00_axi_arqos           	( m00_axi_arqos            ),
	.m00_axi_arvalid         	( m00_axi_arvalid          ),
	.m00_axi_arready         	( m00_axi_arready          ),
	.m00_axi_rdata           	( m00_axi_rdata            ),
	.m00_axi_rresp           	( m00_axi_rresp            ),
	.m00_axi_rlast           	( m00_axi_rlast            ),
	.m00_axi_rvalid          	( m00_axi_rvalid           ),
	.m00_axi_rready          	( m00_axi_rready           )
);

feature_buffer u_feature_buffer(
	.system_clk             	( system_clk              	  	),
	.rst_n                  	( rst_n                   	  	),
	.calculate_begin        	( convolution_calculate_begin 	),
	.calculate_finish       	( convolution_calculate_finish	),
	.row_size               	( row_size                		),
	.col_size               	( col_size                		),
	.stride                 	( stride                  		),
	.padding_size           	( padding_size            		),
	.feature_data           	( feature_data            		),
	.feature_buffer_1_valid 	( feature_buffer_1_valid  		),
	.feature_buffer_2_valid 	( feature_buffer_2_valid  		),
	.feature_buffer_1_ready 	( feature_buffer_1_ready  		),
	.feature_buffer_2_ready 	( feature_buffer_2_ready  		),
	.feature_double_patch   	( feature_double_patch    		),
	.feature_output_data    	( feature_output_data     		),
	.feature_output_valid   	( feature_output_valid    		),
	.feature_output_ready   	( feature_output_ready    		),
	.convolution_valid			( convolution_valid				),
	.adder_pulse				( adder_pulse					)	
);

feature_row_Cache u_feature_row_Cache(
	.system_clk           	( system_clk            ),
	.rst_n                	( rst_n                 ),
	.feature_output_data  	( feature_output_data   ),
	.feature_output_valid 	( feature_output_valid  ),
	.feature_cache_data   	( feature_cache_data    ),
	.feature_cache_valid  	( feature_cache_valid   ),
	.rebuild_structure    	( rebuild_structure     ),
	.col_size             	( col_size              )
);

Weight_buffer u_Weight_buffer(
	.system_clk               	( system_clk                ),
	.rst_n                    	( rst_n                     ),
	.weight_and_bias_data     	( weight_and_bias_data      ),
	.weight_and_bias_valid    	( weight_and_bias_valid     ),
	.weight_buffer_ready        ( weight_buffer_ready       ),
	.weight_and_bias_ready    	( weight_and_bias_ready     ),
	.change_weight_bias       	( change_weight_bias        ),
	.weight_bias_output_data  	( weight_bias_output_data   ),
	.weight_bias_output_valid 	( weight_bias_output_valid  )
);

convolution_core u_convolution_core(
	.DSP_clk               	( system_clk             ),
	.rst_n                 	( rst_n                  ),
	.weight                	( weight                 ),
	.weight_valid          	( weight_valid           ),
	.feature_in            	( feature_cache_data     ),
	.bias                  	( bias                   ),
	.bias_valid            	( bias_valid             ),
	.adder_feature         	( adder_feature          ),
	.bias_or_adder_feature 	( bias_or_adder_feature  ),
	.pulse                 	( feature_cache_valid    ),
	.feature_out           	( feature_out            )
);

Output_buffer u_Output_buffer(
	.system_clk         	( system_clk          ),
	.rst_n              	( rst_n               ),
	.refresh_req        	( refresh_req         ),
	.pull_out_req       	( pull_out_req        ),
	.pull_finish        	( pull_finish         ),
	.pull_where         	( pull_where          ),
	.pull_ready         	( pull_ready          ),
	.data_for_act       	( data_for_act        ),
	.data_for_act_valid 	( data_for_act_valid  ),
	.adder_pulse        	( adder_pulse         ),
	.adder_feature      	( adder_feature       ),
	.feature_in         	( feature_out         ),
	.feature_valid      	( feature_valid       )
);

activate_function u_activate_function(
	.system_clk         	( system_clk          	),
	.rst_n              	( rst_n               	),
	.data_for_act       	( data_to_act_func    	),
	.data_for_act_valid 	( data_to_act_func_valid),
	.act_data           	( act_data            	),
	.act_data_valid     	( act_data_valid      	),
	.fea_in_quant_size  	( fea_in_quant_size   	),
	.fea_out_quant_size 	( fea_out_quant_size  	),
	.weight_quant_size  	( weight_quant_size   	)
);

return_buffer u_return_buffer(
	.system_clk          	( system_clk           ),
	.rst_n               	( rst_n                ),
	.refresh_return_addr 	( refresh_return_addr  ),
	.return_req          	( return_req           ),
	.return_finish       	( return_finish        ),
	.return_patch_num    	( return_patch_num     ),
	.return_addr         	( return_addr          ),
	.return_data         	( return_data          ),
	.return_data_valid   	( return_data_valid    ),
	.return_buffer_ready 	( return_buffer_ready  ),
	.output_buffer_done  	( output_buffer_done   ),
	.m00_axi_awaddr      	( m00_axi_awaddr       ),
	.m00_axi_awlen       	( m00_axi_awlen        ),
	.m00_axi_awsize      	( m00_axi_awsize       ),
	.m00_axi_awburst     	( m00_axi_awburst      ),
	.m00_axi_awlock      	( m00_axi_awlock       ),
	.m00_axi_awcache     	( m00_axi_awcache      ),
	.m00_axi_awprot      	( m00_axi_awprot       ),
	.m00_axi_awqos       	( m00_axi_awqos        ),
	.m00_axi_awvalid     	( m00_axi_awvalid      ),
	.m00_axi_awready     	( m00_axi_awready      ),
	.m00_axi_wdata       	( m00_axi_wdata        ),
	.m00_axi_wstrb       	( m00_axi_wstrb        ),
	.m00_axi_wlast       	( m00_axi_wlast        ),
	.m00_axi_wvalid      	( m00_axi_wvalid       ),
	.m00_axi_wready      	( m00_axi_wready       ),
	.m00_axi_bresp       	( m00_axi_bresp        ),
	.m00_axi_bvalid      	( m00_axi_bvalid       ),
	.m00_axi_bready      	( m00_axi_bready       )
);

act_feature_arbitra act_feature_arbitra_inst(
    .system_clk   					( system_clk			),
    .rst_n        					( rst_n					),
    .direct_out   					( direct_out			),
    .data_from_output_buffer 		( data_for_act			),
    .data_from_output_buffer_valid	( data_for_act_valid	),
    .data_from_conv_core 			( feature_out			),
    .data_from_conv_core_valid		( feature_valid			),
    .data_to_act_func				( data_to_act_func  	),
    .data_to_act_func_valid			( data_to_act_func_valid)
);

endmodule
