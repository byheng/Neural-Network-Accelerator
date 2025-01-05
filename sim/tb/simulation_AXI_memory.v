/*

Copyright (c) 2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

`include "../../parameters.v"
/*
 * AXI4 RAM
 */
module axi_ram #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 512,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Width of ID signal
    parameter ID_WIDTH = 8,
    // Extra pipeline register on output
    parameter PIPELINE_OUTPUT = 0
)
(
    input  wire                   clk,
    input  wire                   rst,

    input  wire [ID_WIDTH-1:0]    s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [7:0]             s_axi_awlen,
    input  wire [2:0]             s_axi_awsize,
    input  wire [1:0]             s_axi_awburst,
    input  wire                   s_axi_awlock,
    input  wire [3:0]             s_axi_awcache,
    input  wire [2:0]             s_axi_awprot,
    input  wire                   s_axi_awvalid,
    output wire                   s_axi_awready,
    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axi_wstrb,
    input  wire                   s_axi_wlast,
    input  wire                   s_axi_wvalid,
    output wire                   s_axi_wready,
    output wire [ID_WIDTH-1:0]    s_axi_bid,
    output wire [1:0]             s_axi_bresp,
    output wire                   s_axi_bvalid,
    input  wire                   s_axi_bready,
    input  wire [ID_WIDTH-1:0]    s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [7:0]             s_axi_arlen,
    input  wire [2:0]             s_axi_arsize,
    input  wire [1:0]             s_axi_arburst,
    input  wire                   s_axi_arlock,
    input  wire [3:0]             s_axi_arcache,
    input  wire [2:0]             s_axi_arprot,
    input  wire                   s_axi_arvalid,
    output wire                   s_axi_arready,
    output wire [ID_WIDTH-1:0]    s_axi_rid,
    output wire [DATA_WIDTH-1:0]  s_axi_rdata,
    output wire [1:0]             s_axi_rresp,
    output wire                   s_axi_rlast,
    output wire                   s_axi_rvalid,
    input  wire                   s_axi_rready
);

parameter VALID_ADDR_WIDTH = ADDR_WIDTH - $clog2(STRB_WIDTH);
parameter WORD_WIDTH = STRB_WIDTH;
parameter WORD_SIZE = DATA_WIDTH/WORD_WIDTH;

// bus width assertions
initial begin
    if (WORD_SIZE * STRB_WIDTH != DATA_WIDTH) begin
        $error("Error: AXI data width not evenly divisble (instance %m)");
        $finish;
    end

    if (2**$clog2(WORD_WIDTH) != WORD_WIDTH) begin
        $error("Error: AXI word width must be even power of two (instance %m)");
        $finish;
    end
end

localparam [0:0]
    READ_STATE_IDLE = 1'd0,
    READ_STATE_BURST = 1'd1;

reg [0:0] read_state_reg = READ_STATE_IDLE, read_state_next;

localparam [1:0]
    WRITE_STATE_IDLE = 2'd0,
    WRITE_STATE_BURST = 2'd1,
    WRITE_STATE_RESP = 2'd2;

reg [1:0] write_state_reg = WRITE_STATE_IDLE, write_state_next;

reg mem_wr_en;
reg mem_rd_en;

