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
    parameter MAC_OUTPUT_WIDTH  = `MAC_OUTPUT_WIDTH,
    parameter POOL_DATA_WIDTH   = 5 * `FEATURE_WIDTH,
	parameter AXIL_DATA_WIDTH	= 32,
	parameter AXIL_ADDR_WIDTH	= 8
)
(
    input                           system_clk,
    input                           rst_n,
    // accelerator core parameters (when simulation finish, it will be change to AXI-lite interface)

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
    output                          m00_axi_bready,
	// AXI-lite interface for setup parameters
	input							s00_axi_aclk,	
	input                           s00_axi_aresetn,
	input 	[AXIL_ADDR_WIDTH-1:0] 	s00_axi_awaddr,
	input 	[2 : 0] 				s00_axi_awprot,
	input 	 						s00_axi_awvalid,
	output 	 						s00_axi_awready,
	input 	[AXIL_DATA_WIDTH-1:0] 	s00_axi_wdata,
	input [(AXIL_DATA_WIDTH/8)-1:0] s00_axi_wstrb,
	input 	 						s00_axi_wvalid,
	output 	 						s00_axi_wready,
	output 	[1 : 0] 				s00_axi_bresp,
	output 	 						s00_axi_bvalid,
	input 	 						s00_axi_bready,
	input 	[AXIL_ADDR_WIDTH-1 : 0] s00_axi_araddr,
	input 	[2 : 0] 				s00_axi_arprot,
	input 	 						s00_axi_arvalid,
	output 	 						s00_axi_arready,
	output 	[AXIL_DATA_WIDTH-1 : 0] s00_axi_rdata,
	output 	[1 : 0] 				s00_axi_rresp,
	output 	 						s00_axi_rvalid,
	input 	 						s00_axi_rready
);

// local parameter declaration
localparam [2:0] WAIT_TASK_BEGIN         = 3'd0,
                 WAIT_ORDER              = 3'd1,
                 WAIT_CONVOLUTION_FINISH = 3'd2,
				 WAIT_ADD_FINISH         = 3'd3,
				 WAIT_OPERATOR_FINISH    = 3'd4;
localparam [2:0] CONVOLUTION = 3'd1,
				 ADD         = 3'd2,
				 POOL        = 3'd3,
				 UPSAMPLE    = 3'd4;

localparam [2:0] WAIT_CONVOLUTION_BEGIN  = 3'd0,
				 CHANGE_WEIGHT_BIAS      = 3'd1,
			     WAIT_BIAS_WEIGHT_READY  = 3'd2,
				 WAIT_CALCULATION_DONE   = 3'd3,
				 CHECK_INPUT_PATCH_NUM   = 3'd4,
				 WAIT_RETURN_FINISH      = 3'd5,
				 CHECK_OUTPUT_PATCH_NUM  = 3'd6,
                 CONVOLUTION_FINISH      = 3'd7;

localparam [1:0] WAIT_ADD_BEGIN          = 2'd0,
				 WAIT_ADD_DONE           = 2'd1,
				 WAIT_A_RETURN_FINISH    = 2'd2,
				 ADD_FINISH              = 2'd3;

localparam [2:0] WAIT_BEGIN         	 = 3'd0,
				 LOAD_FEATURE            = 3'd1,
				 WAIT_COMPUTE_DONE       = 3'd2,
				 WAIT_S_RETURN_FINISH    = 3'd3,
				 CHECK_IN_PATCH_NUM      = 3'd4,
				 OPERTOR_FINISH          = 3'd5;

// accelerator parameters
wire 		 task_start					;
wire 		 task_finish				;	
wire 		 calculate_finish			;	
wire 		 calculate_start			;	
wire  [2:0]  order						;
wire  [31:0] feature_input_base_addr	;
wire  [7:0]  feature_input_patch_num	;
wire  [7:0]  feature_output_patch_num	;
wire         feature_double_patch		;
wire  [31:0] feature_patch_num			;
wire  [9:0]  row_size					;
wire  [9:0]  col_size					;
wire  [3:0]  weight_quant_size			;
wire  [3:0]  fea_in_quant_size			;
wire  [3:0]  fea_out_quant_size			;
wire         stride						;
wire  [31:0] return_addr				;
wire  [15:0] return_patch_num			;		
wire  [2:0]  padding_size				;
wire  [31:0] weight_data_length			;
wire         activate					;

