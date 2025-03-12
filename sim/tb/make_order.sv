/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"
`include "axi_lite_BFM.sv"

module make_order #(
    parameter AXIL_DATA_WIDTH    = 32,
    parameter AXIL_ADDR_WIDTH    = 8
)(
    input   logic                           m00_axi_aclk,
    input   logic                           m00_axi_aresetn,
    output  logic [AXIL_ADDR_WIDTH-1:0]     m00_axi_awaddr,
    output  logic [2 : 0]                   m00_axi_awprot,
    output  logic                           m00_axi_awvalid,
    input   logic                           m00_axi_awready,
    output  logic [AXIL_DATA_WIDTH-1:0]     m00_axi_wdata,
    output  logic [(AXIL_DATA_WIDTH/8)-1:0] m00_axi_wstrb,
    output  logic                           m00_axi_wvalid,
    input   logic                           m00_axi_wready,
    input   logic [1 : 0]                   m00_axi_bresp,
    input   logic                           m00_axi_bvalid,
    output  logic                           m00_axi_bready,
    output  logic [AXIL_ADDR_WIDTH-1 : 0]   m00_axi_araddr,
    output  logic [2 : 0]                   m00_axi_arprot,
    output  logic                           m00_axi_arvalid,
    input   logic                           m00_axi_arready,
    input   logic [AXIL_DATA_WIDTH-1 : 0]   m00_axi_rdata,
    input   logic [1 : 0]                   m00_axi_rresp,
    input   logic                           m00_axi_rvalid,
    output  logic                           m00_axi_rready
);

assign m00_axi_awprot = 3'b000;
assign m00_axi_arprot = 3'b000;
axi_lite_if axi();
axi_lite_BFM bfm;

assign axi.ACLK         = m00_axi_aclk;
assign axi.ARESETn      = m00_axi_aresetn;
assign m00_axi_awaddr   = axi.AWADDR;
assign m00_axi_awvalid  = axi.AWVALID;
assign axi.AWREADY      = m00_axi_awready;
assign m00_axi_wdata    = axi.WDATA;
assign m00_axi_wstrb    = axi.WSTRB;
assign m00_axi_wvalid   = axi.WVALID;
assign axi.WREADY       = m00_axi_wready;
assign axi.BRESP        = m00_axi_bresp;
assign axi.BVALID       = m00_axi_bvalid;
assign m00_axi_bready   = axi.BREADY;
assign m00_axi_araddr   = axi.ARADDR;
assign m00_axi_arvalid  = axi.ARVALID;
assign axi.ARREADY      = m00_axi_arready;
assign axi.RDATA        = m00_axi_rdata;
assign axi.RRESP        = m00_axi_rresp;
assign axi.RVALID       = m00_axi_rvalid;
assign m00_axi_rready   = axi.RREADY;


integer file, status, instruction_finish;
logic [31:0] addr;
logic [31:0] wdata;
logic [31:0] rdata;

initial begin
    bfm = new(axi);
    instruction_finish = 0;
    // 打开文件
    file = $fopen("../compile/compile_out/order_code.txt", "r");
    // file = $fopen("F:/FPGA/accelerator_core/compile/compile_out/order_code.txt", "r");
    if (file == 0) begin
          $display("Error: Cannot open file.");
          $finish;
    end

    while (!$feof(file)) begin
        status = $fscanf(file, "%h %h\n", addr, wdata);
        if (status != 2) begin
            $display("Error: Invalid instruction format.");
            $finish;
        end
        
        // // 判断是否可以写入
        // if (addr == 8'h48) begin
        //     bfm.axi_read(8'h4c, rdata);
        //     @ (posedge m00_axi_aclk);
        //     while (rdata == 0) begin
        //         bfm.axi_read(8'h4c, rdata);
        //     end
        // end

        bfm.axi_write(addr, wdata);
        $display("Sent: Address = 0x%08h, Data = 0x%08h", addr, wdata);
    end

    // 关闭文件
    $fclose(file);
    instruction_finish = 1;
    $display("All instructions have been sent.");
end

endmodule