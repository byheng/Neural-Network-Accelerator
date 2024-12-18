/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
    module_intro: 这个模块负责读取DDR的数据，包括Feature数据，Weight数据，Bias数据
    state       : simulation finish
*/
`timescale 1ns/100fs

`include "../../parameters.v" 

module read_ddr_control #(
    parameter MEM_ADDR_WIDTH = `MEM_ADDR_WIDTH,
    parameter MEM_DATA_WIDTH = `MEM_DATA_WIDTH
)
(
    input                           system_clk,
    input                           rst_n,
    input                           task_start,
    // 超参数加载
    input   [MEM_ADDR_WIDTH-1:0]    weight_data_length,
    // weight_and_bias_data
    output  [MEM_DATA_WIDTH-1:0]    weight_and_bias_data,
    output                          weight_and_bias_valid,
    input                           weight_buffer_ready,
    // feature_output_data
    output  [MEM_DATA_WIDTH-1:0]    feature_output_data,
    output                          feature_buffer_1_valid,
    output                          feature_buffer_2_valid,
    input                           feature_buffer_1_ready,
    input                           feature_buffer_2_ready,
    input                           feature_double_patch,        // 输入数据是否为双批，单批是8输入通道，双批是16输入通道
    input   [MEM_ADDR_WIDTH-1:0]    feature_input_base_addr,     // 输入特征基地址
    input   [MEM_ADDR_WIDTH-1:0]    feature_patch_num,           // 单批8通道数据大小
    input                           load_feature_begin,          // 开始读取一批数据
    input                           free_feature_read_addr,      // 释放当前批数据读取地址
    // AXI-4 Only read
    output  reg[MEM_ADDR_WIDTH-1:0] m00_axi_araddr,     // 操控
    output  reg[7:0]                m00_axi_arlen,      // 操控
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
    output                          m00_axi_rready      // 操控                                 
);

// parameter declaration
localparam [1:0] READ_IDLE = 2'b00, READ_REQ = 2'b01, READ_DATA = 2'b10;

// signal declaration
reg [1:0]                read_state;
reg [1:0]                read_who;
wire                     read_data_valid;
wire[MEM_DATA_WIDTH-1:0] read_data;
reg                      weight_read_req;    // 新计算开启拉高，直到加载完毕拉低
reg [MEM_ADDR_WIDTH-1:0] weight_read_addr;

reg                      feature_read_req, feature_read_req_d1;
wire                     feature_read_req_negedge;
reg [MEM_ADDR_WIDTH-1:0] feature_patch_base_addr;
wire[MEM_ADDR_WIDTH-1:0] feature_patch_addr;
reg                      feature_read_patch;
reg [MEM_ADDR_WIDTH-1:0] feature_read_addr;    
reg [15:0]               feature_load_patch_num;

// AXI-4 Only read assign signals
assign m00_axi_arsize  = 3'b110;
assign m00_axi_arburst = 2'b01;
assign m00_axi_arlock  = 1'b0;
assign m00_axi_arcache = 4'b0011;
assign m00_axi_arprot  = 3'b000;
assign m00_axi_arqos   = 4'b0000;
assign m00_axi_arvalid = (read_state == READ_REQ);
assign m00_axi_rready  = (read_state == READ_DATA);
assign read_data_valid = m00_axi_rvalid && m00_axi_rready;
assign read_data       = m00_axi_rdata;

