/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module compete_accelerator_tb #(
	parameter MEM_ADDR_WIDTH = `MEM_ADDR_WIDTH,
	parameter MEM_DATA_WIDTH = `MEM_DATA_WIDTH
)();

reg system_clk, rst_n;
reg m_axi_aclk, m_axi_aresetn;
initial begin
    m_axi_aclk = 0;
    forever #10 m_axi_aclk = ~m_axi_aclk;
end
initial begin
    m_axi_aresetn = 0;
    #20 m_axi_aresetn = 1;
end
initial begin
    system_clk = 0;
    forever #5 system_clk = ~system_clk;
end
initial begin
    rst_n = 0;
    #10 rst_n = 1;
end       

wire [MEM_ADDR_WIDTH-1:0]    m00_axi_araddr;     
wire [7:0]                   m00_axi_arlen;  
wire [2:0]                   m00_axi_arsize;
wire [1:0]                   m00_axi_arburst;
wire                         m00_axi_arlock;
wire [3:0]                   m00_axi_arcache;
wire [2:0]                   m00_axi_arprot;
wire [3:0]                   m00_axi_arqos;
wire                         m00_axi_arvalid;
wire                         m00_axi_arready;
wire [MEM_DATA_WIDTH-1:0]    m00_axi_rdata;  
wire [1:0]                   m00_axi_rresp;
wire                         m00_axi_rlast;  
wire                         m00_axi_rvalid; 
wire                         m00_axi_rready; 
wire   [MEM_ADDR_WIDTH-1:0]  m00_axi_awaddr;
wire[7:0]                    m00_axi_awlen;
wire[2:0]                    m00_axi_awsize;
wire[1:0]                    m00_axi_awburst;
wire                         m00_axi_awlock;
wire[3:0]                    m00_axi_awcache;
wire[2:0]                    m00_axi_awprot;
wire[3:0]                    m00_axi_awqos;
wire                         m00_axi_awvalid;
wire                         m00_axi_awready;
wire[MEM_DATA_WIDTH-1:0]     m00_axi_wdata;
wire[63:0]                   m00_axi_wstrb;
wire                         m00_axi_wlast;
wire                         m00_axi_wvalid;
wire                         m00_axi_wready;
wire[1:0]                    m00_axi_bresp;
wire                         m00_axi_bvalid;
wire                         m00_axi_bready;

wire [MEM_ADDR_WIDTH-1:0]    m01_axi_araddr;     
wire [7:0]                   m01_axi_arlen;  
wire [2:0]                   m01_axi_arsize;
wire [1:0]                   m01_axi_arburst;
wire                         m01_axi_arlock;
wire [3:0]                   m01_axi_arcache;
wire [2:0]                   m01_axi_arprot;
wire [3:0]                   m01_axi_arqos;
wire                         m01_axi_arvalid;
wire                         m01_axi_arready;
wire [MEM_DATA_WIDTH-1:0]    m01_axi_rdata;  
wire [1:0]                   m01_axi_rresp;
wire                         m01_axi_rlast;  
wire                         m01_axi_rvalid; 
wire                         m01_axi_rready; 
wire   [MEM_ADDR_WIDTH-1:0]  m01_axi_awaddr;
wire[7:0]                    m01_axi_awlen;
wire[2:0]                    m01_axi_awsize;
wire[1:0]                    m01_axi_awburst;
wire                         m01_axi_awlock;
wire[3:0]                    m01_axi_awcache;
wire[2:0]                    m01_axi_awprot;
wire[3:0]                    m01_axi_awqos;
wire                         m01_axi_awvalid;
wire                         m01_axi_awready;
wire[MEM_DATA_WIDTH-1:0]     m01_axi_wdata;
wire[63:0]                   m01_axi_wstrb;
wire                         m01_axi_wlast;
wire                         m01_axi_wvalid;
wire                         m01_axi_wready;
wire[1:0]                    m01_axi_bresp;
wire                         m01_axi_bvalid;
wire                         m01_axi_bready;

// outports wire
wire [7:0]   s_axi_awid;
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

