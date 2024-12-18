/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module return_data_arbitra #(
    parameter FEATURE_WIDTH = `FEATURE_WIDTH
)
(
    input                               system_clk   ,
    input                               rst_n        ,
    // select signal        
    input [3:0]                         select       ,
    // data1    
    input[FEATURE_WIDTH*8-1:0]          data1        ,
    input                               data1_valid  ,
    // data2   
    input[FEATURE_WIDTH*8-1:0]          data2        ,
    input                               data2_valid  ,
    // data3   
    input[FEATURE_WIDTH*8-1:0]          data3        ,
    input                               data3_valid  ,
    // data4   
    input[FEATURE_WIDTH*8-1:0]          data4        ,
    input                               data4_valid  ,
    // output to return module 
    output reg[FEATURE_WIDTH*8-1:0]     return_data  ,
    output reg                          return_data_valid
);

always @(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        return_data_valid <= 0;
        return_data <= 0;
    end
    else if (select[0]) begin
        return_data_valid <= data1_valid;
        return_data <= data1;
    end
    else if (select[1]) begin
        return_data_valid <= data2_valid;
        return_data <= data2;
    end
    else if (select[2]) begin
        return_data_valid <= data3_valid;
        return_data <= data3;
    end
    else if (select[3]) begin
        return_data_valid <= data4_valid;
        return_data <= data4;
    end
    else begin
        return_data_valid <= 0;
        return_data <= 0;
    end
end

endmodule