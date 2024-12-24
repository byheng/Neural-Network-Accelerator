/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module order_tb ();

reg system_clk, rst_n;
initial begin
    system_clk = 0;
    forever #5 system_clk = ~system_clk;
end
initial begin
    rst_n = 0;
    #10 rst_n = 1;
end       

wire [7:0]        m_axi_awaddr ;
wire [2:0]        m_axi_awprot ;
wire              m_axi_awvalid;
wire              m_axi_awready;
wire [31:0]       m_axi_wdata  ;
wire [(32/8)-1:0] m_axi_wstrb  ;
wire              m_axi_wvalid ;
wire              m_axi_wready ;
wire [1:0]        m_axi_bresp  ;    
wire              m_axi_bvalid ;
wire              m_axi_bready ;
wire [7:0]        m_axi_araddr ;
wire [2:0]        m_axi_arprot ;
wire              m_axi_arvalid;
wire              m_axi_arready;
wire [31:0]       m_axi_rdata  ;
wire [1:0]        m_axi_rresp  ;
wire              m_axi_rvalid ;
wire              m_axi_rready ;

make_order make_order_inst(
    .system_clk         ( system_clk    ),
    .rst_n              ( rst_n         ),
    .m00_axi_awaddr     ( m_axi_awaddr  ),
    .m00_axi_awprot     ( m_axi_awprot  ),
    .m00_axi_awvalid    ( m_axi_awvalid ),
    .m00_axi_awready    ( m_axi_awready ),
    .m00_axi_wdata      ( m_axi_wdata   ),
    .m00_axi_wstrb      ( m_axi_wstrb   ),
    .m00_axi_wvalid     ( m_axi_wvalid  ),
    .m00_axi_wready     ( m_axi_wready  ),
    .m00_axi_bresp      ( m_axi_bresp   ),
    .m00_axi_bvalid     ( m_axi_bvalid  ),
    .m00_axi_bready     ( m_axi_bready  ),
    .m00_axi_araddr     ( m_axi_araddr  ),
    .m00_axi_arprot     ( m_axi_arprot  ),
    .m00_axi_arvalid    ( m_axi_arvalid ),
    .m00_axi_arready    ( m_axi_arready ),
    .m00_axi_rdata      ( m_axi_rdata   ),
    .m00_axi_rresp      ( m_axi_rresp   ),
    .m00_axi_rvalid     ( m_axi_rvalid  ),
    .m00_axi_rready     ( m_axi_rready  )
);

get_order get_order_inst(
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
	.s00_axi_aclk				( system_clk			  ),
	.s00_axi_aresetn			( rst_n		  			  ),
	.s00_axi_awaddr				( m_axi_awaddr      	  ),
	.s00_axi_awprot				( m_axi_awprot      	  ),
	.s00_axi_awvalid			( m_axi_awvalid     	  ),
	.s00_axi_awready			( m_axi_awready     	  ),
	.s00_axi_wdata				( m_axi_wdata       	  ),
	.s00_axi_wstrb				( m_axi_wstrb       	  ),
	.s00_axi_wvalid				( m_axi_wvalid      	  ),
	.s00_axi_wready				( m_axi_wready      	  ),
	.s00_axi_bresp				( m_axi_bresp       	  ),
	.s00_axi_bvalid				( m_axi_bvalid      	  ),
	.s00_axi_bready				( m_axi_bready      	  ),
	.s00_axi_araddr				( m_axi_araddr      	  ),
	.s00_axi_arprot				( m_axi_arprot      	  ),
	.s00_axi_arvalid			( m_axi_arvalid     	  ),
	.s00_axi_arready			( m_axi_arready     	  ),
	.s00_axi_rdata				( m_axi_rdata       	  ),
	.s00_axi_rresp				( m_axi_rresp       	  ),
	.s00_axi_rvalid				( m_axi_rvalid      	  ),
	.s00_axi_rready				( m_axi_rready      	  )
);

assign calculate_finish = 1'b1;


endmodule