axi_ram u_axi_ram(
    .clk               ( system_clk     ),    
    .rst               ( ~rst_n         ),
    .s_axi_awid        ( s_axi_awid     ),  
    .s_axi_awaddr      ( s_axi_awaddr   ),
    .s_axi_awlen       ( s_axi_awlen    ),
    .s_axi_awsize      ( s_axi_awsize   ),
    .s_axi_awburst     ( s_axi_awburst  ),
    .s_axi_awlock      ( s_axi_awlock   ),
    .s_axi_awcache     ( s_axi_awcache  ),
    .s_axi_awprot      ( s_axi_awprot   ),
    .s_axi_awvalid     ( s_axi_awvalid  ),
    .s_axi_awready     ( s_axi_awready  ),
    .s_axi_wdata       ( s_axi_wdata    ),
    .s_axi_wstrb       ( s_axi_wstrb    ),
    .s_axi_wlast       ( s_axi_wlast    ),
    .s_axi_wvalid      ( s_axi_wvalid   ),
    .s_axi_wready      ( s_axi_wready   ),
    .s_axi_bid         ( s_axi_bid      ),
    .s_axi_bresp       ( s_axi_bresp    ),
    .s_axi_bvalid      ( s_axi_bvalid   ),
    .s_axi_bready      ( s_axi_bready   ),
    .s_axi_arid        ( s_axi_arid     ),
    .s_axi_araddr      ( s_axi_araddr   ),
    .s_axi_arlen       ( s_axi_arlen    ),
    .s_axi_arsize      ( s_axi_arsize   ),
    .s_axi_arburst     ( s_axi_arburst  ),
    .s_axi_arlock      ( s_axi_arlock   ),
    .s_axi_arcache     ( s_axi_arcache  ),
    .s_axi_arprot      ( s_axi_arprot   ),
    .s_axi_arvalid     ( s_axi_arvalid  ),
    .s_axi_arready     ( s_axi_arready  ),
    .s_axi_rid         ( s_axi_rid      ), 
    .s_axi_rdata       ( s_axi_rdata    ),
    .s_axi_rresp       ( s_axi_rresp    ),
    .s_axi_rlast       ( s_axi_rlast    ),
    .s_axi_rvalid      ( s_axi_rvalid   ),
    .s_axi_rready      ( s_axi_rready   )
);

// outports wire
wire            task_start;
wire            task_finish;
wire            calculate_start;
wire            calculate_finish;