// AXI-4 读状态机
always @(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        read_state <= READ_IDLE;
        read_who   <= 2'b0;
    end else begin
        case(read_state)
            READ_IDLE: begin
                if (weight_buffer_ready & weight_read_req) begin
                    read_state      <= READ_REQ;
                    read_who        <= 2'b00;
                    m00_axi_arlen   <= 8'd255;
                    m00_axi_araddr  <= `DDR_WEIGHT_ADDR + weight_read_addr;
                end
                else if (((feature_buffer_1_ready & ~feature_read_patch) | (feature_buffer_2_ready & feature_read_patch)) & feature_read_req) begin
                    read_state      <= READ_REQ;
                    read_who        <= 2'b01;
                    m00_axi_arlen   <= 8'd63;
                    m00_axi_araddr  <= feature_input_base_addr + feature_patch_addr + feature_read_addr;
                end
            end

            READ_REQ: begin
                if (m00_axi_arready) begin
                    read_state <= READ_DATA;
                end
            end

            READ_DATA: begin
                if (m00_axi_rlast & m00_axi_rvalid) begin
                    read_state <= READ_IDLE;
                    read_who   <= 0;
                end
            end
        endcase
    end
end

// 权重和偏置，新计算开启拉高，直到加载完毕拉低
always @(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        weight_read_req <= 1'b0;
    end
    else if (task_start) begin
        weight_read_req <= 1'b1;
    end
    else if (weight_read_addr == weight_data_length) begin
        weight_read_req <= 1'b0;
    end

    if(~rst_n) begin
        weight_read_addr <= 0;
    end
    else if (task_start) begin
        weight_read_addr <= 0;
    end
    else if (m00_axi_rvalid & m00_axi_rlast & (read_who == 2'b00)) begin
        weight_read_addr <= weight_read_addr + 32'h4000;
    end
end

// 分配weight_and_bias_data
assign weight_and_bias_data  = read_data;
assign weight_and_bias_valid = (read_who == 2'b00) & read_data_valid;

// 分配输入数据
always @(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        feature_read_req <= 1'b0;
    end
    else if (load_feature_begin) begin
        feature_read_req <= 1'b1;
    end
    else if (feature_load_patch_num == feature_patch_num - 1) begin
        if (m00_axi_rvalid & m00_axi_rlast & (read_who == 2'b01) & (feature_double_patch == feature_read_patch)) begin
            feature_read_req <= 1'b0;
        end
    end
end

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        feature_read_patch <= 1'b0;
    end
    else if (load_feature_begin) begin
        feature_read_patch <= 1'b0;
    end
    else if (m00_axi_rlast && read_who == 2'b01) begin
        if (feature_double_patch) begin
            feature_read_patch <= ~feature_read_patch;
        end
    end
end

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        feature_read_addr <= 0;
    end
    else if (load_feature_begin) begin
        feature_read_addr <= 0;
    end
    else if (m00_axi_rvalid & m00_axi_rlast & (read_who == 2'b01) & (feature_double_patch == feature_read_patch)) begin
        feature_read_addr <= feature_read_addr + 32'h1000;
    end
end

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        feature_load_patch_num <= 0;
    end
    else if (load_feature_begin) begin
        feature_load_patch_num <= 0;
    end
    else if (m00_axi_rvalid & m00_axi_rlast & (read_who == 2'b01) & (feature_double_patch == feature_read_patch)) begin
        feature_load_patch_num <= feature_load_patch_num + 1;
    end
end

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n)
        feature_read_req_d1 <= 1'b0;
    else 
        feature_read_req_d1 <= feature_read_req;
end
assign feature_read_req_negedge = ~feature_read_req & feature_read_req_d1;

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        feature_patch_base_addr <= 0;
    end
    else if (free_feature_read_addr) begin
        feature_patch_base_addr <= 0;
    end
    else if (feature_read_req_negedge) begin
        if (feature_double_patch) begin
            feature_patch_base_addr <= feature_patch_base_addr + (feature_patch_num<<13);
        end
        else begin
            feature_patch_base_addr <= feature_patch_base_addr + (feature_patch_num<<12);
        end
    end
end

assign feature_patch_addr = (!feature_read_patch) ? feature_patch_base_addr : feature_patch_base_addr + (feature_patch_num<<12);

assign feature_output_data  = read_data;
assign feature_buffer_1_valid = (read_who == 2'b01) & read_data_valid & ~feature_read_patch;
assign feature_buffer_2_valid = (read_who == 2'b01) & read_data_valid & feature_read_patch;


endmodule