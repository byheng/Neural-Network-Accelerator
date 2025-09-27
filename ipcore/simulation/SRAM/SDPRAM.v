`timescale 1ns/1ps

/*
*   Date : 2024-06-27
*   Author : nitcloud
*   Module Name:   SDPRAM.v - SDPRAM
*   Target Device: [Target FPGA and ASIC Device]
*   Tool versions: vivado 18.3 & DC 2016
*   Revision Historyc :
*   Revision :
*       Revision 0.01 - File Created
*   Description : 
*                 1. In Vivado, EDA can directly use BRAM for synthesis.
*                 2. When ren disabled, it outputs the last data.
*                 3. In write mode, the current data input takes precedence for writing, 
*                    and the data from the address input at the previous clock cycle is read out. 
*                    In read mode, the data from the address input at the current clock cycle 
*                    is directly read out. In write mode, when writing to different addresses, 
*                    the data corresponding to the current address input at the current clock cycle 
*                    is directly read out.
*                 4. The reset is a synchronous reset with active high, and it can also serve as 
*                    the enable input for the SDPRAM, with active low enable.
*   Dependencies: none(FPGA) auto for BRAM in vivado | RAM_IP with IC 
*   Company : ncai Technology .Inc
*   Copyright(c) 1999, ncai Technology Inc, All right reserved
*/

/* @wavedrom
{signal: [
  {name: 'clock', wave: '101010101010101'},
  {name: 'wen', wave: '01.........0...'},
  {name: 'ren', wave: '01.......0.1.0.'},
  {name: 'waddr', wave: 'x3...3.....3.x.', data: ['addr0','addr1','addr2']},
  {name: 'raddr', wave: 'x3...3.3.3.3.x.', data: ['addr0','addr2','addr0','addr1','addr0']},
  {name: 'din', wave: 'x4.4.4...4.4.x.', data: ['data0','data1','data2','data3','data4']},
  {name: 'dout', wave: 'x..5.5.5.....x.', data: ['data0','data2','data1']},
]}
*/
module SDPRAM #(
        // The depth parameter of RAM.
        parameter DEPTH = 1024,
        // The width parameter for reading and writing data.
        parameter WIDTH = 12,
        // Delay output
        parameter DELAY = 0,
        // do not set by user
        parameter STEP  = ($clog2(DEPTH) == 0) ? 0 : ($clog2(DEPTH) - 1) // 确定 RAM 地址的位宽
    ) (
        // Clock input
        input      clock,
        // Synchronous reset with active high
        // When DEPTH == 1; asynchronous reset with active high
        input      reset,

        // Write enable input, active high.
        input      wen,  
        // Read enable input, active high.
        input      ren,

        // Write input address.
        input  [STEP:0] waddr,
        // Read input address.
        input  [STEP:0] raddr,

        // Write input data.
        input  [WIDTH-1:0] din,
        // Read output data.
        output [WIDTH-1:0] dout
    );

    reg [WIDTH-1:0] rdout;
    reg [WIDTH-1:0] o_rdata_delay_reg[DELAY:0];

    // define ram as array or ip
    reg [WIDTH-1:0] ram [DEPTH-1:0]; // 定义 RAM 存储器
    integer i;
    initial begin
        for(i=0; i<DEPTH; i=i+1) begin
            ram[i] = 0; // 初始化 RAM 存储器
        end
    end
    
    always @(posedge clock) begin
        if(reset) begin
            rdout <= 0;
        end
        else begin
            if (wen) begin
                ram[waddr] <= din; // 写入数据到 RAM
            end
            if (ren) begin
                rdout <= ram[raddr]; // 从 RAM 读取数据
            end
        end
    end


    // delay read data
    generate
        if (DELAY == 0) begin
            assign dout = rdout; // 不需要延迟输出时，直接输出当前读数据
        end
        else begin // 需要延迟输出时，打拍
            for (genvar i = 0; i < DELAY; i = i + 1) begin
                if (i == 0) begin
                    always@(posedge clock) begin
                        o_rdata_delay_reg[i] <= rdout;
                    end
                end
                else begin
                    always@(posedge clock) begin
                        o_rdata_delay_reg[i] <= o_rdata_delay_reg[i-1];
                    end
                end
            end
            assign dout = o_rdata_delay_reg[DELAY-1];
        end
    endgenerate

endmodule //
