/*
    created by  : <Xidian University>
    created date: 2024-12-23
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`ifndef axi_lite_BFM
`define axi_lite_BFM

`include "../../parameters.v"

class axi_lite_BFM;
    virtual axi_lite_if axi;

    function new(virtual axi_lite_if v_axi);
        this.axi = v_axi;
    endfunction

    // AXI-Lite write operation
    task axi_write(input logic [31:0] addr, input logic [31:0] data);
        // 设置地址和数据
        axi.AWADDR = addr;
        axi.WDATA  = data;
        axi.AWVALID = 1;
        axi.WVALID  = 1;
        axi.WSTRB   = 4'b1111;

        // 等待 AWREADY 和 WREADY 信号
        @(posedge axi.ACLK);
        wait (axi.AWREADY);
        wait (axi.WREADY);
        @(posedge axi.ACLK);
        axi.AWVALID = 0;
        axi.WVALID  = 0;

        // 等待 BVALID 信号
        wait (axi.BVALID);
        axi.BREADY  = 1;
        @(posedge axi.ACLK);
        axi.BREADY  = 0;
    endtask

    // AXI-Lite read operation
    task axi_read(input logic [31:0] addr, output logic [31:0] data);
        // 设置地址并启动 ARVALID 信号
        axi.ARADDR  = addr;
        axi.ARVALID = 1;

        // 等待 ARREADY 信号
        @(posedge axi.ACLK);
        wait (axi.ARREADY);
        #1;
        @(posedge axi.ACLK);
        axi.ARVALID = 0;

        // 等待 RVALID 信号并读取数据
        wait (axi.RVALID);
        data = axi.RDATA;
        axi.RREADY = 1;
        @(posedge axi.ACLK);
        axi.RREADY = 0;
    endtask
endclass

`endif