// variables declaration
reg  [2:0]                      task_state;
reg  [2:0]                      convolution_state;
reg  [1:0]	                    add_state;
reg  [2:0]						single_operator_state;
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
reg                             compute_begin;	
wire                            compute_finish;
reg                             return_req;	
wire                            return_finish;
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
reg                             direct_out;
reg                             output_buffer_done;
wire                            adder_pulse;
wire [FETURE_DATA_WIDTH/2-1:0]  feature_x1_in;
wire [FETURE_DATA_WIDTH/2-1:0]  feature_x2_in;
wire [FETURE_DATA_WIDTH/2-1:0]  feature_upsample;
wire [FETURE_DATA_WIDTH/2-1:0]  feature_add_data_out;
wire                            feature_add_data_valid;
wire [3:0]						return_select;
wire                            convolution_working;
wire                            add_layer_working;
wire                            pool_layer_working;
wire                            upsample_working;
wire [POOL_DATA_WIDTH*8-1:0]	pool_cache_data;
wire [FEATURE_WIDTH*8-1:0]		pool_data_out;
wire [FEATURE_WIDTH*8-1:0] 		unsample_feature;
wire [9:0]						col_size_for_cache;
wire [2:0]						kernel_size;
wire                            upsample_ready;
wire                            unsample_feature_valid;
wire                            upsample_buffer_empty;
wire                            single_operator_buffer_done;

integer i;

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
						ADD: begin
							task_state <= WAIT_ADD_FINISH;
						end
						POOL: begin
							task_state <= WAIT_OPERATOR_FINISH;
						end
						UPSAMPLE: begin
							task_state <= WAIT_OPERATOR_FINISH;
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

			WAIT_ADD_FINISH: begin
				if (add_state == ADD_FINISH) begin
					task_state <= WAIT_ORDER;
				end
			end

			WAIT_OPERATOR_FINISH: begin
				if (single_operator_state == OPERTOR_FINISH) begin
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
				if (compute_finish) begin
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

/*-------------------------------- add layer state machine --------------------------*/
always@(posedge system_clk or negedge rst_n) begin
    if (!rst_n) begin
        add_state <= 2'b00;
    end
    else begin
		case (add_state)
			WAIT_ADD_BEGIN: begin
				if (task_state == WAIT_ADD_FINISH) begin
					add_state <= WAIT_ADD_DONE;
				end
			end
			WAIT_ADD_DONE: begin
				if (compute_finish) begin
					add_state <= WAIT_A_RETURN_FINISH;
				end
			end

			WAIT_A_RETURN_FINISH: begin
				if (return_finish) begin
					add_state <= ADD_FINISH;
				end
			end

			ADD_FINISH: begin
				add_state <= WAIT_ADD_BEGIN;
			end
		endcase
	end
end

