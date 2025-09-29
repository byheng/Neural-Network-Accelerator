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
    parameter MEM_ADDR_WIDTH = `MEM_ADDR_WIDTH, // 32
    parameter MEM_DATA_WIDTH = `MEM_DATA_WIDTH // 512
)
(
    input                           system_clk,
    input                           rst_n,
    input                           task_start,
    // 超参数加载
    (* keep = "true" *)input   [MEM_ADDR_WIDTH-1:0]    weight_data_length,
    // weight_and_bias_data
    output  [MEM_DATA_WIDTH-1:0]    weight_and_bias_data,  // --> Weight_buffer
    output                          weight_and_bias_valid,
    input                           weight_buffer_ready,
    // feature_output_data
    output  [MEM_DATA_WIDTH-1:0]    feature_output_data,  // --> feature_buffer
    output                          feature_buffer_1_valid,
    output                          feature_buffer_2_valid,
    input                           feature_buffer_1_ready,
    input                           feature_buffer_2_ready,
    input                           feature_double_patch,        // 输入数据是否为双批，单批是8输入通道，双批是16输入通道
    input   [MEM_ADDR_WIDTH-1:0]    feature_input_base_addr,     // 输入特征基地址
    input   [MEM_ADDR_WIDTH-1:0]    feature_patch_num,           // 单批8通道数据大小
    input                           load_feature_begin,          // 开始读取一批数据
    input                           free_feature_read_addr,      // 释放当前批数据读取地址
    output                          load_feature_finish,         // 读取一批数据结束
    // AXI-4 Only read
    output  reg[MEM_ADDR_WIDTH-1:0] m00_axi_araddr,     // AXI-4 读地址
    output  reg[7:0]                m00_axi_arlen,      // AXI-4 读突发长度,本次读请求需要连续读取的数据个数。如果 arlen 为 n，则本次读请求需要连续读取 n+1 个数据
    output  [2:0]                   m00_axi_arsize,     // 本次读请求单个返回数据的宽度的对数，宽度以字节为单位。 例如，arsize=3'b010表示每次传输2^2=4个字节（32位）
    output  [1:0]                   m00_axi_arburst,    // AXI-4 读突发类型,00:单次突发;01:递增突发;10:包裹突发
    output                          m00_axi_arlock,
    output  [3:0]                   m00_axi_arcache,
    output  [2:0]                   m00_axi_arprot,
    output  [3:0]                   m00_axi_arqos,
    output                          m00_axi_arvalid,    // AXI-4 读地址有效信号
    input                           m00_axi_arready,    // AXI-4 读地址就绪信号
    input   [MEM_DATA_WIDTH-1:0]    m00_axi_rdata,      // AXI-4 读数据
    input   [1:0]                   m00_axi_rresp,
    input                           m00_axi_rlast,      // AXI-4 读数据最后一个信号
    input                           m00_axi_rvalid,     // AXI-4 读数据有效信号
    output                          m00_axi_rready      // AXI-4 读数据就绪信号
);

// parameter declaration
localparam [1:0] READ_IDLE = 2'b00, READ_REQ = 2'b01, READ_DATA = 2'b10;

// signal declaration
(* keep = "true" *)reg [1:0]                read_state;
(* keep = "true" *)reg [1:0]                read_who; // 00:无操作，01:读取weight和bias，10:读取feature
wire                     read_data_valid;
wire[MEM_DATA_WIDTH-1:0] read_data;
(* keep = "true" *)reg                      weight_read_req;    // 新计算开启拉高，直到加载完毕拉低
(* keep = "true" *)reg [MEM_ADDR_WIDTH-1:0] weight_read_addr;

reg                      feature_read_req, feature_read_req_d1;
wire                     feature_read_req_negedge;
reg [MEM_ADDR_WIDTH-1:0] feature_patch_base_addr;
wire[MEM_ADDR_WIDTH-1:0] feature_patch_addr;
(* keep = "true" *)reg                      feature_read_patch;
reg [MEM_ADDR_WIDTH-1:0] feature_read_addr;    
(* keep = "true" *)reg [15:0]               feature_load_patch_num;

(* keep = "true" *)reg [15:0]      buffer1_cnt;
(* keep = "true" *)reg [15:0]      buffer2_cnt;

(* keep = "true" *)reg [15:0]      x_buffer1_cnt;
(* keep = "true" *)reg [15:0]      x_buffer2_cnt;

// AXI-4 Only read assign signals
assign m00_axi_arsize  = 3'b110; // 2^6 = 64 bytes = 512 bits
assign m00_axi_arburst = 2'b01; // 01:递增突发
assign m00_axi_arlock  = 1'b0; // 0:正常访问，1:排他访问
assign m00_axi_arcache = 4'b0011; // 0011: 只读且缓冲
assign m00_axi_arprot  = 3'b000; // 000: 普通的、未受保护的数据访问
assign m00_axi_arqos   = 4'b0000; // 不需要特殊的服务质量
assign m00_axi_arvalid = (read_state == READ_REQ); // 读地址有效信号
assign m00_axi_rready  = (read_state == READ_DATA); // 读数据就绪信号
assign read_data_valid = m00_axi_rvalid & m00_axi_rready; // 当读数据有效且就绪时，表示读到有效数据
assign read_data       = m00_axi_rdata; // 读到的数据

