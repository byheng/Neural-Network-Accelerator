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
    output reg                          m00_axi_bready
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

assign m00_axi_awsize = 3'b110;
assign m00_axi_awburst = 2'b01;   
assign m00_axi_awlock = 1'b0;
assign m00_axi_awcache = 4'b0000;
assign m00_axi_awprot = 3'b000;
assign m00_axi_awqos = 4'b0000;
assign m00_axi_wstrb = 64'hffff_ffff_ffff_ffff;
assign m00_axi_awlen = 8'd63;

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
    else if (refresh_return_addr) begin
        m00_axi_awaddr <= return_addr;
    end
    else if (write_ack) begin
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
    else if (write_ack) begin
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
    else if ((return_num_cnt >= (return_patch_num - 1)) & write_ack) begin
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
                if (((~return_buffer_almost_empty) | output_buffer_done) & return_keep)begin
                    write_ddr_state <= WRITE_REQ;
                end
            end

            WRITE_REQ: begin
                if (m00_axi_awready & m00_axi_awvalid) begin
                    write_ddr_state <= WRITE_DATA;
                    cnt <= 0;
                end
            end

            WRITE_DATA: begin
                if (m00_axi_wready & m00_axi_wvalid) begin
                    cnt <= cnt + 1;
                end
                if (write_ack) begin
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
    else if (write_ack) begin
        m00_axi_bready <= 1'b0;
    end
    else if (m00_axi_bvalid) begin
        m00_axi_bready <= 1'b1;
    end
    else begin
        m00_axi_bready <= 1'b0;
    end
end

assign m00_axi_awvalid = (write_ddr_state == WRITE_REQ);
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

assign m00_axi_wlast = (cnt == m00_axi_awlen) && m00_axi_wvalid && m00_axi_wready;

assign return_buffer_rd_en = m00_axi_wvalid && m00_axi_wready;

assign write_ack = m00_axi_bvalid & m00_axi_bready;

endmodule