/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
    Todo: total_rebuild
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module Weight_buffer #(
    parameter WEIGHT_WIDTH      = `WEIGHT_WIDTH,
    parameter PE_CORE_NUM       = `PE_CORE_NUM,
    parameter MEM_DATA_WIDTH    = `MEM_DATA_WIDTH,
    parameter WEIGHT_DATA_WIDTH = `PE_CORE_NUM * WEIGHT_WIDTH
)
(
    input                           system_clk             ,
    input                           rst_n                  ,
    // data path       
    input [MEM_DATA_WIDTH-1:0]      weight_and_bias_data   ,
    input                           weight_and_bias_valid  ,
    (* keep = "true" *)output                          weight_buffer_ready    ,
    // output data path  
    output                          weight_and_bias_ready  ,
    input  [1:0]                    change_weight_bias     ,  // 00: no change, 01: change weight, 10: change bias, 11: change weight and bias
    output[WEIGHT_DATA_WIDTH-1:0]   weight_bias_output_data,
    output reg[8:0]                 weight_bias_output_valid,  // 独热码，8赋给权重，1赋值给偏置  
    input                           task_finish
);
// local parameter
localparam [1:0] IDLE = 2'b00, CHANGE_WEIGHT=2'b01, CHANGE_BIAS=2'b10, CHANGE_WEIGHT_AND_BIAS=2'b11;
parameter WEIGHT_CNT = 0; //12586

// variables declaration
(* keep = "true" *)reg [1:0]                   state;
reg [3:0]                   cnt2;
wire                        weight_buffer_almost_full;
(* keep = "true" *)wire                        weight_buffer_empty;
wire                        weight_buffer_rd_en;
wire[MEM_DATA_WIDTH-1:0]    fifo_in_data;
reg [8:0]                   weight_bias_output_addr;
wire                        weight_rst;
// for debug
// reg [31:0] debug_weight_cnt;
// reg        debug_weight_en;
// reg        debug_weight_ready;

generate
    // because the xilinx fifo is big-endian, we need to swap the data when using xilinx device
    if (`device == "xilinx") begin
        assign fifo_in_data = {weight_and_bias_data[255:0], weight_and_bias_data[511:256]};
    end
    else if (`device == "simulation") begin
        assign fifo_in_data = weight_and_bias_data;
    end
endgenerate

assign weight_rst = (~rst_n) | task_finish;

generate
    if (`device == "xilinx") begin
        weight_and_bias_buffer_fifo weight_and_bias_buffer_fifo_inst (
            .clk               (system_clk),
            .srst              (weight_rst),
            .din               (fifo_in_data),
            .wr_en             (weight_and_bias_valid),
            .rd_en             (weight_buffer_rd_en),
            .dout              (weight_bias_output_data),
            .full              (),
            .almost_full       (),
            .empty             (weight_buffer_empty),
            .wr_rst_busy       (),
            .rd_rst_busy       (),
            .prog_full         (weight_buffer_almost_full)
        );
    end
    else if (`device == "simulation") begin
        // ram_based_fifo #(
        //     .DATA_W                  	( 512      ),
        //     .DEPTH_W                 	( 9        ),
        //     .DATA_R                  	( 256      ),
        //     .DEPTH_R                 	( 10       ),
        //     .ALMOST_FULL_THRESHOLD   	( 256      ),
        //     .ALMOST_EMPTY_THRESHOLD  	( 2        ),
        //     .FIRST_WORD_FALL_THROUGH 	( 0        )
        // )
        // u_ram_based_fifo(
        //     .system_clk     	( system_clk                ),
        //     .rst_n          	( ~weight_rst               ),
        //     .i_wren         	( weight_and_bias_valid     ),
        //     .i_wrdata       	( fifo_in_data              ),
        //     .o_full         	(                           ),
        //     .o_almost_full  	( weight_buffer_almost_full ),
        //     .i_rden         	( weight_buffer_rd_en       ),
        //     .o_rddata       	( weight_bias_output_data   ),
        //     .o_empty        	( weight_buffer_empty       ),
        //     .o_almost_empty 	(                           )  
        // );
        sync_fifo #(
            .INPUT_WIDTH       	( 512       ),
            .OUTPUT_WIDTH      	( 256       ),
            .WR_DEPTH          	( 2**9      ),
            .RD_DEPTH          	( 2**10     ),
            .MODE              	( "Standard"),
            .DIRECTION         	( "LSB"     ),
            .ECC_MODE          	( "no_ecc"  ),
            .PROG_EMPTY_THRESH 	( 2         ),
            .PROG_FULL_THRESH  	( 256       ))
        u_sync_fifo(
            .clock         	( system_clk                ),
            .reset         	( weight_rst                ),
            .wr_en         	( weight_and_bias_valid     ),
            .din           	( fifo_in_data              ),
            .rd_en         	( weight_buffer_rd_en       ),
            .dout          	( weight_bias_output_data   ),
            .empty         	( weight_buffer_empty       ),
            .prog_full     	( weight_buffer_almost_full ),
            .prog_empty    	(                           )    
        );
    end