// AXI-4 读状态机
always @(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        read_state <= READ_IDLE;
        read_who   <= 2'b00;
    end else begin
        case(read_state)
            READ_IDLE: begin
                if (weight_buffer_ready & weight_read_req) begin // 当weight_buffer 准备好且需要读取weight时
                    read_state      <= READ_REQ;
                    read_who        <= 2'b01; // 01表示读取weight和bias
                    m00_axi_arlen   <= 8'd255;
                    m00_axi_araddr  <= `DDR_WEIGHT_ADDR + weight_read_addr; // 权重和偏置基地址 + 读取地址
                end
                else if (((feature_buffer_1_ready & ~feature_read_patch) | (feature_buffer_2_ready & feature_read_patch)) & feature_read_req) begin
                    read_state      <= READ_REQ;
                    read_who        <= 2'b10; // 10表示读取feature
                    m00_axi_arlen   <= 8'd63;
                    m00_axi_araddr  <= feature_input_base_addr + feature_patch_addr + feature_read_addr;
                end
            end

            READ_REQ: begin
                if (m00_axi_arready) begin // 当读地址准备好时，表示可以进行读操作
                    read_state <= READ_DATA;
                end
            end

            READ_DATA: begin
                if (m00_axi_rlast & read_data_valid) begin // 当读到最后一个数据且数据有效时，表示本次读操作完成
                    read_state <= READ_IDLE;
                    read_who   <= 2'b00;
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
    else if (task_start) begin  // 新计算开始，拉高读取请求
        weight_read_req <= 1'b1;
    end
    else if (weight_read_addr == weight_data_length) begin // 当读取地址达到权重数据长度时，表示读取完毕，拉低请求
        weight_read_req <= 1'b0;
    end

    if(~rst_n) begin
        weight_read_addr <= 0;
    end
    else if (task_start) begin // 新计算开始，地址归零
        weight_read_addr <= 0;
    end
    else if (read_data_valid & m00_axi_rlast & (read_who == 2'b01)) begin // 当读到最后一个数据且读取的是weight时，地址加偏移量0x4000（16KB）
        weight_read_addr <= weight_read_addr + 32'h4000;
    end
end

// 分配weight_and_bias_data
assign weight_and_bias_data  = read_data;
assign weight_and_bias_valid = (read_who == 2'b01) & read_data_valid;

// 分配输入数据
always @(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        feature_read_req <= 1'b0;
    end
    else if (load_feature_begin) begin // 新特征加载开始，拉高读取请求
        feature_read_req <= 1'b1;
    end
    else if (feature_load_patch_num == feature_patch_num - 1) begin // 当读取的patch数量达到设定值时，表示读取完毕，拉低请求
        if (read_data_valid & m00_axi_rlast & (read_who == 2'b10) & (feature_double_patch == feature_read_patch)) begin
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
    else if (read_data_valid & m00_axi_rlast & (read_who == 2'b10)) begin
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
    else if (read_data_valid & m00_axi_rlast & (read_who == 2'b10) & (feature_double_patch == feature_read_patch)) begin 
        feature_read_addr <= feature_read_addr + 32'h1000; // 每读完一个patch，地址加偏移量0x1000（4KB）
    end
end

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        feature_load_patch_num <= 0;
    end
    else if (load_feature_begin) begin
        feature_load_patch_num <= 0;
    end
    else if (read_data_valid & m00_axi_rlast & (read_who == 2'b10) & (feature_double_patch == feature_read_patch)) begin
        feature_load_patch_num <= feature_load_patch_num + 1; // 每读完一个patch，数量加1
    end
end

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n)
        feature_read_req_d1 <= 1'b0;
    else 
        feature_read_req_d1 <= feature_read_req;
end
assign feature_read_req_negedge = ~feature_read_req & feature_read_req_d1; // 读取请求下降沿

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        feature_patch_base_addr <= 0;
    end
    else if (free_feature_read_addr) begin
        feature_patch_base_addr <= 0;
    end
    else if (feature_read_req_negedge) begin // 每次读取请求下降沿，表示一批数据读取完毕，基地址加上当前批数据大小
        if (feature_double_patch) begin 
            feature_patch_base_addr <= feature_patch_base_addr + (feature_patch_num<<13); // 双批时加两倍数据大小
        end
        else begin
            feature_patch_base_addr <= feature_patch_base_addr + (feature_patch_num<<12); // 单批时加一倍数据大小
        end
    end
end

// 当没有在读取patch时，地址为基地址
// 当在读取patch时，地址为基地址加上当前批数据大小
assign feature_patch_addr = (!feature_read_patch) ? feature_patch_base_addr : feature_patch_base_addr + (feature_patch_num<<12);

assign feature_output_data  = read_data;
assign feature_buffer_1_valid = (read_who == 2'b10) & read_data_valid & (~feature_read_patch); // 特征缓冲区1有效
assign feature_buffer_2_valid = (read_who == 2'b10) & read_data_valid & feature_read_patch; // 特征缓冲区2有效  

assign load_feature_finish = ~feature_read_req; // 当读取请求拉低时，表示一批数据读取完毕

always@(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        buffer1_cnt <= 0;
    end
    else if (load_feature_begin) begin
        buffer1_cnt <= 0;
    end
    else if (feature_buffer_1_valid) begin
        buffer1_cnt <= buffer1_cnt + 1;
    end
end

always@(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        buffer2_cnt <= 0;
    end
    else if (load_feature_begin) begin
        buffer2_cnt <= 0;
    end
    else if (feature_buffer_2_valid) begin
        buffer2_cnt <= buffer2_cnt + 1;
    end
end

always@(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        x_buffer1_cnt <= 0;
    end
    else if (load_feature_begin) begin
        x_buffer1_cnt <= 0;
    end
    else if (read_data_valid & (~feature_read_patch)) begin
        x_buffer1_cnt <= x_buffer1_cnt + 1;
    end
end

always@(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        x_buffer2_cnt <= 0;
    end
    else if (load_feature_begin) begin
        x_buffer2_cnt <= 0;
    end
    else if (read_data_valid & feature_read_patch) begin
        x_buffer2_cnt <= x_buffer2_cnt + 1;
    end
end

endmodule