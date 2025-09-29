/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
    “要扫清一切害人虫，全无敌”
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module return_buffer #(
    parameter FEATURE_WIDTH     = `FEATURE_WIDTH, // 16
    parameter MEM_DATA_WIDTH    = `MEM_DATA_WIDTH, // 512
    parameter MEM_ADDR_WIDTH    = `MEM_ADDR_WIDTH  // 32
)
(
    input                               system_clk  ,       
    input                               rst_n       ,
    // data from calculate component
    input                               refresh_return_addr, // 刷新返回地址信号
    input                               return_req,
    output                              return_finish,
    input  [15:0]                       return_patch_num,
    input  [MEM_ADDR_WIDTH-1:0]         return_addr, // <-- get_order 返回数据的起始地址
    input  [FEATURE_WIDTH*8-1:0]        return_data, // <-- return_data_arbitra
    input                               return_data_valid,
    output                              return_buffer_ready,
    input                               output_buffer_done,

    // AXI-4 only for write
    output reg[MEM_ADDR_WIDTH-1:0]      m00_axi_awaddr,  // AXI-4 写地址
    output [7:0]                        m00_axi_awlen,   // 突发传输长度，如果 awlen 为 n，则本次写请求需要连续写入 n+1 个数据。
    output [2:0]                        m00_axi_awsize,  // 写入数据的突发传输大小，3'b110表示每次传输2^6=64字节
    output [1:0]                        m00_axi_awburst, // 突发传输类型，2'b00表示固定突发, 2'b01表示递增突发, 2'b10表示包裹突发, 2'b11表示保留
    output                              m00_axi_awlock,  // 2'b00表示正常的突发传输, 2'b01表示未锁定的突发传输, 2'b10表示锁定的突发传输, 2'b11表示保留
    output [3:0]                        m00_axi_awcache, // 4'b0000表示所有的缓存属性均为0, 4'b0001表示缓冲区可缓存, 4'b0010表示缓冲区不可缓存, 4'b0011表示缓冲区可缓存且可分配, 4'b0100表示缓冲区可分配, 4'b0101表示缓冲区可缓存且不可分配, 4'b0110表示缓冲区不可缓存且可分配, 4'b0111表示缓冲区可缓存且可分配, 4'b1xxx表示保留
    output [2:0]                        m00_axi_awprot,  // 3'b000表示数据传输的优先级最低，且为普通的非特权级别，且为数据访问, 3'b001表示数据传输的优先级最低，且为普通的非特权级别，且为指令访问, 3'b010表示数据传输的优先级最低，且为特权级别，且为数据访问, 3'b011表示数据传输的优先级最低，且为特权级别，且为指令访问, 3'b100表示数据传输的优先级最高，且为普通的非特权级别，且为数据访问, 3'b101表示数据传输的优先级最高，且为普通的非特权级别，且为指令访问, 3'b110表示数据传输的优先级最高，且为特权级别，且为数据访问, 3'b111表示数据传输的优先级最高，且为特权级别，且为指令访问
    output [3:0]                        m00_axi_awqos,   // 4'b0000表示不对传输进行任何质量服务区分, 4'b0001表示最低的质量服务等级, 4'b1110表示最高的质量服务等级, 4'b1111表示保留
    output                              m00_axi_awvalid,  // AXI-4 写地址有效信号
    input                               m00_axi_awready,  // AXI-4 写地址准备好信号
    output [MEM_DATA_WIDTH-1:0]         m00_axi_wdata,    // 写数据
    output [63:0]                       m00_axi_wstrb,    // 写数据的掩码
    output                              m00_axi_wlast,    // 本次写事务的最后一个数据
    output                              m00_axi_wvalid,   // AXI-4 写数据信号
    input                               m00_axi_wready,   // AXI-4 写数据准备好信号
    input  [1:0]                        m00_axi_bresp,    // 写回响应，表示存储器完成本次写事务的状态，包括正常（0b00）、错误（0b01）、保留（0b10）、未知（0b11）
    input                               m00_axi_bvalid,   // AXI-4 写响应有效信号,表示本次写事务已经完成
    output reg                          m00_axi_bready    // 表示已经接收到了存储器的写回确认
);

// local parameters
localparam [1:0] IDLE = 2'b00, WRITE_REQ = 2'b01, WRITE_DATA = 2'b10, CHECK_WRITE_FINISH = 2'b11;

// variables declaration
(* keep = "true" *)wire                        return_buffer_almost_full;
(* keep = "true" *)wire                        return_buffer_almost_empty;
wire [MEM_DATA_WIDTH-1:0]   return_buffer_data;
wire                        return_buffer_rd_en;
(* keep = "true" *)reg  [1:0]                  write_ddr_state;
(* keep = "true" *)reg  [15:0]                 return_num_cnt;
(* keep = "true" *)reg                         return_keep;
reg  [7:0]                  cnt;
(* keep = "true" *)wire                        return_buffer_empty;
wire                        fifo_rst;
wire                        write_ack;

assign fifo_rst = (~rst_n) | return_req;

assign m00_axi_awsize = 3'b110; // 写入数据的突发传输大小，3'b110表示每次传输2^6=64字节
assign m00_axi_awburst = 2'b01;   // 突发传输类型，2'b01表示递增突发
assign m00_axi_awlock = 1'b0; // 2'b00表示正常的突发传输
assign m00_axi_awcache = 4'b0000; // 0000表示所有的缓存属性均为0
assign m00_axi_awprot = 3'b000; // 000表示数据传输的优先级最低，且为普通的非特权级别，且为数据访问
assign m00_axi_awqos = 4'b0000; // 0000表示不对传输进行任何质量服务区分
assign m00_axi_wstrb = 64'hffff_ffff_ffff_ffff; // 每个字节都有效
assign m00_axi_awlen = 8'd63; // 每次突发传输64个数据

assign return_buffer_ready = ~return_buffer_almost_full;

generate
    if (`device == "xilinx") begin
        return_buffer_fifo return_buffer_fifo_inst (
            .clk            (system_clk),                
            .srst           (fifo_rst),        
            .din            (return_data),        
            .wr_en          (return_data_valid),        
            .rd_en          (return_buffer_rd_en),        
            .dout           (return_buffer_data),        
            .full           (),        
            .almost_full    (),            
            .empty          (return_buffer_empty),
            .almost_empty   (),        
            .prog_full      (return_buffer_almost_full),    
            .prog_empty     (return_buffer_almost_empty),        
            .wr_rst_busy    (),        
            .rd_rst_busy    ()       
        );
    end
    else if (`device == "simulation") begin
        // ram_based_fifo #(
        //     .DATA_W                  	( 128      ),
        //     .DEPTH_W                 	( 11       ),
        //     .DATA_R                  	( 512      ),
        //     .DEPTH_R                 	( 9        ),
        //     .ALMOST_FULL_THRESHOLD   	( 2016     ),
        //     .ALMOST_EMPTY_THRESHOLD  	( 64       ),
        //     .FIRST_WORD_FALL_THROUGH 	( 1        )
        // )
        // u_ram_based_fifo(
        //     .system_clk     	( system_clk                    ),
        //     .rst_n          	( ~fifo_rst                     ),
        //     .i_wren         	( return_data_valid             ),
        //     .i_wrdata       	( return_data                   ),
        //     .o_full         	(                               ),
        //     .o_almost_full  	( return_buffer_almost_full     ),
        //     .i_rden         	( return_buffer_rd_en           ),
        //     .o_rddata       	( return_buffer_data            ),
        //     .o_empty        	( return_buffer_empty           ),
        //     .o_almost_empty 	( return_buffer_almost_empty    )  
        // );

        sync_fifo #(
            .INPUT_WIDTH       	( 128       ),
            .OUTPUT_WIDTH      	( 512       ),
            .WR_DEPTH          	( 2**11     ),
            .RD_DEPTH          	( 2**9      ),
            .MODE              	( "FWFT"    ),
            .DIRECTION         	( "LSB"     ),
            .ECC_MODE          	( "no_ecc"  ),
            .PROG_EMPTY_THRESH 	( 64        ),
            .PROG_FULL_THRESH  	( 2016      ))
        u_sync_fifo(
            .clock         	( system_clk                ),
            .reset         	( fifo_rst                  ),
            .wr_en         	( return_data_valid         ),
            .din           	( return_data               ),
            .rd_en         	( return_buffer_rd_en       ),
            .dout          	( return_buffer_data        ),
            .empty         	( return_buffer_empty       ),
            .prog_full     	( return_buffer_almost_full ),
            .prog_empty    	( return_buffer_almost_empty)
        );
    end
endgenerate


/*-------------------------------- DDR AXI-4 write logic --------------------------*/
always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        m00_axi_awaddr <= 0;
    end
    else if (refresh_return_addr) begin // 当接收到刷新地址信号时，更新AXI-4写地址
        m00_axi_awaddr <= return_addr;
    end
    else if (write_ack) begin // 当本次写事务完成后，更新AXI-4写地址，准备下一次写事务
        m00_axi_awaddr <= m00_axi_awaddr + 'd4096; // 每次写完一个patch后，地址增加4096字节（512个数据，每个数据8字节）
    end
end

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        return_num_cnt <= 0;
    end
    else if (return_req) begin // 接收到新的返回请求时，计数器清零
        return_num_cnt <= 0;
    end
    else if (write_ack) begin
        return_num_cnt <= return_num_cnt + 1;
    end
end

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        return_keep <= 0;
    end
    else if (return_req) begin // 接收到新的返回请求时，保持写入状态
        return_keep <= 1;
    end
    else if ((return_num_cnt >= (return_patch_num - 1)) & write_ack) begin // 当所有patch都写完后，清除return_keep信号
        return_keep <= 0;
    end
end

assign return_finish = ~(return_keep | return_req); // 当没有新的请求且所有patch都写完后，表示返回操作完成

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        write_ddr_state <= IDLE;
        cnt <= 0;
    end
    else begin
        case (write_ddr_state)
            IDLE: begin
                if (((~return_buffer_almost_empty) | output_buffer_done) & return_keep)begin // 当有数据且处于写入状态时，开始写入数据
                    write_ddr_state <= WRITE_REQ;
                end
            end

            WRITE_REQ: begin
                if (m00_axi_awready & m00_axi_awvalid) begin // 当AXI-4写地址有效且准备好时，进入写数据状态
                    write_ddr_state <= WRITE_DATA;
                    cnt <= 0;
                end
            end

            WRITE_DATA: begin
                if (m00_axi_wready & m00_axi_wvalid) begin // 当AXI-4写数据有效且准备好时，开始写入数据
                    cnt <= cnt + 1;
                end
                if (write_ack) begin // 每次写回响应到来时，表示本次写事务已经完成
                    write_ddr_state <= CHECK_WRITE_FINISH;
                end
            end

            CHECK_WRITE_FINISH: begin
                write_ddr_state <= IDLE;
            end
        endcase
    end
end

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        m00_axi_bready <= 1'b0;
    end
    else if (write_ack) begin // 当本次写事务完成后，清除m00_axi_bready信号，准备下一次写事务
        m00_axi_bready <= 1'b0;
    end
    else if (m00_axi_bvalid) begin // 当接收到写回响应时，表示本次写事务已经完成，可以进行下一次写事务
        m00_axi_bready <= 1'b1;
    end
    else begin
        m00_axi_bready <= 1'b0;
    end
end

assign m00_axi_awvalid = (write_ddr_state == WRITE_REQ); // 当处于写请求状态时，表示AXI-4写地址有效
// 当处于写数据状态且返回缓冲区不为空或输出缓冲区完成且计数器未达到突发长度时，表示AXI-4写数据有效
assign m00_axi_wvalid = (write_ddr_state == WRITE_DATA) & ((~return_buffer_empty) | output_buffer_done) & (cnt <= m00_axi_awlen);
// because the xilinx fifo is big-endian, we need to swap the data when using xilinx device
generate
    if (`device == "xilinx") begin
        assign m00_axi_wdata = {return_buffer_data[127:0], return_buffer_data[255:128], return_buffer_data[383:256], return_buffer_data[511:384]};
    end
    else if (`device == "simulation") begin
        assign m00_axi_wdata = return_buffer_data;
    end
endgenerate

assign m00_axi_wlast = (cnt == m00_axi_awlen) && m00_axi_wvalid && m00_axi_wready; // 当计数器达到突发长度且AXI-4写数据有效且准备好时，表示本次写事务的最后一个数据

assign return_buffer_rd_en = m00_axi_wvalid && m00_axi_wready; // 当AXI-4写数据有效且准备好时，从返回缓冲区读取数据

assign write_ack = m00_axi_bvalid & m00_axi_bready; // 当接收到写回响应时，表示本次写事务已经完成，可以进行下一次写事务

endmodule