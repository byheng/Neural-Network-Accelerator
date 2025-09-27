/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
    module_intro: make a 3*3 kernel to convolution
    state       : LION WORK FINISH
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module PE_core #(
    parameter FEATURE_WIDTH       = `FEATURE_WIDTH,
    parameter WEIGHT_WIDTH        = `WEIGHT_WIDTH,
    parameter MAC_OUTPUT_WIDTH    = `MAC_OUTPUT_WIDTH,
    parameter PE_NUM_PRE_CORE     = `PE_NUM_PRE_CORE, // PE阵列每行/列PE数 3
    parameter PE_ARRAY_TOTAL_SIZE = PE_NUM_PRE_CORE * PE_NUM_PRE_CORE, // PE整列总PE数 3 * 3
    parameter BIAS_WIDTH          = WEIGHT_WIDTH + FEATURE_WIDTH // 32 = 16 + 16
)
(
    input                                       DSP_clk,
    input                                       rst_n, 
    input [WEIGHT_WIDTH-1:0]                    weight, // 一个权重数据
    input                                       weight_valid,      
    input [FEATURE_WIDTH*PE_NUM_PRE_CORE-1:0]   feature_in,   // 多个特征图数据，特征图位宽 * 3
    input [BIAS_WIDTH-1:0]                      bias,
    input                                       bias_valid, 
    input [MAC_OUTPUT_WIDTH-1:0]                adder_feature, 
    input                                       bias_or_adder_feature,      
    input                                       pulse,           
    output[MAC_OUTPUT_WIDTH-1:0]                feature_out
);

/*----------------- 缓存weight -----------------*/
reg [WEIGHT_WIDTH-1:0]   weight_array [PE_ARRAY_TOTAL_SIZE-1:0]; // 9个权重参数
reg [BIAS_WIDTH-1:0]     bias_reg;
always @(posedge DSP_clk) begin
    if (weight_valid) begin
        weight_array[PE_ARRAY_TOTAL_SIZE-1] <= weight; // 缓存weight到 weight_array 数组的最后一个位置，后续通过移位寄存器，移动到前面
    end

    if (bias_valid) begin
        bias_reg <= bias; // 缓存bias
    end
end

/*----------------- weight 移位寄存器 -----------------*/
genvar p;
generate
    for (p = 0; p < PE_ARRAY_TOTAL_SIZE-1; p=p+1) begin : weight_array_gen
        always @(posedge DSP_clk) begin
            if (weight_valid) begin
                weight_array[p] <= weight_array[p+1];
            end
        end
    end
endgenerate