accelerator_control u_accelerator_control(
    .system_clk                   ( system_clk      ),
    .system_rst_n                 ( rst_n           ),
    .m00_axi_araddr               ( m00_axi_araddr  ),
    .m00_axi_arlen                ( m00_axi_arlen   ),
    .m00_axi_arsize               ( m00_axi_arsize  ),
    .m00_axi_arburst              ( m00_axi_arburst ),
    .m00_axi_arlock               ( m00_axi_arlock  ),
    .m00_axi_arcache              ( m00_axi_arcache ),
    .m00_axi_arprot               ( m00_axi_arprot  ),
    .m00_axi_arqos                ( m00_axi_arqos   ),
    .m00_axi_arvalid              ( m00_axi_arvalid ),
    .m00_axi_arready              ( m00_axi_arready ),
    .m00_axi_rdata                ( m00_axi_rdata   ),
    .m00_axi_rresp                ( m00_axi_rresp   ),
    .m00_axi_rlast                ( m00_axi_rlast   ),
    .m00_axi_rvalid               ( m00_axi_rvalid  ),
    .m00_axi_rready               ( m00_axi_rready  ),
    .m00_axi_awaddr               ( m00_axi_awaddr  ),
    .m00_axi_awlen                ( m00_axi_awlen   ),
    .m00_axi_awsize               ( m00_axi_awsize  ),
    .m00_axi_awburst              ( m00_axi_awburst ),
    .m00_axi_awlock               ( m00_axi_awlock  ),
    .m00_axi_awcache              ( m00_axi_awcache ),
    .m00_axi_awprot               ( m00_axi_awprot  ),
    .m00_axi_awqos                ( m00_axi_awqos   ),
    .m00_axi_awvalid              ( m00_axi_awvalid ),
    .m00_axi_awready              ( m00_axi_awready ),
    .m00_axi_wdata                ( m00_axi_wdata   ),
    .m00_axi_wstrb                ( m00_axi_wstrb   ),
    .m00_axi_wlast                ( m00_axi_wlast   ),
    .m00_axi_wvalid               ( m00_axi_wvalid  ),
    .m00_axi_wready               ( m00_axi_wready  ),
    .m00_axi_bresp                ( m00_axi_bresp   ),
    .m00_axi_bvalid               ( m00_axi_bvalid  ),
    .m00_axi_bready               ( m00_axi_bready  ),
    .s00_axi_aclk                 ( m_axi_aclk      ),
    .s00_axi_aresetn              ( m_axi_aresetn   ),
    .s00_axi_awaddr               ( m_axi_awaddr    ),
    .s00_axi_awprot               ( m_axi_awprot    ),
    .s00_axi_awvalid              ( m_axi_awvalid   ),
    .s00_axi_awready              ( m_axi_awready   ),
    .s00_axi_wdata                ( m_axi_wdata     ),
    .s00_axi_wstrb                ( m_axi_wstrb     ),
    .s00_axi_wvalid               ( m_axi_wvalid    ),
    .s00_axi_wready               ( m_axi_wready    ),
    .s00_axi_bresp                ( m_axi_bresp     ),
    .s00_axi_bvalid               ( m_axi_bvalid    ),
    .s00_axi_bready               ( m_axi_bready    ),
    .s00_axi_araddr               ( m_axi_araddr    ),
    .s00_axi_arprot               ( m_axi_arprot    ),
    .s00_axi_arvalid              ( m_axi_arvalid   ),
    .s00_axi_arready              ( m_axi_arready   ),
    .s00_axi_rdata                ( m_axi_rdata     ),
    .s00_axi_rresp                ( m_axi_rresp     ),
    .s00_axi_rvalid               ( m_axi_rvalid    ),
    .s00_axi_rready               ( m_axi_rready    )
);

make_order make_order_inst(
    .m00_axi_aclk       ( m_axi_aclk    ),
    .m00_axi_aresetn    ( m_axi_aresetn ),
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


axi_master #(
	.MEM_ADDR_WIDTH 	( 32   ),
	.MEM_DATA_WIDTH 	( 512  ))
u_axi_master2(
	.m00_axi_aclk    	( system_clk       ),
	.m00_axi_aresetn 	( rst_n            ),
	.m00_axi_araddr  	( m01_axi_araddr   ),
	.m00_axi_arlen   	( m01_axi_arlen    ),
	.m00_axi_arsize  	( m01_axi_arsize   ),
	.m00_axi_arburst 	( m01_axi_arburst  ),
	.m00_axi_arlock  	( m01_axi_arlock   ),
	.m00_axi_arcache 	( m01_axi_arcache  ),
	.m00_axi_arprot  	( m01_axi_arprot   ),
	.m00_axi_arqos   	( m01_axi_arqos    ),
	.m00_axi_arvalid 	( m01_axi_arvalid  ),
	.m00_axi_arready 	( m01_axi_arready  ),
	.m00_axi_rdata   	( m01_axi_rdata    ),
	.m00_axi_rresp   	( m01_axi_rresp    ),
	.m00_axi_rlast   	( m01_axi_rlast    ),
	.m00_axi_rvalid  	( m01_axi_rvalid   ),
	.m00_axi_rready  	( m01_axi_rready   ),
	.m00_axi_awaddr  	( m01_axi_awaddr   ),
	.m00_axi_awlen   	( m01_axi_awlen    ),
	.m00_axi_awsize  	( m01_axi_awsize   ),
	.m00_axi_awburst 	( m01_axi_awburst  ),
	.m00_axi_awlock  	( m01_axi_awlock   ),
	.m00_axi_awcache 	( m01_axi_awcache  ),
	.m00_axi_awprot  	( m01_axi_awprot   ),
	.m00_axi_awqos   	( m01_axi_awqos    ),
	.m00_axi_awvalid 	( m01_axi_awvalid  ),
	.m00_axi_awready 	( m01_axi_awready  ),
	.m00_axi_wdata   	( m01_axi_wdata    ),
	.m00_axi_wstrb   	( m01_axi_wstrb    ),
	.m00_axi_wlast   	( m01_axi_wlast    ),
	.m00_axi_wvalid  	( m01_axi_wvalid   ),
	.m00_axi_wready  	( m01_axi_wready   ),
	.m00_axi_bresp   	( m01_axi_bresp    ),
	.m00_axi_bvalid  	( m01_axi_bvalid   ),
	.m00_axi_bready  	( m01_axi_bready   )
);