/*-------------------------------- pool layer state machine --------------------------*/
always@(posedge system_clk or negedge rst_n) begin
    if (!rst_n) begin
        single_operator_state <= WAIT_BEGIN;
    end
    else begin
		case (single_operator_state)
			WAIT_BEGIN: begin
				if (task_state == WAIT_OPERATOR_FINISH) begin
					single_operator_state <= LOAD_FEATURE;
				end
			end

			LOAD_FEATURE: begin
				single_operator_state <= WAIT_COMPUTE_DONE;
			end

			WAIT_COMPUTE_DONE: begin
				if (compute_finish) begin
					single_operator_state <= WAIT_S_RETURN_FINISH;
				end
			end

			WAIT_S_RETURN_FINISH: begin
				if (return_finish) begin
					single_operator_state <= CHECK_IN_PATCH_NUM;
				end
			end

			CHECK_IN_PATCH_NUM: begin
				if (input_patch_cnt == feature_input_patch_num) begin
					single_operator_state <= OPERTOR_FINISH;
				end
				else begin
					single_operator_state <= LOAD_FEATURE;
				end
			end

			OPERTOR_FINISH: begin
				single_operator_state <= WAIT_BEGIN;
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
	// else if (convolution_state == WAIT_CONVOLUTION_BEGIN) begin
	// 	input_patch_cnt <= 8'd0;
	// end 
	else if ((convolution_state == WAIT_CALCULATION_DONE) & compute_finish) begin
		input_patch_cnt <= input_patch_cnt + 8'd1;
	end
	else if ((single_operator_state == WAIT_S_RETURN_FINISH) & return_finish) begin
		input_patch_cnt <= input_patch_cnt + 8'd1;
	end
	else if ((convolution_state == WAIT_RETURN_FINISH) | (single_operator_state == OPERTOR_FINISH)) begin
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
	else if (change_weight_bias) begin	// convolution begin
		load_feature_begin <= 1;
	end
	else if ((add_state == WAIT_ADD_BEGIN) & (task_state == WAIT_ADD_FINISH)) begin	// add begin
		load_feature_begin <= 1;
	end
	else if (single_operator_state == LOAD_FEATURE) begin
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
	else if (add_state == ADD_FINISH) begin
		free_feature_read_addr <= 1;
	end
	else if (single_operator_state == OPERTOR_FINISH) begin
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
	else if ((convolution_state == CHANGE_WEIGHT_BIAS) && (input_patch_cnt == feature_input_patch_num - 1)) begin
		return_req <= 1;
	end
	else if ((add_state == WAIT_ADD_BEGIN) & (task_state == WAIT_ADD_FINISH)) begin  // add begin
		return_req <= 1;
	end
	else if (single_operator_state == LOAD_FEATURE) begin
		return_req <= 1;
	end
	else begin
		return_req <= 0;
	end
end

always@(posedge system_clk or negedge rst_n) begin
	if (!rst_n) begin
		refresh_return_addr <= 0;
	end
	else if (return_req & output_patch_cnt == 0 & (convolution_state != WAIT_CONVOLUTION_BEGIN)) begin
		refresh_return_addr <= 1;
	end
	else if ((add_state == WAIT_ADD_BEGIN) & (task_state == WAIT_ADD_FINISH)) begin
		refresh_return_addr <= 1;
	end
	else if ((single_operator_state == LOAD_FEATURE) & (input_patch_cnt == 0)) begin
		refresh_return_addr <= 1;
	end
	else begin
		refresh_return_addr <= 0;
	end
end

always@(posedge system_clk or negedge rst_n) begin
	if (!rst_n) begin
		direct_out <= 0;
	end
	else if (convolution_state == CHANGE_WEIGHT_BIAS) begin
		if (input_patch_cnt == feature_input_patch_num - 1) begin
			direct_out <= 1;
		end
		else begin
			direct_out <= 0;
		end
	end
end

always@(posedge system_clk or negedge rst_n) begin
	if (!rst_n) begin
		compute_begin <= 0;
	end
	else if ((convolution_state == WAIT_BIAS_WEIGHT_READY) & weight_and_bias_ready) begin
		compute_begin <= 1;
	end
	else if ((add_state == WAIT_ADD_BEGIN) & (task_state == WAIT_ADD_FINISH)) begin
		compute_begin <= 1;
	end
	else if (single_operator_state == LOAD_FEATURE) begin
		compute_begin <= 1;
	end
	else begin
		compute_begin <= 0;
	end
end

always@(posedge system_clk or negedge rst_n) begin
	if (!rst_n) begin
		output_buffer_done <= 0;
	end
	else if (convolution_state == WAIT_RETURN_FINISH) begin
		output_buffer_done <= 1;
	end
	else if (add_state == WAIT_A_RETURN_FINISH) begin
		output_buffer_done <= 1;
	end
	else if ((single_operator_state == WAIT_S_RETURN_FINISH) & single_operator_buffer_done) begin
		output_buffer_done <= 1;
	end
	else begin
		output_buffer_done <= 0;
	end
end


// assign signals
assign weight            = weight_bias_output_data;
assign weight_valid      = weight_bias_output_valid[7:0];
assign bias              = weight_bias_output_data;
assign bias_valid        = weight_bias_output_valid[8];