endgenerate


assign weight_buffer_ready = ~weight_buffer_almost_full;

// for debug
// always @(posedge system_clk or negedge rst_n) begin
//     if(~rst_n) begin
//         debug_weight_cnt <= 0;
//         debug_weight_en <= 0;
//         debug_weight_ready <= 0;
//     end
//     else if (weight_buffer_rd_en) begin
//         debug_weight_cnt <= debug_weight_cnt + 1;
//         debug_weight_en <= 0;
//     end
//     else if (debug_weight_cnt >= WEIGHT_CNT) begin
//         debug_weight_en <= 0;
//         debug_weight_ready <= 1;
//     end
//     else if (~weight_buffer_empty & debug_weight_en == 0) begin
//         debug_weight_en <= 1;
//         debug_weight_cnt <= debug_weight_cnt + 1;
//     end
//     else begin
//         debug_weight_en <= 0;
//         debug_weight_cnt <= debug_weight_cnt;
//     end
// end

// 更新权重或偏置
always @(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        state <= IDLE;
        weight_bias_output_addr <= 9'b0;
        cnt2 <= 0;
    end
    else begin
        case(state)
            IDLE: begin
                state <= change_weight_bias; 
                if (change_weight_bias == 2'b10) begin
                    weight_bias_output_addr[8] <= 1;
                end
                else if (change_weight_bias == 2'b00) begin
                    weight_bias_output_addr <= 0;
                end
                else begin
                    weight_bias_output_addr <= 9'd1;
                end
                cnt2 <= 0;
            end

            CHANGE_WEIGHT: begin
                if (weight_buffer_rd_en) begin
                    if (cnt2 == 4'd8) begin
                        if (weight_bias_output_addr == 9'b010000000) begin
                            state <= IDLE;
                            weight_bias_output_addr <= 0;
                        end
                        else begin
                            weight_bias_output_addr <= weight_bias_output_addr << 1;
                        end
                        cnt2 <= 0;
                    end
                    else begin
                        cnt2 <= cnt2 + 1;
                    end
                end
            end
            
            CHANGE_WEIGHT_AND_BIAS: begin
                if (weight_buffer_rd_en) begin
                    if (weight_bias_output_addr[8] == 1) begin
                        state <= IDLE;
                        weight_bias_output_addr <= 0;
                    end
                    else if (cnt2 == 4'd8) begin
                        weight_bias_output_addr <= weight_bias_output_addr << 1;
                        cnt2 <= 0;
                    end
                    else begin
                        cnt2 <= cnt2 + 1;
                    end
                end
            end

            CHANGE_BIAS: begin
                if (weight_buffer_rd_en) begin
                    state <= IDLE;
                    weight_bias_output_addr <= 0;
                end
            end
        endcase
    end
end

assign weight_buffer_rd_en   = (|weight_bias_output_addr) & ~weight_buffer_empty;

assign weight_and_bias_ready = (state == IDLE) & (change_weight_bias == 2'b00);

always @(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        weight_bias_output_valid <= 9'b0;
    end
    else begin
        weight_bias_output_valid <= weight_bias_output_addr & {9{weight_buffer_rd_en}};
    end
end

endmodule