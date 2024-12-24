/*
    created by  : <Xidian University>
    created date: 2024-12-23
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`ifndef AXI_LITE_IF_SV
`define AXI_LITE_IF_SV

interface axi_lite_if();
    // Global signals
    logic          ACLK;
    logic          ARESETn;

    // Write address channel
    logic  [31:0]  AWADDR;
    logic          AWVALID;
    logic          AWREADY;

    // Write data channel
    logic  [31:0]  WDATA;
    logic  [3:0]   WSTRB;
    logic          WVALID;
    logic          WREADY;

    // Write response channel
    logic  [1:0]   BRESP;
    logic          BVALID;
    logic          BREADY;

    // Read address channel
    logic  [31:0]  ARADDR;
    logic          ARVALID;
    logic          ARREADY;

    // Read data channel
    logic  [31:0]  RDATA;
    logic  [1:0]   RRESP;
    logic          RVALID;
    logic          RREADY;

    initial begin
        AWADDR  = 0;
        AWVALID = 0;
        WDATA   = 0;
        WSTRB   = 0;
        WVALID  = 0;
        BREADY  = 0;
        ARADDR  = 0;
        ARVALID = 0;
        RREADY  = 0;
    end

    modport master (
        input   ACLK    ,   
        input   ARESETn ,
        output  AWADDR  ,
        output  AWVALID ,
        input   AWREADY ,
        output  WDATA   ,
        output  WSTRB   ,
        output  WVALID  ,
        input   WREADY  ,
        input   BRESP   ,
        input   BVALID  ,
        output  BREADY  ,
        output  ARADDR  ,
        output  ARVALID ,
        input   ARREADY ,
        input   RDATA   ,
        input   RRESP   ,
        input   RVALID  ,
        output  RREADY  
    );
endinterface

`endif
