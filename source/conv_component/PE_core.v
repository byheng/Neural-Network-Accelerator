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
    parameter PE_NUM_PRE_CORE     = `PE_NUM_PRE_CORE,
    parameter PE_ARRAY_TOTAL_SIZE = PE_NUM_PRE_CORE * PE_NUM_PRE_CORE,
    parameter BIAS_WIDTH          = WEIGHT_WIDTH + FEATURE_WIDTH
)
(
    input                                       DSP_clk,
    input                                       rst_n, 
    input [WEIGHT_WIDTH-1:0]                    weight,
    input                                       weight_valid,      
    input [FEATURE_WIDTH*PE_NUM_PRE_CORE-1:0]   feature_in,      
    input [BIAS_WIDTH-1:0]                      bias,
    input                                       bias_valid, 
    input [MAC_OUTPUT_WIDTH-1:0]                adder_feature, 
    input                                       bias_or_adder_feature,      
    input                                       pulse,           
    output[MAC_OUTPUT_WIDTH-1:0]                feature_out
);

/*----------------- 缓存weight -----------------*/
reg [WEIGHT_WIDTH-1:0]   weight_array [PE_ARRAY_TOTAL_SIZE-1:0];
reg [BIAS_WIDTH-1:0]     bias_reg;
always @(posedge DSP_clk or negedge rst_n) begin
    if (weight_valid) begin
        weight_array[PE_ARRAY_TOTAL_SIZE-1] <= weight;
    end

    if (bias_valid) begin
        bias_reg <= bias;
    end
end

genvar p;
generate
    for (p = 0; p < PE_ARRAY_TOTAL_SIZE-1; p=p+1) begin : weight_array_gen
        always @(posedge DSP_clk or negedge rst_n) begin
            if (weight_valid) begin
                weight_array[p] <= weight_array[p+1];
            end
        end
    end
endgenerate

wire [MAC_OUTPUT_WIDTH-1:0]                 bias_add;   
assign bias_add = bias_or_adder_feature? {{`MAC_OVERFLOW_WIDTH{bias_reg[BIAS_WIDTH-1]}}, bias_reg} : adder_feature;


/*----------------- PE array ---------------------*/
wire [MAC_OUTPUT_WIDTH-1:0] output_array [PE_ARRAY_TOTAL_SIZE-1:0];
wire [47:0]                 PCOUT [PE_ARRAY_TOTAL_SIZE-1:0];
reg  [MAC_OUTPUT_WIDTH-1:0] flow_reg1[2:0], flow_reg2[2:0], flow_reg3[2:0];
reg  [MAC_OUTPUT_WIDTH-1:0] adder1, adder2, adder3;

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
                    .PCIN       ( 48'd0                                            ), 
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
                    .PCIN       ( 48'd0                                            ), 
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
                    .PCIN       ( 48'd0                                            ), 
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
                    .PCIN       ( PCOUT[index-1]                                   ), 
                    .out        ( output_array[index]                              ),
                    .PCOUT      ( PCOUT[index]                                     )
                );
            end
        end
    end
endgenerate

always @(posedge DSP_clk or negedge rst_n) begin
    flow_reg1[0] <= output_array[2];
    flow_reg1[1] <= output_array[5];
    flow_reg1[2] <= output_array[8];

    flow_reg2[0] <= flow_reg1[0];
    flow_reg2[1] <= flow_reg1[1];
    flow_reg2[2] <= flow_reg1[2];

    // flow_reg3[0] <= flow_reg2[0];
    // flow_reg3[1] <= flow_reg2[1];
    // flow_reg3[2] <= flow_reg2[2];
end

always @(posedge DSP_clk or negedge rst_n) begin
    adder1 <= $signed(flow_reg2[0] + flow_reg2[1]);
    adder2 <= $signed(flow_reg2[2] + bias_add);
    adder3 <= $signed(adder1 + adder2);
end

assign feature_out = adder3;

endmodule