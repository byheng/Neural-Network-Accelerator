/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module ram_based_fifo_tb #(    
    parameter DATA_W  = 16,    
    parameter DEPTH_W = 11,    
    parameter DATA_R  = 64,  
    parameter DEPTH_R = 9
);

reg clk, rst_n;
reg [DATA_W-1:0] data_in;
wire [DATA_R-1:0] data_out;
wire empty, almost_empty, full, almost_full;
reg wen, ren;

ram_based_fifo #(
	.DATA_W                 	( DATA_W   ),
	.DEPTH_W                	( DEPTH_W  ),
	.DATA_R                 	( DATA_R   ),
	.DEPTH_R                	( DEPTH_R  ),
	.ALMOST_FULL_THRESHOLD  	( 256      ),
	.ALMOST_EMPTY_THRESHOLD 	( 2        ),
    .FIRST_WORD_FALL_THROUGH	( 0        )
)
u_ram_based_fifo(
	.system_clk     	( clk             ),
	.rst_n          	( rst_n           ),
	.i_wren         	( wen             ),
	.i_wrdata       	( data_in         ),
	.o_full         	( full            ),
	.o_almost_full  	( almost_full     ),
	.i_rden         	( ren             ),
	.o_rddata       	( data_out        ),
	.o_empty        	( empty           ),
	.o_almost_empty 	( almost_empty    )
);

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        wen <= 0;
        data_in <= 0;
    end
    else begin
        if (!full) begin
            wen <= 1;
            data_in <= data_in + 1;
        end
        else begin
            wen <= 0;
        end
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        ren <= 0;
    end
    else begin
        if (!almost_empty) begin
            ren <= 1;
        end
        else begin
            ren <= 0;
        end
    end
end

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 0;
    #10 rst_n = 1;
end

endmodule
