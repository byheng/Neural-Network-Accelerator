/*
    created by  : <Xidian University>
    created date: 2025-02-27
    author      : <zhiquan huang>
    description : 
*/
`timescale 1ns/100fs

module axi_master #(
    parameter MEM_ADDR_WIDTH = 32,
    parameter MEM_DATA_WIDTH = 512
)(
    // AXI-signal for ddr port
    // AXI-4 Only read
    input                           m00_axi_aclk,
    input                           m00_axi_aresetn,
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
    output reg[MEM_ADDR_WIDTH-1:0]  m00_axi_awaddr,
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
    output reg                      m00_axi_bready
);

assign m00_axi_araddr  = 0;
assign m00_axi_arlen   = 0;
assign m00_axi_arsize  = 0;
assign m00_axi_arburst = 0;
assign m00_axi_arlock  = 0;
assign m00_axi_arcache = 0;
assign m00_axi_arprot  = 0;
assign m00_axi_arqos   = 0;
assign m00_axi_arvalid = 0;
assign m00_axi_rready  = 0;

assign m00_axi_awsize = 3'b110;
assign m00_axi_awburst = 2'b01;   
assign m00_axi_awlock = 1'b0;
assign m00_axi_awcache = 4'b0000;
assign m00_axi_awprot = 3'b000;
assign m00_axi_awqos = 4'b0000;
assign m00_axi_wstrb = 64'hffff_ffff_ffff_ffff;
assign m00_axi_awlen = 8'd63;

reg [2:0]     state;

// state for AXI4-FULL write
localparam [2:0]    IDLE = 3'd0,
                    WAIT_DATA_READY = 3'd1,
                    WRITE_ADDR = 3'd2, 
                    WRITE_DATA = 3'd3, 
                    WRITE_RESP = 3'd4;

reg [8:0] cnt;
always@(posedge m00_axi_aclk or negedge m00_axi_aresetn) begin
    if (~m00_axi_aresetn) begin
        state <= IDLE;
        cnt <= 9'd0;
        m00_axi_awaddr <= 32'h80000000;
    end else begin
        case (state)
            IDLE: begin
                if (($random % (1000 + 1)) > 999) begin
                    state <= WAIT_DATA_READY;
                end
            end
            WAIT_DATA_READY: begin
                state <= WRITE_ADDR;
            end
            WRITE_ADDR: begin
                if (m00_axi_awready) begin
                    state <= WRITE_DATA;
                end
            end
            WRITE_DATA: begin
                if (m00_axi_wready & m00_axi_wvalid) begin
                    cnt <= cnt + 1;
                end
                if (m00_axi_bvalid & m00_axi_bready) begin
                    cnt <= 0;
                    state <= IDLE;
                end
            end
        endcase
    end     
end

always @(posedge m00_axi_aclk or negedge m00_axi_aresetn) begin
    if (~m00_axi_aresetn) begin
        m00_axi_bready <= 1'b0;
    end
    else if (m00_axi_bvalid & m00_axi_bready) begin
        m00_axi_bready <= 1'b0;
    end
    else if (m00_axi_bvalid) begin
        m00_axi_bready <= 1'b1;
    end
    else begin
        m00_axi_bready <= 1'b0;
    end
end

assign m00_axi_awvalid = (state == WRITE_ADDR);
assign m00_axi_wvalid = (state == WRITE_DATA) & (cnt <= m00_axi_awlen);
assign m00_axi_wdata = 0;
assign m00_axi_wlast = (cnt == m00_axi_awlen) && m00_axi_wvalid && m00_axi_wready;

endmodule