assign calculate_finish = (task_state == WAIT_ORDER) | (task_state == WAIT_TASK_BEGIN);

assign feature_output_ready = (direct_out & convolution_working) ? return_buffer_ready : 
							  (upsample_working) ? upsample_ready : 1'b1;

assign rebuild_structure = pool_layer_working ? 1'b1 : 1'b0;

assign bias_or_adder_feature = (input_patch_cnt == 0) ? 1'b1 : 1'b0;

assign feature_valid = convolution_valid;

assign refresh_req = |change_weight_bias;

assign data_for_act = feature_out;
assign data_for_act_valid = direct_out & feature_valid;

// split data for adder layer
assign feature_x1_in = feature_output_data[FETURE_DATA_WIDTH/2-1:0];					// lower 8 channel feature for adder x1
assign feature_x2_in = feature_output_data[FETURE_DATA_WIDTH-1:FETURE_DATA_WIDTH/2];    // upper 8 channel feature for adder x2
assign feature_upsample = feature_output_data[FETURE_DATA_WIDTH/2-1:0];

assign convolution_working = (convolution_state != WAIT_CONVOLUTION_BEGIN);
assign add_layer_working = (add_state != WAIT_ADD_BEGIN);
assign pool_layer_working = (single_operator_state != WAIT_BEGIN) & (order == POOL);
assign upsample_working = (single_operator_state != WAIT_BEGIN) & (order == UPSAMPLE);

assign return_select = {upsample_working, pool_layer_working, add_layer_working, convolution_working};

assign kernel_size = pool_layer_working ? 5 : 3; 

assign single_operator_buffer_done = (upsample_working) ? upsample_buffer_empty : 1'b1;

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
	.compute_begin        	    ( compute_begin           		),
	.compute_finish       	    ( compute_finish				),
	.load_feature_begin			( load_feature_begin			),
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
	.pool_data_valid			( pool_data_valid				),
	.adder_pulse				( adder_pulse					),
	.col_size_for_cache			( col_size_for_cache			),
	.kernel_size				( kernel_size					)
);

feature_row_Cache u_feature_row_Cache(
	.system_clk           	( system_clk            					  ),
	.rst_n                	( rst_n                 					  ),
	.feature_output_data  	( feature_output_data   					  ),
	.feature_output_valid 	( feature_output_valid & (convolution_working | pool_layer_working)  ),
	.feature_cache_data   	( feature_cache_data    					  ),
	.pool_cache_data		( pool_cache_data       					  ),
	.feature_cache_valid  	( feature_cache_valid   					  ),
	.rebuild_structure    	( rebuild_structure     					  ),
	.col_size             	( col_size_for_cache              			  )
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
	.pulse                 	( feature_cache_valid & convolution_working ),
	.feature_out           	( feature_out            )
);

Output_buffer u_Output_buffer(
	.system_clk         	( system_clk          ),
	.rst_n              	( rst_n               ),
	.refresh_req        	( refresh_req         ),
	.adder_pulse        	( adder_pulse         ),
	.adder_feature      	( adder_feature       ),
	.feature_in         	( feature_out         ),
	.feature_valid      	( feature_valid       )
);