axi_interconnect_wrap_2x1 #(
	.DATA_WIDTH        	( 512 ),
	.ADDR_WIDTH        	( 32  ),
	.STRB_WIDTH        	(     ),
	.ID_WIDTH          	( 8   ),
	.AWUSER_ENABLE     	( 0   ),
	.AWUSER_WIDTH      	( 1   ),
	.WUSER_ENABLE      	( 0   ),
	.WUSER_WIDTH       	( 1   ),
	.BUSER_ENABLE      	( 0   ),
	.BUSER_WIDTH       	( 1   ),
	.ARUSER_ENABLE     	( 0   ),
	.ARUSER_WIDTH      	( 1   ),
	.RUSER_ENABLE      	( 0   ),
	.RUSER_WIDTH       	( 1   ),
	.FORWARD_ID        	( 0   ),
	.M_REGIONS         	( 1   ),
	.M00_BASE_ADDR     	( 0   ),
	.M00_ADDR_WIDTH    	(     ),
	.M00_CONNECT_READ  	( 11  ),
	.M00_CONNECT_WRITE 	( 11  ),
	.M00_SECURE        	( 0   ))
u_axi_interconnect_wrap_2x1(
	.clk              	( system_clk        ),
	.rst              	( ~rst_n            ),
	.s00_axi_awid     	( 0                 ),
	.s00_axi_awaddr   	( m00_axi_awaddr    ),
	.s00_axi_awlen    	( m00_axi_awlen     ),
	.s00_axi_awsize   	( m00_axi_awsize    ),
	.s00_axi_awburst  	( m00_axi_awburst   ),
	.s00_axi_awlock   	( m00_axi_awlock    ),
	.s00_axi_awcache  	( m00_axi_awcache   ),
	.s00_axi_awprot   	( m00_axi_awprot    ),
	.s00_axi_awqos    	( m00_axi_awqos     ),
	.s00_axi_awuser   	(                   ),
	.s00_axi_awvalid  	( m00_axi_awvalid   ),
	.s00_axi_awready  	( m00_axi_awready   ),  
	.s00_axi_wdata    	( m00_axi_wdata     ),  
	.s00_axi_wstrb    	( m00_axi_wstrb     ),  
	.s00_axi_wlast    	( m00_axi_wlast     ), 
	.s00_axi_wuser    	(                   ), 
	.s00_axi_wvalid   	( m00_axi_wvalid    ),
	.s00_axi_wready   	( m00_axi_wready    ),
	.s00_axi_bid      	(                   ),
	.s00_axi_bresp    	( m00_axi_bresp     ),
	.s00_axi_buser    	(                   ),
	.s00_axi_bvalid   	( m00_axi_bvalid    ),
	.s00_axi_bready   	( m00_axi_bready    ),
	.s00_axi_arid     	( 0                 ),
	.s00_axi_araddr   	( m00_axi_araddr    ),
	.s00_axi_arlen    	( m00_axi_arlen     ),
	.s00_axi_arsize   	( m00_axi_arsize    ), 
	.s00_axi_arburst  	( m00_axi_arburst   ), 
	.s00_axi_arlock   	( m00_axi_arlock    ), 
	.s00_axi_arcache  	( m00_axi_arcache   ), 
	.s00_axi_arprot   	( m00_axi_arprot    ), 
	.s00_axi_arqos    	( m00_axi_arqos     ),  
	.s00_axi_aruser   	(                   ), 
	.s00_axi_arvalid  	( m00_axi_arvalid   ), 
	.s00_axi_arready  	( m00_axi_arready   ),
	.s00_axi_rid      	(                   ),
	.s00_axi_rdata    	( m00_axi_rdata     ),
	.s00_axi_rresp    	( m00_axi_rresp     ),
	.s00_axi_rlast    	( m00_axi_rlast     ),
	.s00_axi_ruser    	(                   ),
	.s00_axi_rvalid   	( m00_axi_rvalid    ),
	.s00_axi_rready   	( m00_axi_rready    ),
	.s01_axi_awid     	( 0                 ),
	.s01_axi_awaddr   	( m01_axi_awaddr    ),
	.s01_axi_awlen    	( m01_axi_awlen     ),
	.s01_axi_awsize   	( m01_axi_awsize    ),
	.s01_axi_awburst  	( m01_axi_awburst   ),
	.s01_axi_awlock   	( m01_axi_awlock    ),
	.s01_axi_awcache  	( m01_axi_awcache   ),
	.s01_axi_awprot   	( m01_axi_awprot    ),
	.s01_axi_awqos    	( m01_axi_awqos     ),
	.s01_axi_awuser   	(                   ),
	.s01_axi_awvalid  	( m01_axi_awvalid   ),
	.s01_axi_awready  	( m01_axi_awready   ),  
	.s01_axi_wdata    	( m01_axi_wdata     ),  
	.s01_axi_wstrb    	( m01_axi_wstrb     ),  
	.s01_axi_wlast    	( m01_axi_wlast     ), 
	.s01_axi_wuser    	(                   ), 
	.s01_axi_wvalid   	( m01_axi_wvalid    ),
	.s01_axi_wready   	( m01_axi_wready    ),
	.s01_axi_bid      	(                   ),
	.s01_axi_bresp    	( m01_axi_bresp     ),
	.s01_axi_buser    	(                   ),
	.s01_axi_bvalid   	( m01_axi_bvalid    ),
	.s01_axi_bready   	( m01_axi_bready    ),
	.s01_axi_arid     	( 0                 ),
	.s01_axi_araddr   	( m01_axi_araddr    ),
	.s01_axi_arlen    	( m01_axi_arlen     ),
	.s01_axi_arsize   	( m01_axi_arsize    ), 
	.s01_axi_arburst  	( m01_axi_arburst   ), 
	.s01_axi_arlock   	( m01_axi_arlock    ), 
	.s01_axi_arcache  	( m01_axi_arcache   ), 
	.s01_axi_arprot   	( m01_axi_arprot    ), 
	.s01_axi_arqos    	( m01_axi_arqos     ),  
	.s01_axi_aruser   	(                   ), 
	.s01_axi_arvalid  	( m01_axi_arvalid   ), 
	.s01_axi_arready  	( m01_axi_arready   ),
	.s01_axi_rid      	(                   ),
	.s01_axi_rdata    	( m01_axi_rdata     ),
	.s01_axi_rresp    	( m01_axi_rresp     ),
	.s01_axi_rlast    	( m01_axi_rlast     ),
	.s01_axi_ruser    	(                   ),
	.s01_axi_rvalid   	( m01_axi_rvalid    ),
	.s01_axi_rready   	( m01_axi_rready    ),
	.m00_axi_awid     	( s_axi_awid      ),
	.m00_axi_awaddr   	( s_axi_awaddr    ),
	.m00_axi_awlen    	( s_axi_awlen     ),
	.m00_axi_awsize   	( s_axi_awsize    ),
	.m00_axi_awburst  	( s_axi_awburst   ),
	.m00_axi_awlock   	( s_axi_awlock    ),
	.m00_axi_awcache  	( s_axi_awcache   ),
	.m00_axi_awprot   	( s_axi_awprot    ),
	.m00_axi_awqos    	( s_axi_awqos     ),
	.m00_axi_awregion 	( s_axi_awregion  ),
	.m00_axi_awuser   	( s_axi_awuser    ),
	.m00_axi_awvalid  	( s_axi_awvalid   ),
	.m00_axi_awready  	( s_axi_awready   ),
	.m00_axi_wdata    	( s_axi_wdata     ),
	.m00_axi_wstrb    	( s_axi_wstrb     ),
	.m00_axi_wlast    	( s_axi_wlast     ),
	.m00_axi_wuser    	( s_axi_wuser     ),
	.m00_axi_wvalid   	( s_axi_wvalid    ),
	.m00_axi_wready   	( s_axi_wready    ),
	.m00_axi_bid      	( s_axi_bid       ),
	.m00_axi_bresp    	( s_axi_bresp     ),
	.m00_axi_buser    	( s_axi_buser     ),
	.m00_axi_bvalid   	( s_axi_bvalid    ),
	.m00_axi_bready   	( s_axi_bready    ),
	.m00_axi_arid     	( s_axi_arid      ),
	.m00_axi_araddr   	( s_axi_araddr    ),
	.m00_axi_arlen    	( s_axi_arlen     ),
	.m00_axi_arsize   	( s_axi_arsize    ),
	.m00_axi_arburst  	( s_axi_arburst   ),
	.m00_axi_arlock   	( s_axi_arlock    ),
	.m00_axi_arcache  	( s_axi_arcache   ),
	.m00_axi_arprot   	( s_axi_arprot    ),
	.m00_axi_arqos    	( s_axi_arqos     ),
	.m00_axi_arregion 	(   			  ),
	.m00_axi_aruser   	(     			  ),
	.m00_axi_arvalid  	( s_axi_arvalid   ),
	.m00_axi_arready  	( s_axi_arready   ),
	.m00_axi_rid      	( s_axi_rid       ),
	.m00_axi_rdata    	( s_axi_rdata     ),
	.m00_axi_rresp    	( s_axi_rresp     ),
	.m00_axi_rlast    	( s_axi_rlast     ),
	.m00_axi_ruser    	(      			  ),
	.m00_axi_rvalid   	( s_axi_rvalid    ),
	.m00_axi_rready   	( s_axi_rready    )
);

