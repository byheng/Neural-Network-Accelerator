/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module feature_buffer #(
    parameter FEATURE_WIDTH     = `FEATURE_WIDTH,
    parameter PE_CORE_NUM       = `PE_CORE_NUM,
    parameter MEM_DATA_WIDTH    = `MEM_DATA_WIDTH,
    parameter FETURE_DATA_WIDTH = `PE_CORE_NUM * `FEATURE_WIDTH,
    parameter CONV_KERNEL_SIZE  = `PE_NUM_PRE_CORE
)
(
    input                           system_clk            ,
    input                           rst_n                 ,
    input                           compute_begin         ,
    output                          compute_finish        ,
    input                           load_feature_begin    ,
    input [9:0]                     row_size              ,
    input [9:0]                     col_size              ,
    input                           stride                ,
    input [2:0]                     padding_size          ,
    // data path      
    input [MEM_DATA_WIDTH-1:0]      feature_data          ,
    input                           feature_buffer_1_valid,
    input                           feature_buffer_2_valid,
    output                          feature_buffer_1_ready,
    output                          feature_buffer_2_ready,
    input                           feature_double_patch  ,    // 输入数据是否为双批，单批是8输入通道，双批是16输入通道
    // output data path
    output[FETURE_DATA_WIDTH-1:0]   feature_output_data   ,
    output                          feature_output_valid  ,
    input                           feature_output_ready  ,
    // calculate data valid signal
    output                          convolution_valid     ,
    output                          pool_data_valid       ,
    output                          adder_pulse           ,
    output [9:0]                    col_size_for_cache    ,
    output [2:0]                    kernel_size
);

wire [FEATURE_WIDTH*8-1:0] feature_data_expand[3:0];
wire [FEATURE_WIDTH*4-1:0] feature_buffer_1_data[7:0];
wire [7:0]                 feature_buffer_1_almost_full;
wire [7:0]                 feature_buffer_1_empty;
wire [FEATURE_WIDTH*4-1:0] feature_buffer_2_data[7:0];
wire [7:0]                 feature_buffer_2_almost_full;
wire [7:0]                 feature_buffer_2_empty;
reg  [9:0]                 row_cnt;
reg  [9:0]                 col_cnt;
reg                        calculate_keep, calculate_keep_r1;
reg                        padding_flag;
wire                       padding_en;
reg                        padding_en_reg;
reg                        fifo_flag;
wire                       fifo_rd_en;
reg                        fifo_rd_en_reg;
wire                       fifo_empty;
wire [FEATURE_WIDTH-1:0]   fifo_output_data[PE_CORE_NUM-1:0];
wire                       compute_finish_signal;
wire                       fifo_rst;
wire [15:0]                wr_rst_busy;
wire [15:0]                rd_rst_busy;
reg  [9:0]                 row_plus_padding;
reg  [9:0]                 col_plus_padding;
reg  [3:0]                 padding_size_double;    
reg  [2:0]                 kernel_size_miner;

