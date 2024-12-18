/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module simulation_row_cache ();

reg system_clk, rst_n;
initial begin
    system_clk = 1;
    forever #5 system_clk = ~system_clk;
end
initial begin
    rst_n = 0;
    #10 rst_n = 1;
end 

reg [15:0] feature;
reg        feature_valid;
reg        stop;

initial begin
    stop <= 0;
    #3000 stop <= 1;
    #200 stop <= 0;
end

always @(posedge system_clk or negedge rst_n) begin
    if (~rst_n) begin
        feature <= 0;
        feature_valid <= 0;
    end
    else if (feature < 16'd20) begin
        if (stop) begin
            feature_valid <= 0;
            feature <= feature;
        end
        else begin
            feature_valid <= 1;
            feature <= feature + 1;
        end
    end
    else begin
        feature <= 1;
        feature_valid <= 1;
    end
end

feature_row_Cache u_feature_row_Cache(
	.system_clk           	( system_clk            ),
	.rst_n                	( rst_n                 ),
	.feature_output_data  	( {{240{1'b0}}, feature}         ),
	.feature_output_valid 	( feature_valid         ),
	.feature_cache_data   	(     ),
	.feature_cache_valid  	(    ),
	.rebuild_structure    	( 1'b1     ),
	.col_size             	( 10'd18               )
);


endmodule