integer i, d, times;

initial begin
	d = 0;
end

always @(posedge system_clk) begin
    if (u_accelerator_control.get_order_inst.next_calculate_application)begin
        for (i=0;i<u_accelerator_control.return_patch_num*u_accelerator_control.feature_output_patch_num*64;i=i+1)begin
            $fwrite(u_axi_ram.out_file, "%h\n", u_axi_ram.mem[(u_accelerator_control.return_addr/64)+i]);
        end
        $fwrite(u_axi_ram.out_file, "#%d\n", u_accelerator_control.get_order_inst.id);

        $display("the %d layer simulation is finish", u_accelerator_control.get_order_inst.id);
        $display("Using time: %d us", (($time - times) / 10000000));
        times = $time;
    end
    else if (u_accelerator_control.get_order_inst.calculate_start & d == 0) begin
        for (i=0;i<u_accelerator_control.feature_input_patch_num*u_accelerator_control.feature_patch_num*64;i=i+1)begin
            $fwrite(u_axi_ram.out_file, "%h\n", u_axi_ram.mem[(u_accelerator_control.feature_input_base_addr/64)+i]);
        end
        $fwrite(u_axi_ram.out_file, "#%d\n", u_accelerator_control.get_order_inst.id);
        d = 1;
    end 

    if (u_accelerator_control.get_order_inst.Cache_order_inst.order==5) begin
        if (u_axi_ram.file != 0) begin
            $writememh(u_axi_ram.memory_patch, u_axi_ram.mem);
            $fclose(u_axi_ram.file);
            $fclose(u_axi_ram.out_file);
            u_axi_ram.file = 0;
            $stop;
        end
    end
end

// 加入气泡


endmodule