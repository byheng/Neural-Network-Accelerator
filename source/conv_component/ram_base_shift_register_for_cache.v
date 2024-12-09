/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
    model_intro : <make a shift register for convolution base on ram
                    the shift work is : row_size + 2>
    state       : simulation finish! It works well!
                  LION WORK FINISH
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module ram_base_shift_register_for_cache #(
    parameter FEATURE_WIDTH  = `FEATURE_WIDTH
)
(
    input                        system_clk,
    input                        rst_n,
    input                        wr_en,
    input  [FEATURE_WIDTH*2-1:0] wr_data,
    output [FEATURE_WIDTH*2-1:0] rd_data,
    input  [9:0]                 shift_size
);

reg [9:0]   wr_addr;
reg [9:0]   rd_addr;

always @(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        wr_addr <= 10'd0;
        rd_addr <= 10'd0;
    end 
    else if(wr_en) begin
        wr_addr <= wr_addr + 10'd1;
        rd_addr <= wr_addr - shift_size;
    end
end

shift_register_ram shift_register_ram_inst (
    .clka       (system_clk),
    .ena        (1'b1      ),
    .wea        (wr_en     ),
    .addra      (wr_addr   ),
    .dina       (wr_data   ),
    .clkb       (system_clk),
    .enb        (1'b1      ),
    .addrb      (rd_addr   ),
    .doutb      (rd_data   )
);

endmodule 