/*----------------- bias 和 adder_feature 数据选择器 -----------------*/
// 通过 bias_or_adder_feature 信号确定 bias_add 的信号是 adder_feature 还是 bias_reg，需要对 bias_reg 进行符号位扩展
wire [MAC_OUTPUT_WIDTH-1:0]                 bias_add;   
assign bias_add = bias_or_adder_feature? {{`MAC_OVERFLOW_WIDTH{bias_reg[BIAS_WIDTH-1]}}, bias_reg} : adder_feature;


/*----------------- PE array ---------------------*/
wire [MAC_OUTPUT_WIDTH-1:0] output_array [PE_ARRAY_TOTAL_SIZE-1:0]; // PE整列的计算输出，每个PE都要各自的输出，所以有9个
wire [47:0]                 PCOUT [PE_ARRAY_TOTAL_SIZE-1:0];
reg  [MAC_OUTPUT_WIDTH-1:0] flow_reg1[2:0], flow_reg2[2:0], flow_reg3[2:0];
reg  [MAC_OUTPUT_WIDTH-1:0] adder1, adder2, adder3;

/* PE array 实现细节
PE_NUM_PRE_CORE = 3，实现 3 * 3 的 MAC_PE 整列
[00] [01] [02]
[10] [11] [12]
[20] [21] [22]
对于第一列的 MAC_PE (00 10 20),其 PCIN 都为 0 
对于第二、三列的 MAC_PE，其 PCIN 为前一个 MAC_PE 的 PCOUT
'd0 -> [00] -> [01] -> [02]
'd0 -> [10] -> [11] -> [12]
'd0 -> [20] -> [21] -> [22]
因此，同一行 MAC_PE 的累加结果最后都会集中在行内最后一个 MAC_PE 上
最后对每行最后一个 MAC_PE 进行累加，即可得到所以 3 * 3 的 MAC_PE 输出的累加总和

对于 feature_in 的输入
feature_in = {feature2, feature1, feature0} 一次输入 3 个 feature，分配给同一列上的 3 个 MAC_PE
共输入 3 次 feature_in，完成 3 * 3 的 MAC_PE 计算
*/
genvar i, j;
generate
    for (i = 0; i < PE_NUM_PRE_CORE; i=i+1) begin : PE_array_line_gen
        for (j = 0; j < PE_NUM_PRE_CORE; j=j+1) begin : PE_array_col_gen
            localparam index = i*PE_NUM_PRE_CORE + j;
            if (i == 0 && j == 0) begin : first_PE // first PE's bias connect with bias input
                MAC_PE u_MAC_PE(
                    .DSP_clk    ( DSP_clk                                          ),
                    .rst_n      ( rst_n                                            ),
                    .pulse      ( pulse                                            ),
                    .w          ( weight_array[index]                              ),
                    .x          ( feature_in[(i+1)*FEATURE_WIDTH-1:i*FEATURE_WIDTH]),
                    .b          ( 36'd0                                            ),
                    .PCIN       ( 48'd0                                            ), // 第一列的 MAC_PE ,其 PCIN 都为 0 
                    .out        ( output_array[index]                              ),
                    .PCOUT      ( PCOUT[index]                                     )
                );
            end
            else if (i == 1 && j == 0)begin
                MAC_PE u_MAC_PE(
                    .DSP_clk    ( DSP_clk                                          ),
                    .rst_n      ( rst_n                                            ),
                    .pulse      ( pulse                                            ),
                    .w          ( weight_array[index]                              ),
                    .x          ( feature_in[(i+1)*FEATURE_WIDTH-1:i*FEATURE_WIDTH]),
                    .b          ( 36'd0                                            ),
                    .PCIN       ( 48'd0                                            ), // 第一列的 MAC_PE ,其 PCIN 都为 0 
                    .out        ( output_array[index]                              ),
                    .PCOUT      ( PCOUT[index]                                     )
                );
            end
            else if (i == 2 && j == 0)begin
                MAC_PE u_MAC_PE(
                    .DSP_clk    ( DSP_clk                                          ),
                    .rst_n      ( rst_n                                            ),
                    .pulse      ( pulse                                            ),
                    .w          ( weight_array[index]                              ),
                    .x          ( feature_in[(i+1)*FEATURE_WIDTH-1:i*FEATURE_WIDTH]),
                    .b          ( 36'd0                                            ),
                    .PCIN       ( 48'd0                                            ), // 第一列的 MAC_PE ,其 PCIN 都为 0 
                    .out        ( output_array[index]                              ),
                    .PCOUT      ( PCOUT[index]                                     )
                );
            end
            else begin : other_PE // other PEs' bias connect with previous PE's output
                MAC_PE u_MAC_PE(
                    .DSP_clk    ( DSP_clk                                          ),
                    .rst_n      ( rst_n                                            ),
                    .pulse      ( pulse                                            ),
                    .w          ( weight_array[index]                              ),
                    .x          ( feature_in[(i+1)*FEATURE_WIDTH-1:i*FEATURE_WIDTH]),
                    .b          ( 36'd0                                            ),
                    .PCIN       ( PCOUT[index-1]                                   ), // 第二、三列的 MAC_PE，其 PCIN 为前一个 MAC_PE 的 PCOUT
                    .out        ( output_array[index]                              ),
                    .PCOUT      ( PCOUT[index]                                     )
                );
            end
        end
    end
endgenerate

// 需要打两拍，因为要等前面两列的 PCOUT 累加到最后一列
// PCOUT 和 out 输出的内容其实是一样的
always @(posedge DSP_clk) begin
    flow_reg1[0] <= output_array[2];
    flow_reg1[1] <= output_array[5];
    flow_reg1[2] <= output_array[8];

    flow_reg2[0] <= flow_reg1[0];
    flow_reg2[1] <= flow_reg1[1];
    flow_reg2[2] <= flow_reg1[2];
end

// 树形加法
/*
flow_reg2[0]   flow_reg2[1]   flow_reg2[2]   bias_add
    \               /             \               /   
     \             /               \             /    
      \           /                 \           /     
         adder1                         adder2
            \                             /     
             \                           /      
              \                         /    
                         adder3    
*/
always @(posedge DSP_clk) begin
    adder1 <= $signed(flow_reg2[0] + flow_reg2[1]);
    adder2 <= $signed(flow_reg2[2] + bias_add);
    adder3 <= $signed(adder1 + adder2);
end

assign feature_out = adder3;

endmodule