activate_function u_activate_function(
	.system_clk         	( system_clk          	),
	.rst_n              	( rst_n               	),
	.data_for_act       	( data_for_act    		),
	.data_for_act_valid 	( data_for_act_valid	),
	.act_data           	( act_data            	),
	.act_data_valid     	( act_data_valid      	),
	.fea_in_quant_size  	( fea_in_quant_size   	),
	.fea_out_quant_size 	( fea_out_quant_size  	),
	.weight_quant_size  	( weight_quant_size   	),
	.activate				( activate				)
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

feature_add u_feature_add(
	.system_clk             	( system_clk              ),
	.rst_n                  	( rst_n                   ),
	.feature_x1_in          	( feature_x1_in			  ),
	.feature_x2_in          	( feature_x2_in			  ),
	.feature_x_valid_in     	( feature_output_valid    ),
	.feature_data_out       	( feature_add_data_out    ),
	.feature_data_valid_out 	( feature_add_data_valid  )
);

return_data_arbitra  u_return_data_arbitra(
	.system_clk        	( system_clk         	),
	.rst_n             	( rst_n              	),
	.select            	( return_select         ),
	.data1             	( act_data           	),
	.data1_valid       	( act_data_valid     	),
	.data2             	( feature_add_data_out	),
	.data2_valid       	( feature_add_data_valid),
	.data3				( pool_data_out			),
	.data3_valid		( pool_data_valid		),
	.data4				( unsample_feature		),
	.data4_valid		( unsample_feature_valid),
	.return_data       	( return_data        	),
	.return_data_valid 	( return_data_valid  	)
);

pool_array pool_array_u(
    .DSP_clk		( system_clk 	  	  ),
    .rst_n			( rst_n      	  	  ), 
    .feature		( pool_cache_data 	  ),      
    .pulse			( feature_cache_valid & pool_layer_working ),
    .feature_out	( pool_data_out 	  )
);

upsample u_upsample(
	.system_clk             	( system_clk              ),
	.rst_n                  	( rst_n                   ),
	.feature                	( feature_upsample        ),
	.feature_valid          	( feature_output_valid & upsample_working ),
	.feature_ready          	( upsample_ready          ),
	.col_size               	( col_size                ),
	.row_size               	( row_size                ),
	.unsample_feature       	( unsample_feature        ),
	.unsample_feature_valid 	( unsample_feature_valid  ),
	.output_ready           	( return_buffer_ready     ),
	.upsample_buffer_empty  	( upsample_buffer_empty   )
);

get_order get_order_inst(
	.system_clk					( system_clk			  ),
	.rst_n						( rst_n				  	  ),
	.task_start					( task_start			  ),	
	.task_finish				( task_finish			  ),
	.calculate_finish			( calculate_finish		  ),
	.calculate_start			( calculate_start		  ),
	.order						( order					  ),
	.feature_input_base_addr	( feature_input_base_addr ),
	.feature_input_patch_num	( feature_input_patch_num ),
	.feature_output_patch_num	( feature_output_patch_num),
	.feature_double_patch		( feature_double_patch	  ),
	.feature_patch_num			( feature_patch_num		  ),
	.row_size					( row_size				  ),
	.col_size					( col_size				  ),
	.weight_quant_size			( weight_quant_size		  ),
	.fea_in_quant_size			( fea_in_quant_size		  ),
	.fea_out_quant_size			( fea_out_quant_size	  ),
	.stride						( stride				  ),
	.return_addr				( return_addr			  ),
	.return_patch_num			( return_patch_num		  ),
	.padding_size				( padding_size			  ),
	.weight_data_length			( weight_data_length      ),
	.activate   				( activate				  ),
	.id							( ), 
	.s00_axi_aclk				( s00_axi_aclk			  ),
	.s00_axi_aresetn			( s00_axi_aresetn		  ),
	.s00_axi_awaddr				( s00_axi_awaddr		  ),
	.s00_axi_awprot				( s00_axi_awprot		  ),
	.s00_axi_awvalid			( s00_axi_awvalid		  ),
	.s00_axi_awready			( s00_axi_awready		  ),
	.s00_axi_wdata				( s00_axi_wdata			  ),
	.s00_axi_wstrb				( s00_axi_wstrb			  ),
	.s00_axi_wvalid				( s00_axi_wvalid		  ),
	.s00_axi_wready				( s00_axi_wready		  ),
	.s00_axi_bresp				( s00_axi_bresp			  ),
	.s00_axi_bvalid				( s00_axi_bvalid		  ),
	.s00_axi_bready				( s00_axi_bready		  ),
	.s00_axi_araddr				( s00_axi_araddr		  ),
	.s00_axi_arprot				( s00_axi_arprot		  ),
	.s00_axi_arvalid			( s00_axi_arvalid		  ),
	.s00_axi_arready			( s00_axi_arready		  ),
	.s00_axi_rdata				( s00_axi_rdata			  ),
	.s00_axi_rresp				( s00_axi_rresp			  ),
	.s00_axi_rvalid				( s00_axi_rvalid		  ),
	.s00_axi_rready				( s00_axi_rready		  )
);


endmodule
