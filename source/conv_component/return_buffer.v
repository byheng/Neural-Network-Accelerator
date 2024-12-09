/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
    “要扫清一切害人虫，全无敌”
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module return_buffer #(
    parameter FEATURE_WIDTH     = `FEATURE_WIDTH,
    parameter MEM_DATA_WIDTH    = `MEM_DATA_WIDTH,
    parameter MEM_ADDR_WIDTH    = `MEM_ADDR_WIDTH
)
(
    input                               system_clk  ,       
    input                               rst_n       ,
    // data from calculate component
    input                               refresh_return_addr,
    input                               return_req,
    output                              return_finish,
    input  [15:0]                       return_patch_num,
    input  [MEM_ADDR_WIDTH-1:0]         return_addr,
    input  [FEATURE_WIDTH*8-1:0]        return_data,
    input                               return_data_valid,
    output                              return_buffer_ready,
    input                               output_buffer_done,

    // AXI-4 only for write
    output reg[MEM_ADDR_WIDTH-1:0]      m00_axi_awaddr,
    output [7:0]                        m00_axi_awlen,
    output [2:0]                        m00_axi_awsize,
    output [1:0]                        m00_axi_awburst,
    output                              m00_axi_awlock,
    output [3:0]                        m00_axi_awcache,
    output [2:0]                        m00_axi_awprot,
    output [3:0]                        m00_axi_awqos,
    output                              m00_axi_awvalid,
    input                               m00_axi_awready,
    output [MEM_DATA_WIDTH-1:0]         m00_axi_wdata,
    output [63:0]                       m00_axi_wstrb,
    output                              m00_axi_wlast,
    output                              m00_axi_wvalid,
    input                               m00_axi_wready,
    input  [1:0]                        m00_axi_bresp,
    input                               m00_axi_bvalid,
    output                              m00_axi_bready
);

// local parameters
localparam [1:0] IDLE = 2'b00, WRITE_REQ = 2'b01, WRITE_DATA = 2'b10, CHECK_WRITE_FINISH = 2'b11;

// variables declaration
wire                        return_buffer_almost_full;
wire                        return_buffer_almost_empty;
wire [MEM_DATA_WIDTH-1:0]   return_buffer_data;
wire                        return_buffer_rd_en;
reg  [1:0]                  write_ddr_state;
reg  [15:0]                 return_num_cnt;
reg                         return_keep;
reg  [7:0]                  cnt;

assign m00_axi_awsize = 3'b110;
assign m00_axi_awburst = 2'b01;   
assign m00_axi_awlock = 1'b0;
assign m00_axi_awcache = 4'b0000;
assign m00_axi_awprot = 3'b000;
assign m00_axi_awqos = 4'b0000;
assign m00_axi_wstrb = 64'hffff_ffff_ffff_ffff;
assign m00_axi_awlen = 8'd63;

assign return_buffer_ready = ~return_buffer_almost_full;

return_buffer_fifo return_buffer_fifo_inst (
    .clk            (system_clk),                
    .srst           (~rst_n),        
    .din            (return_data),        
    .wr_en          (return_data_valid),        
    .rd_en          (return_buffer_rd_en),        
    .dout           (return_buffer_data),        
    .full           (),        
    .almost_full    (),            
    .empty          (),
    .almost_empty   (),        
    .prog_full      (return_buffer_almost_full),    
    .prog_empty     (return_buffer_almost_empty),        
    .wr_rst_busy    (),        
    .rd_rst_busy    ()       
);

/*-------------------------------- DDR AXI-4 write logic --------------------------*/
always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        m00_axi_awaddr <= 0;
    end
    else if (refresh_return_addr) begin
        m00_axi_awaddr <= return_addr;
    end
    else if (m00_axi_bvalid) begin
        m00_axi_awaddr <= m00_axi_awaddr + 'd4096;
    end
end

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        return_num_cnt <= 0;
    end
    else if (return_req) begin
        return_num_cnt <= 0;
    end
    else if (m00_axi_bvalid) begin
        return_num_cnt <= return_num_cnt + 1;
    end
end

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        return_keep <= 0;
    end
    else if (return_req) begin
        return_keep <= 1;
    end
    else if ((return_num_cnt == return_patch_num - 1) && m00_axi_bvalid) begin
        return_keep <= 0;
    end
end

assign return_finish = ~(return_keep | return_req);

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        write_ddr_state <= IDLE;
        cnt <= 0;
    end
    else begin
        case (write_ddr_state)
            IDLE: begin
                if ((~return_buffer_almost_empty | output_buffer_done) & return_keep)begin
                    write_ddr_state <= WRITE_REQ;
                end
            end

            WRITE_REQ: begin
                if (m00_axi_awready) begin
                    write_ddr_state <= WRITE_DATA;
                    cnt <= 0;
                end
            end

            WRITE_DATA: begin
                if (m00_axi_wready & m00_axi_wvalid) begin
                    cnt <= cnt + 1;
                end
                if (m00_axi_bvalid) begin
                    write_ddr_state <= CHECK_WRITE_FINISH;
                end
            end

            CHECK_WRITE_FINISH: begin
                write_ddr_state <= IDLE;
            end
        endcase
    end
end

assign m00_axi_awvalid = (write_ddr_state == WRITE_REQ);
assign m00_axi_wvalid = (write_ddr_state == WRITE_DATA);
assign m00_axi_bready = 1'b1;
assign m00_axi_wdata = {return_buffer_data[127:0], return_buffer_data[255:128], return_buffer_data[383:256], return_buffer_data[511:384]};
assign m00_axi_wlast = (cnt == m00_axi_awlen) && m00_axi_wvalid && m00_axi_wready;

assign return_buffer_rd_en = m00_axi_wvalid && m00_axi_wready;

endmodule