reg [ID_WIDTH-1:0] read_id_reg = {ID_WIDTH{1'b0}}, read_id_next;
reg [ADDR_WIDTH-1:0] read_addr_reg = {ADDR_WIDTH{1'b0}}, read_addr_next;
reg [7:0] read_count_reg = 8'd0, read_count_next;
reg [2:0] read_size_reg = 3'd0, read_size_next;
reg [1:0] read_burst_reg = 2'd0, read_burst_next;
reg [ID_WIDTH-1:0] write_id_reg = {ID_WIDTH{1'b0}}, write_id_next;
reg [ADDR_WIDTH-1:0] write_addr_reg = {ADDR_WIDTH{1'b0}}, write_addr_next;
reg [7:0] write_count_reg = 8'd0, write_count_next;
reg [2:0] write_size_reg = 3'd0, write_size_next;
reg [1:0] write_burst_reg = 2'd0, write_burst_next;

reg s_axi_awready_reg = 1'b0, s_axi_awready_next;
reg s_axi_wready_reg = 1'b0, s_axi_wready_next;
reg [ID_WIDTH-1:0] s_axi_bid_reg = {ID_WIDTH{1'b0}}, s_axi_bid_next;
reg s_axi_bvalid_reg = 1'b0, s_axi_bvalid_next;
reg s_axi_arready_reg = 1'b0, s_axi_arready_next;
reg [ID_WIDTH-1:0] s_axi_rid_reg = {ID_WIDTH{1'b0}}, s_axi_rid_next;
reg [DATA_WIDTH-1:0] s_axi_rdata_reg = {DATA_WIDTH{1'b0}}, s_axi_rdata_next;
reg s_axi_rlast_reg = 1'b0, s_axi_rlast_next;
reg s_axi_rvalid_reg = 1'b0, s_axi_rvalid_next;
reg [ID_WIDTH-1:0] s_axi_rid_pipe_reg = {ID_WIDTH{1'b0}};
reg [DATA_WIDTH-1:0] s_axi_rdata_pipe_reg = {DATA_WIDTH{1'b0}};
reg s_axi_rlast_pipe_reg = 1'b0;
reg s_axi_rvalid_pipe_reg = 1'b0;

// (* RAM_STYLE="BLOCK" *)
reg [DATA_WIDTH-1:0] mem[1310719:0];  // 80 MB

wire [VALID_ADDR_WIDTH-1:0] s_axi_awaddr_valid = s_axi_awaddr >> (ADDR_WIDTH - VALID_ADDR_WIDTH);
wire [VALID_ADDR_WIDTH-1:0] s_axi_araddr_valid = s_axi_araddr >> (ADDR_WIDTH - VALID_ADDR_WIDTH);
wire [VALID_ADDR_WIDTH-1:0] read_addr_valid = read_addr_reg >> (ADDR_WIDTH - VALID_ADDR_WIDTH);
wire [VALID_ADDR_WIDTH-1:0] write_addr_valid = write_addr_reg >> (ADDR_WIDTH - VALID_ADDR_WIDTH);

assign s_axi_awready = s_axi_awready_reg;
assign s_axi_wready = s_axi_wready_reg;
assign s_axi_bid = s_axi_bid_reg;
assign s_axi_bresp = 2'b00;
assign s_axi_bvalid = s_axi_bvalid_reg;
assign s_axi_arready = s_axi_arready_reg;
assign s_axi_rid = PIPELINE_OUTPUT ? s_axi_rid_pipe_reg : s_axi_rid_reg;
assign s_axi_rdata = PIPELINE_OUTPUT ? s_axi_rdata_pipe_reg : s_axi_rdata_reg;
assign s_axi_rresp = 2'b00;
assign s_axi_rlast = PIPELINE_OUTPUT ? s_axi_rlast_pipe_reg : s_axi_rlast_reg;
assign s_axi_rvalid = PIPELINE_OUTPUT ? s_axi_rvalid_pipe_reg : s_axi_rvalid_reg;

integer i, j;

always @* begin
    write_state_next = WRITE_STATE_IDLE;

    mem_wr_en = 1'b0;

    write_id_next = write_id_reg;
    write_addr_next = write_addr_reg;
    write_count_next = write_count_reg;
    write_size_next = write_size_reg;
    write_burst_next = write_burst_reg;

    s_axi_awready_next = 1'b0;
    s_axi_wready_next = 1'b0;
    s_axi_bid_next = s_axi_bid_reg;
    s_axi_bvalid_next = s_axi_bvalid_reg && !s_axi_bready;

    case (write_state_reg)
        WRITE_STATE_IDLE: begin
            s_axi_awready_next = 1'b1;

            if (s_axi_awready && s_axi_awvalid) begin
                write_id_next = s_axi_awid;
                write_addr_next = s_axi_awaddr;
                write_count_next = s_axi_awlen;
                write_size_next = s_axi_awsize < $clog2(STRB_WIDTH) ? s_axi_awsize : $clog2(STRB_WIDTH);
                write_burst_next = s_axi_awburst;

                s_axi_awready_next = 1'b0;
                s_axi_wready_next = 1'b1;
                write_state_next = WRITE_STATE_BURST;
            end else begin
                write_state_next = WRITE_STATE_IDLE;
            end
        end
        WRITE_STATE_BURST: begin
            s_axi_wready_next = 1'b1;

            if (s_axi_wready && s_axi_wvalid) begin
                mem_wr_en = 1'b1;
                if (write_burst_reg != 2'b00) begin
                    write_addr_next = write_addr_reg + (1 << write_size_reg);
                end
                write_count_next = write_count_reg - 1;
                if (write_count_reg > 0) begin
                    write_state_next = WRITE_STATE_BURST;
                end else begin
                    s_axi_wready_next = 1'b0;
                    if (s_axi_bready || !s_axi_bvalid) begin
                        s_axi_bid_next = write_id_reg;
                        s_axi_bvalid_next = 1'b1;
                        s_axi_awready_next = 1'b1;
                        write_state_next = WRITE_STATE_IDLE;
                    end else begin
                        write_state_next = WRITE_STATE_RESP;
                    end
                end
            end else begin
                write_state_next = WRITE_STATE_BURST;
            end
        end
        WRITE_STATE_RESP: begin
            if (s_axi_bready || !s_axi_bvalid) begin
                s_axi_bid_next = write_id_reg;
                s_axi_bvalid_next = 1'b1;
                s_axi_awready_next = 1'b1;
                write_state_next = WRITE_STATE_IDLE;
            end else begin
                write_state_next = WRITE_STATE_RESP;
            end
        end
    endcase
end

always @(posedge clk) begin
    write_state_reg <= write_state_next;

    write_id_reg <= write_id_next;
    write_addr_reg <= write_addr_next;
    write_count_reg <= write_count_next;
    write_size_reg <= write_size_next;
    write_burst_reg <= write_burst_next;

    s_axi_awready_reg <= s_axi_awready_next;
    s_axi_wready_reg <= s_axi_wready_next;
    s_axi_bid_reg <= s_axi_bid_next;
    s_axi_bvalid_reg <= s_axi_bvalid_next;

    for (i = 0; i < WORD_WIDTH; i = i + 1) begin
        if (mem_wr_en & s_axi_wstrb[i]) begin
            mem[write_addr_valid][WORD_SIZE*i +: WORD_SIZE] <= s_axi_wdata[WORD_SIZE*i +: WORD_SIZE];
        end
    end

    if (rst) begin
        write_state_reg <= WRITE_STATE_IDLE;

        s_axi_awready_reg <= 1'b0;
        s_axi_wready_reg <= 1'b0;
        s_axi_bvalid_reg <= 1'b0;
    end
end

always @* begin
    read_state_next = READ_STATE_IDLE;

    mem_rd_en = 1'b0;

    s_axi_rid_next = s_axi_rid_reg;
    s_axi_rlast_next = s_axi_rlast_reg;
    s_axi_rvalid_next = s_axi_rvalid_reg && !(s_axi_rready || (PIPELINE_OUTPUT && !s_axi_rvalid_pipe_reg));

    read_id_next = read_id_reg;
    read_addr_next = read_addr_reg;
    read_count_next = read_count_reg;
    read_size_next = read_size_reg;
    read_burst_next = read_burst_reg;

    s_axi_arready_next = 1'b0;

    case (read_state_reg)
        READ_STATE_IDLE: begin
            s_axi_arready_next = 1'b1;

            if (s_axi_arready && s_axi_arvalid) begin
                read_id_next = s_axi_arid;
                read_addr_next = s_axi_araddr;
                read_count_next = s_axi_arlen;
                read_size_next = s_axi_arsize < $clog2(STRB_WIDTH) ? s_axi_arsize : $clog2(STRB_WIDTH);
                read_burst_next = s_axi_arburst;

                s_axi_arready_next = 1'b0;
                read_state_next = READ_STATE_BURST;
            end else begin
                read_state_next = READ_STATE_IDLE;
            end
        end
        READ_STATE_BURST: begin
            if (s_axi_rready || (PIPELINE_OUTPUT && !s_axi_rvalid_pipe_reg) || !s_axi_rvalid_reg) begin
                mem_rd_en = 1'b1;
                s_axi_rvalid_next = 1'b1;
                s_axi_rid_next = read_id_reg;
                s_axi_rlast_next = read_count_reg == 0;
                if (read_burst_reg != 2'b00) begin
                    read_addr_next = read_addr_reg + (1 << read_size_reg);
                end
                read_count_next = read_count_reg - 1;
                if (read_count_reg > 0) begin
                    read_state_next = READ_STATE_BURST;
                end else begin
                    s_axi_arready_next = 1'b1;
                    read_state_next = READ_STATE_IDLE;
                end
            end else begin
                read_state_next = READ_STATE_BURST;
            end
        end
    endcase
end

always @(posedge clk) begin
    read_state_reg <= read_state_next;

    read_id_reg <= read_id_next;
    read_addr_reg <= read_addr_next;
    read_count_reg <= read_count_next;
    read_size_reg <= read_size_next;
    read_burst_reg <= read_burst_next;

    s_axi_arready_reg <= s_axi_arready_next;
    s_axi_rid_reg <= s_axi_rid_next;
    s_axi_rlast_reg <= s_axi_rlast_next;
    s_axi_rvalid_reg <= s_axi_rvalid_next;

    if (mem_rd_en) begin
        s_axi_rdata_reg <= mem[read_addr_valid];
    end

    if (!s_axi_rvalid_pipe_reg || s_axi_rready) begin
        s_axi_rid_pipe_reg <= s_axi_rid_reg;
        s_axi_rdata_pipe_reg <= s_axi_rdata_reg;
        s_axi_rlast_pipe_reg <= s_axi_rlast_reg;
        s_axi_rvalid_pipe_reg <= s_axi_rvalid_reg;
    end

    if (rst) begin
        read_state_reg <= READ_STATE_IDLE;

        s_axi_arready_reg <= 1'b0;
        s_axi_rvalid_reg <= 1'b0;
        s_axi_rvalid_pipe_reg <= 1'b0;
    end
end

// 初始化内存中的数据
parameter memory_patch     = "F:/FPGA/accelerator_core/script/memory_patch.txt";
parameter weight_data_path = "F:/FPGA/accelerator_core/script/WeightAndBias.bin";
parameter picture_data_path= "F:/FPGA/accelerator_core/script/picture.bin";

// 读取权重文件
integer file, o, addr, d, times;
reg [31:0]weight_first_addr, bias_first_addr, picture_first_addr;
reg [7:0] byte_data[63:0];
integer out_file, in_file;
initial begin
    // for (i = 0; i < 2**VALID_ADDR_WIDTH; i = i + 2**(VALID_ADDR_WIDTH/2)) begin
    //     for (j = i; j < i + 2**(VALID_ADDR_WIDTH/2); j = j + 1) begin
    //         mem[j] = 0;
    //     end
    // end
    // // load weight
    // file = $fopen(weight_data_path, "rb");
    // addr = 0;
    // weight_first_addr = `DDR_WEIGHT_ADDR / 64;
    // while (!$feof(file)) begin
    //     o = $fread(byte_data, file);
    //     mem[weight_first_addr + addr] = {byte_data[63], byte_data[62], byte_data[61], byte_data[60], byte_data[59], byte_data[58], byte_data[57], byte_data[56], byte_data[55], byte_data[54], 
    //                                      byte_data[53], byte_data[52], byte_data[51], byte_data[50], byte_data[49], byte_data[48], byte_data[47], byte_data[46], byte_data[45], byte_data[44], 
    //                                      byte_data[43], byte_data[42], byte_data[41], byte_data[40], byte_data[39], byte_data[38], byte_data[37], byte_data[36], byte_data[35], byte_data[34], 
    //                                      byte_data[33], byte_data[32], byte_data[31], byte_data[30], byte_data[29], byte_data[28], byte_data[27], byte_data[26], byte_data[25], byte_data[24], 
    //                                      byte_data[23], byte_data[22], byte_data[21], byte_data[20], byte_data[19], byte_data[18], byte_data[17], byte_data[16], byte_data[15], byte_data[14], 
    //                                      byte_data[13], byte_data[12], byte_data[11], byte_data[10], byte_data[9], byte_data[8], byte_data[7], byte_data[6], byte_data[5], byte_data[4], 
    //                                      byte_data[3], byte_data[2], byte_data[1], byte_data[0]};
    //     addr = addr + 1;
    // end
    // $display("read data num: %d", addr<<6);
    // $fclose(file);
    // // load picture
    // file = $fopen(picture_data_path, "rb");
    // addr = 0;
    // picture_first_addr = `DDR_PICTURE_ADDR / 64;
    // while (!$feof(file)) begin
    //     o = $fread(byte_data, file);
    //     mem[picture_first_addr + addr] = {byte_data[63], byte_data[62], byte_data[61], byte_data[60], byte_data[59], byte_data[58], byte_data[57], byte_data[56], byte_data[55], byte_data[54], 
    //                                      byte_data[53], byte_data[52], byte_data[51], byte_data[50], byte_data[49], byte_data[48], byte_data[47], byte_data[46], byte_data[45], byte_data[44], 
    //                                      byte_data[43], byte_data[42], byte_data[41], byte_data[40], byte_data[39], byte_data[38], byte_data[37], byte_data[36], byte_data[35], byte_data[34], 
    //                                      byte_data[33], byte_data[32], byte_data[31], byte_data[30], byte_data[29], byte_data[28], byte_data[27], byte_data[26], byte_data[25], byte_data[24], 
    //                                      byte_data[23], byte_data[22], byte_data[21], byte_data[20], byte_data[19], byte_data[18], byte_data[17], byte_data[16], byte_data[15], byte_data[14], 
    //                                      byte_data[13], byte_data[12], byte_data[11], byte_data[10], byte_data[9], byte_data[8], byte_data[7], byte_data[6], byte_data[5], byte_data[4], 
    //                                      byte_data[3], byte_data[2], byte_data[1], byte_data[0]};
    //     addr = addr + 1;
    // end
    // $display("read data num: %d", addr<<6);
    // $fclose(file);
    // // save mem to txt
    // file = $fopen(memory_patch, "w");
    // $writememh(memory_patch, mem);
    // $fclose(file);
    out_file = $fopen("F:/FPGA/accelerator_core/script/output.txt", "w");
    in_file = $fopen("F:/FPGA/accelerator_core/script/input.txt", "w");
    file = $fopen(memory_patch, "r");
    $readmemh(memory_patch, mem);
    d = 0;
    times = $time;
end

always @(posedge clk) begin
    if (conv_control_tb.u_accelerator_control.get_order_inst.next_calculate_application)begin
        for (i=0;i<conv_control_tb.u_accelerator_control.return_patch_num*conv_control_tb.u_accelerator_control.feature_output_patch_num*64;i=i+1)begin
            $fwrite(out_file, "%h\n", mem[(conv_control_tb.u_accelerator_control.return_addr/64)+i]);
        end
        $fwrite(out_file, "#%d\n", conv_control_tb.u_accelerator_control.get_order_inst.id);

        for (i=0;i<conv_control_tb.u_accelerator_control.feature_input_patch_num*conv_control_tb.u_accelerator_control.feature_patch_num*64*(1+conv_control_tb.u_accelerator_control.feature_double_patch);i=i+1)begin
            $fwrite(in_file, "%h\n", mem[(conv_control_tb.u_accelerator_control.feature_input_base_addr/64)+i]);
        end
        $fwrite(in_file, "#%d\n", conv_control_tb.u_accelerator_control.get_order_inst.id);

        if (conv_control_tb.u_accelerator_control.get_order_inst.id==73) begin
            if (file != 0) begin
                $writememh(memory_patch, mem);
                $display("the %d layer simulation is finish", conv_control_tb.u_accelerator_control.get_order_inst.id);
                // $display("save memory data to file");
                // $display("weight_cnt==%d", conv_control_tb.u_accelerator_control.u_Weight_buffer.debug_weight_cnt);
                $display("Using time: %d us", (($time - times) / 10000000));
                times = $time;
                $fclose(file);
                $$fclose(out_file);
                file = 0;
                $stop;
            end
        end
        else begin
            $display("the %d layer simulation is finish", conv_control_tb.u_accelerator_control.get_order_inst.id);
            // $display("weight_cnt==%d", conv_control_tb.u_accelerator_control.u_Weight_buffer.debug_weight_cnt); 
            $display("Using time: %d us", (($time - times) / 10000000));
            times = $time;
        end
    end
    else if (conv_control_tb.u_accelerator_control.feature_input_patch_num!=0 && d==0) begin
        for (i=0;i<conv_control_tb.u_accelerator_control.feature_input_patch_num*conv_control_tb.u_accelerator_control.feature_patch_num*64;i=i+1)begin
            $fwrite(out_file, "%h\n", mem[(conv_control_tb.u_accelerator_control.feature_input_base_addr/64)+i]);
        end
        $fwrite(out_file, "#%d\n", conv_control_tb.u_accelerator_control.get_order_inst.id);
        d = 1;
    end 
end

endmodule

`resetall