always@(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        row_plus_padding <= 0;
        col_plus_padding <= 0;
        padding_size_double <= 0;
        kernel_size_miner <= 0;
    end
    else begin
        row_plus_padding <= row_size + padding_size;
        col_plus_padding <= col_size + padding_size;
        padding_size_double <= padding_size << 1;
        kernel_size_miner <= kernel_size - 1;
    end
end

/*------------------------分配输入数据---------------------*/
genvar i;
generate
    for(i=0;i<4;i=i+1) begin: feature_expand
        assign feature_data_expand[i] = feature_data[(i+1)*FEATURE_WIDTH*8-1:i*FEATURE_WIDTH*8];
    end
    for(i=0;i<8;i=i+1) begin: feature_buffer_1_assign
        assign feature_buffer_1_data[i] = {feature_data_expand[0][(i+1)*FEATURE_WIDTH-1:i*FEATURE_WIDTH],
                                            feature_data_expand[1][(i+1)*FEATURE_WIDTH-1:i*FEATURE_WIDTH],
                                            feature_data_expand[2][(i+1)*FEATURE_WIDTH-1:i*FEATURE_WIDTH],
                                            feature_data_expand[3][(i+1)*FEATURE_WIDTH-1:i*FEATURE_WIDTH]};
        assign feature_buffer_2_data[i] = {feature_data_expand[0][(i+1)*FEATURE_WIDTH-1:i*FEATURE_WIDTH],
                                            feature_data_expand[1][(i+1)*FEATURE_WIDTH-1:i*FEATURE_WIDTH],
                                            feature_data_expand[2][(i+1)*FEATURE_WIDTH-1:i*FEATURE_WIDTH],
                                            feature_data_expand[3][(i+1)*FEATURE_WIDTH-1:i*FEATURE_WIDTH]};
    end
endgenerate

assign fifo_rst = (~rst_n) | load_feature_begin;

// patch 1的fifo
generate
    for (i=0;i<8;i=i+1) begin: feature_buffer_1_fifo
        feature_buffer_fifo feature_buffer_fifo_inst(
            .clk               (system_clk),
            .srst              (fifo_rst),
            .din               (feature_buffer_1_data[i]),
            .wr_en             (feature_buffer_1_valid),
            .rd_en             (fifo_rd_en),
            .dout              (fifo_output_data[i]),
            .full              (),
            .almost_full       (),
            .empty             (feature_buffer_1_empty[i]),
            .wr_rst_busy       (wr_rst_busy[i]),
            .rd_rst_busy       (rd_rst_busy[i]),
            .prog_full         (feature_buffer_1_almost_full[i])
        );
    end
endgenerate
assign feature_buffer_1_ready = ~(|feature_buffer_1_almost_full);

// patch 2的fifo
generate
    for (i=0;i<8;i=i+1) begin: feature_buffer_2_fifo
        feature_buffer_fifo feature_buffer_fifo_inst(
            .clk               (system_clk),
            .srst              (fifo_rst),
            .din               (feature_buffer_2_data[i]),
            .wr_en             (feature_buffer_2_valid),
            .rd_en             (fifo_rd_en),
            .dout              (fifo_output_data[8+i]),
            .full              (),
            .almost_full       (feature_buffer_2_almost_full[i]),
            .empty             (feature_buffer_2_empty[i]),
            .wr_rst_busy       (wr_rst_busy[8+i]),
            .rd_rst_busy       (rd_rst_busy[8+i])
        );      
    end
endgenerate
assign feature_buffer_2_ready = ~(|feature_buffer_2_almost_full);

assign fifo_empty = (feature_double_patch) ? (|feature_buffer_1_empty) | (|feature_buffer_2_empty) : (|feature_buffer_1_empty);

assign feature_output_data = (fifo_rd_en_reg) ? {fifo_output_data[15], fifo_output_data[14], fifo_output_data[13], fifo_output_data[12], 
                                                 fifo_output_data[11], fifo_output_data[10], fifo_output_data[9], fifo_output_data[8], 
                                                 fifo_output_data[7], fifo_output_data[6], fifo_output_data[5], fifo_output_data[4], 
                                                 fifo_output_data[3], fifo_output_data[2], fifo_output_data[1], fifo_output_data[0]} : 0;

/*--------------------------- 正片开始 ----------------------*/
// 考虑二维数据的数据流通通路, 首先是行列计数器
always@(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        row_cnt        <= 10'h3ff;
        col_cnt        <= 10'h3ff;
        calculate_keep <= 0;
    end
    else if (compute_begin) begin
        row_cnt        <= 0;
        col_cnt        <= 0;
        calculate_keep <= 1;
    end
    else if (calculate_keep) begin
        if (fifo_rd_en | padding_en) begin
            if (col_cnt == col_size + padding_size_double - 1) begin
                col_cnt <= 0;
                if (row_cnt == row_size + padding_size_double - 1) begin
                    row_cnt         <= row_cnt;
                    calculate_keep  <= 0;
                end
                else begin
                    row_cnt         <= row_cnt + 1;
                end
            end
            else begin
                col_cnt <= col_cnt + 1;
            end
        end
    end
end
// 对calculate_keep打拍，得到计算完成信号
always@(posedge system_clk) begin
    calculate_keep_r1 <= calculate_keep;
end
assign compute_finish_signal = calculate_keep_r1 & ~calculate_keep;

always@(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        padding_flag <= 0;
    end
    else if (calculate_keep) begin
        if ((row_cnt<padding_size)||(row_cnt>=row_plus_padding)||(col_cnt<padding_size)||(col_cnt>=col_plus_padding))begin
            padding_flag <= 1;
        end
        else begin
            padding_flag <= 0;
        end
    end
    else begin
        padding_flag <= 0;
    end
end

always@(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        fifo_flag <= 0;
    end
    else if (calculate_keep) begin
        if ((row_cnt<padding_size)||(row_cnt>=row_size+padding_size)||(col_cnt<padding_size)||(col_cnt>=col_size+padding_size)) begin
            fifo_flag <= 0;
        end
        else begin
            fifo_flag <= 1;
        end
    end
    else begin
        fifo_flag <= 0;
    end
end

assign padding_en = ((row_cnt<padding_size) | (row_cnt>=row_plus_padding) | (col_cnt<padding_size) | (col_cnt>=col_plus_padding)) & feature_output_ready & calculate_keep;
assign fifo_rd_en = (row_cnt>=padding_size) & (row_cnt<row_plus_padding) & (col_cnt>=padding_size) & (col_cnt<col_plus_padding) & feature_output_ready & calculate_keep & (~fifo_empty);

// padding 和 fifo_rd_en 都打一拍，因为fifo不是fwft模式
always@(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        padding_en_reg <= 0;
        fifo_rd_en_reg <= 0;
    end
    else begin
        padding_en_reg <= padding_en;
        fifo_rd_en_reg <= fifo_rd_en;
    end
end

// fifo输出数据
assign feature_output_valid = fifo_rd_en_reg | padding_en_reg;

// 计算何时数据为有效数据，对于卷积而言，一般是从(kernel_size-1, kernel_size-1)开始为有效数据
wire        convolution_valid_wire;
reg         convolution_valid_reg;
reg         convolution_valid_flag;
always@(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        convolution_valid_flag <= 0;
    end
    else if (row_cnt >= kernel_size_miner && col_cnt >= kernel_size_miner) begin
            convolution_valid_flag <= (stride) ? (~row_cnt[0] & ~col_cnt[0]) : 1'b1;
    end
    else begin
        convolution_valid_flag <= 1'b0;
    end
end

// always@(posedge system_clk or negedge rst_n) begin
//     if(~rst_n) begin
//         convolution_valid_reg <= 0;
//     end
//     else begin
//         convolution_valid_reg <= convolution_valid_flag & feature_output_valid;
//     end
// end

assign convolution_valid_wire = convolution_valid_flag & feature_output_valid;

// 由于卷积计算部件需要延迟10拍，所以这里的convolution_valid需要延迟10拍
reg [10:0]   convolution_valid_delay;
always@(posedge system_clk or negedge rst_n) begin
    convolution_valid_delay <= {convolution_valid_delay[9:0], convolution_valid_wire};
end

assign convolution_valid = convolution_valid_delay[10];

// 因此，calculate_finish信号也需要延迟10拍
reg [11:0]   compute_finish_delay;
always@(posedge system_clk or negedge rst_n) begin
    compute_finish_delay <= {compute_finish_delay[10:0], compute_finish_signal};
end

assign compute_finish = compute_finish_delay[11];

// 计算何时数据为adder_feature有效数据，adder_feature一般从图的左上角开始
reg [2:0]adder_feature_valid_reg;
always@(posedge system_clk or negedge rst_n) begin
    if (!rst_n) begin
        adder_feature_valid_reg <= 0;
    end
    else begin
        adder_feature_valid_reg[0] <= convolution_valid_wire;
        adder_feature_valid_reg[1] <= adder_feature_valid_reg[0];
        adder_feature_valid_reg[2] <= adder_feature_valid_reg[1];
    end
end

assign adder_pulse = adder_feature_valid_reg[0];

assign pool_data_valid = convolution_valid_delay[3];

assign col_size_for_cache = col_size + padding_size_double - 2;

endmodule