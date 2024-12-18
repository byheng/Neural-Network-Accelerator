/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module upsample #(
    parameter FEATURE_WIDTH = `FEATURE_WIDTH,
    parameter PE_ARRAY_SIZE = `PE_ARRAY_SIZE,
    parameter FEATURE_TOTAL_WIDTH = FEATURE_WIDTH*PE_ARRAY_SIZE
)(
    input                           system_clk,
    input                           rst_n,
    input [FEATURE_TOTAL_WIDTH-1:0] feature,
    input                           feature_valid,
    output                          feature_ready,
    input [9:0]                     col_size,
    input [9:0]                     row_size,
    output[FEATURE_TOTAL_WIDTH-1:0] unsample_feature,
    output reg                      unsample_feature_valid,
    input                           output_ready,
    output                          upsample_buffer_empty
);

wire          o_almost_full;
wire          o_empty;
wire          o_almost_empty;
reg           change_point;
reg  [10:0]   cnt;
reg  [10:0]   double_col_size;
wire          ready_for_output;

assign feature_ready = ~o_almost_full;
assign upsample_buffer_empty = o_empty;

always @(posedge system_clk or negedge rst_n) begin
    if (!rst_n) begin
        double_col_size <= 0;
    end
    else begin
        double_col_size <= col_size << 1;
    end
end

ram_based_upsample_fifo ram_based_upsample_fifo_inst(                  	
    .system_clk             ( system_clk             ),       
    .rst_n                  ( rst_n                  ),                                            
    .i_wren                 ( feature_valid          ),     
    .i_wrdata               ( {feature, feature}     ),              
    .o_full                 (                        ),     
    .o_almost_full          ( o_almost_full          ),     
    .i_rden                 ( unsample_feature_valid ),     
    .o_rddata               ( unsample_feature       ),             
    .o_empty                ( o_empty                ),     
    .o_almost_empty         ( o_almost_empty         ),     
    .change_point           ( change_point           ),
    .almost_empty_threshold ( double_col_size        ),
    .ready_for_output       ( ready_for_output       )
);

always @(posedge system_clk or negedge rst_n) begin
    if (!rst_n) begin
        unsample_feature_valid <= 0;
        change_point <= 0;
        cnt <= 0;
    end 
    else if (!ready_for_output & output_ready & ~o_empty) begin
        if (cnt == (double_col_size - 1)) begin
            change_point <= 1'b1;
        end
        else begin
            change_point <= 1'b0;
        end

        if (change_point) begin
            unsample_feature_valid <= 0;
            cnt <= cnt;
        end
        else if (cnt == (double_col_size - 1)) begin
            unsample_feature_valid <= 1;
            cnt <= 0;
        end
        else begin
            unsample_feature_valid <= 1;
            cnt <= cnt + 1;
        end
    end
    else begin
        change_point <= 1'b0;
        unsample_feature_valid <= 0;
    end
end

reg [9:0]   row_cnt;
always @(posedge system_clk or negedge rst_n) begin
    if (!rst_n) begin
        row_cnt <= 0;
    end
    else if (change_point) begin
        if (row_cnt == ((row_size<<1) - 1)) begin
            row_cnt <= 0;
        end
        else begin
            row_cnt <= row_cnt + 1;
        end
    end
    else begin
        row_cnt <= row_cnt;
    end
end

endmodule