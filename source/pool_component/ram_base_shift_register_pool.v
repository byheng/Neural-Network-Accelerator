/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../../parameters.v"

module ram_base_shift_register_pool
(
    input           system_clk,
    input           rst_n,
    input           wr_en,
    input  [31:0]   wr_data,
    output [31:0]   rd_data,
    input  [9:0]    col_size,
    input           ram_rst
);

reg [7:0]   wr_addr;
reg [7:0]   rd_addr;
wire        ram_rst_tt;

assign ram_rst_tt = ram_rst & (~rst_n);

always @(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        wr_addr <= 8'd0;
        rd_addr <= 8'd0;
    end 
    else if(wr_en) begin
        wr_addr <= wr_addr + 8'd1;
        rd_addr <= wr_addr - col_size;
    end
end

generate
    if (`device == "simulation") begin
        simulation_ram#(
            .DATA_W    ( 32 ),
            .DATA_R    ( 32 ),
            .DEPTH_W   ( 8  ),
            .DEPTH_R   ( 8  )
        )shift_register_ram_small(
            .clk       ( system_clk),
            .i_wren    ( wr_en     ),
            .i_waddr   ( wr_addr   ),
            .i_wdata   ( wr_data   ),
            .i_raddr   ( rd_addr   ),
            .o_rdata   ( rd_data   )
        );
    end
    else begin
        shift_register_ram_small shift_register_ram_small_inst (
            .wr_data        (wr_data),   
            .wr_addr        (wr_addr),   
            .wr_en          (wr_en),     
            .wr_clk         (system_clk),    
            .wr_rst         (ram_rst_tt),    
            .rd_addr        (rd_addr),   
            .rd_data        (rd_data),   
            .rd_clk         (system_clk),    
            .rd_rst         (ram_rst_tt)     
        );
    end
endgenerate


endmodule 