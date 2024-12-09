/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module act_feature_arbitra #(
    parameter MAC_OUTPUT_WIDTH = `MAC_OUTPUT_WIDTH
)
(
    input                               system_clk   ,
    input                               rst_n        ,
    // refresh buffer       
    input                               direct_out   ,
    // data from output buffer  
    input[MAC_OUTPUT_WIDTH*8-1:0]       data_from_output_buffer ,
    input                               data_from_output_buffer_valid,
    // data from conv core  
    input[MAC_OUTPUT_WIDTH*8-1:0]       data_from_conv_core ,
    input                               data_from_conv_core_valid,
    // output to activate function
    output reg[MAC_OUTPUT_WIDTH*8-1:0]  data_to_act_func,
    output reg                          data_to_act_func_valid
);

always @(posedge system_clk or negedge rst_n) begin
    if (direct_out) begin
        data_to_act_func <= data_from_conv_core;
        data_to_act_func_valid <= data_from_conv_core_valid;
    end
    else begin
        data_to_act_func <= data_from_output_buffer;
        data_to_act_func_valid <= data_from_output_buffer_valid;
    end
end

endmodule