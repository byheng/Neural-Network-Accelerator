/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../../parameters.v"

module pool_layer(
    input         DSP_clk,
    input         rst_n, 
    input [7:0]   feature,      
    input         pulse,
    output[7:0]   feature_out,
    input [9:0]   col_size,
    input         ram_rst
);

wire [7:0]  pool_out[24:0];
wire [7:0]  pool_in [24:0];

genvar i, j;
generate
    for (i = 0; i < 5; i=i+1) begin : Pool_array_line_gen
        for (j = 0; j < 5; j=j+1) begin : Pool_array_col_gen
            localparam index = i*5 + j;
            if (i == 0 && j == 0) begin : Pool_array_first_PE
                assign pool_in[index] = 0;
                pool_PE u_pool_PE(
                    .DSP_clk    ( DSP_clk        ),
                    .rst_n      ( rst_n          ),
                    .pulse      ( pulse          ),
                    .x1_        ( feature        ),
                    .x2_        ( pool_in[index] ),
                    .out        ( pool_out[index])
                );
            end
            else if (j == 0)begin : Pool_array_first_row_PE
                pool_PE u_pool_PE(
                    .DSP_clk    ( DSP_clk        ),
                    .rst_n      ( rst_n          ),
                    .pulse      ( pulse          ),
                    .x1_         ( feature        ),
                    .x2_        ( pool_in[index] ),
                    .out        ( pool_out[index])
                );
            end
            else begin : Pool_array_other_PE
                assign pool_in[index] = pool_out[index-1];
                pool_PE u_pool_PE(
                    .DSP_clk    ( DSP_clk        ),
                    .rst_n      ( rst_n          ),
                    .pulse      ( pulse          ),
                    .x1_         ( feature        ),
                    .x2_        ( pool_in[index] ),
                    .out        ( pool_out[index])
                );
            end
        end
    end
endgenerate

wire [31:0] write_data, read_data;
assign write_data = {pool_out[4], pool_out[9], pool_out[14], pool_out[19]};
assign {pool_in[5], pool_in[10], pool_in[15], pool_in[20]} = read_data;

wire [9:0]  col_size_to_PE_core;
assign col_size_to_PE_core = col_size - 3; // col_size + padding - kernel_size - 2

ram_base_shift_register_pool ram_base_shift_register_pool_inst(
    .system_clk ( DSP_clk               ),
    .rst_n      ( rst_n                 ),
    .wr_en      ( pulse                 ),
    .wr_data    ( write_data            ),
    .rd_data    ( read_data             ),
    .col_size   ( col_size_to_PE_core   ),
    .ram_rst    ( ram_rst               )
);

assign feature_out = pool_out[24];

endmodule