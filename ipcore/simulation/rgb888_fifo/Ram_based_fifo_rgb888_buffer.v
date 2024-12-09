/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../source/parameters.v"

module ram_based_fifo_rgb888_buffer #(
    parameter DATA_W  = 128,    
    parameter DEPTH_W = 8,    
    parameter DATA_R  = 128,  
    parameter DEPTH_R = 8,
    parameter WRITE_NUM = 2 ** DEPTH_W,
    parameter READ_NUM = 2 ** DEPTH_R,
    parameter ALMOST_FULL_THRESHOLD = 127,
    parameter ALMOST_EMPTY_THRESHOLD = 64
)
(                  	
    input                   system_clk       ,       
    input                   rst_n            ,                                            
    input                   i_wren           ,        // Write Enable
    input  [DATA_W - 1 : 0] i_wrdata         ,        // Write-data                    
    output                  o_full           ,        // Full signal
    output                  o_almost_full    ,        // Almost full signal
    input                   i_rden           ,        // Read Enable
    output [DATA_R - 1 : 0] o_rddata         ,        // Read-data                    
    output                  o_empty          ,        // Empty signal
    output                  o_almost_empty            // Almost empty signal
);


/*---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   Internal Registers / Signals
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
reg  [DEPTH_W - 1 : 0] wrptr_rg  ; // Write pointer
reg  [DEPTH_R - 1 : 0] rdptr_rg  ; // Read pointer
wire [DEPTH_R - 1 : 0] now_data_num; // Number of data in FIFO
wire [DEPTH_R - 1 : 0] nxt_rdptr ; // Next Read pointer
wire [DEPTH_R - 1 : 0] rdaddr    ; // Read-address to RAM
 
wire wren            ;        // Write Enable signal generated iff FIFO is not full
wire rden            ;        // Read Enable signal generated iff FIFO is not empty
wire full            ;        // Full signal
wire empty           ;        // Empty signal
reg  empty_rg        ;        // Empty signal (registered)
reg  state_rg        ;        // State
reg  ex_rg           ;        // Exception


/*---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   Instantiation of RAM
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
generate
    if (`device == "simulation") begin : simulation_ram_inst
        simulation_ram#(
            .DATA_W    ( 128 ),
            .DATA_R    ( 128 ),
            .DEPTH_W   ( 8   ),
            .DEPTH_R   ( 8   )
        )return_ram_inst(
            .clk       ( system_clk),
            .i_wren    ( wren      ),
            .i_waddr   ( wrptr_rg  ),
            .i_wdata   ( i_wrdata  ),
            .i_raddr   ( rdaddr    ),
            .o_rdata   ( o_rddata  )
        );
    end
    else begin 
        simulation_ram#(
            .DATA_W    ( 128 ),
            .DATA_R    ( 128 ),
            .DEPTH_W   ( 8   ),
            .DEPTH_R   ( 8   )
        )return_ram_inst(
            .clk       ( system_clk),
            .i_wren    ( wren      ),
            .i_waddr   ( wrptr_rg  ),
            .i_wdata   ( i_wrdata  ),
            .i_raddr   ( rdaddr    ),
            .o_rdata   ( o_rddata  )
        );
    end
endgenerate

/*---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   Synchronous logic to write to and read from FIFO
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
always @ (posedge system_clk or negedge rst_n) begin
    if (!rst_n) begin            
       wrptr_rg  <= 0    ;
       rdptr_rg  <= 0    ; 
       state_rg  <= 1'b0 ;
       ex_rg     <= 1'b0 ;
    end
    else begin   
        /* FIFO write logic */            
        if (wren) begin         
            if (wrptr_rg == WRITE_NUM - 1) begin
                wrptr_rg <= 0               ;        // Reset write pointer  
            end
            else begin
                wrptr_rg <= wrptr_rg + 1    ;        // Increment write pointer            
            end
        end

        /* FIFO read logic */
        if (rden) begin         
            if (rdptr_rg == READ_NUM - 1) begin
               rdptr_rg <= 0               ;        // Reset read pointer
            end
            else begin
               rdptr_rg <= rdptr_rg + 1    ;        // Increment read pointer            
            end
        end
      
        // State where FIFO is emptied
        if (state_rg == 1'b0) begin
            ex_rg <= 1'b0 ;

            if (wren && !rden) begin
                state_rg <= 1'b1 ;                        
            end 
            else if (wren && rden && (rdaddr == wrptr_rg)) begin
                ex_rg    <= 1'b1 ;        // Exceptional case where same address is being read and written in FIFO ram
            end
        end
      
        // State where FIFO is filled up
        else begin
            if (!wren && rden) begin
               state_rg <= 1'b0 ;            
            end
        end

        // Empty signal registered
        empty_rg <= empty ;      
    end
end


/*---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   Continuous Assignments
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
// Full and Empty internal
assign full      = (wrptr_rg == rdptr_rg) && (state_rg == 1'b1)            ;
assign empty     = ((wrptr_rg == rdptr_rg) && (state_rg == 1'b0)) || ex_rg ;

// Write and Read Enables internal
assign wren      = i_wren & !full                                          ;  
assign rden      = i_rden & !empty & !empty_rg                             ;

// Full and Empty to output
assign o_full      = full                                                  ;
assign o_empty     = empty || empty_rg                                     ;

// Read-address to RAM
assign nxt_rdptr   = (rdptr_rg == READ_NUM - 1) ? 'b0 : rdptr_rg + 1        ;
assign rdaddr      = rden ? nxt_rdptr : rdptr_rg                           ;

// almost_full and almost_empty
assign now_data_num = wrptr_rg - rdptr_rg;
assign o_almost_full  = now_data_num >= ALMOST_FULL_THRESHOLD;
assign o_almost_empty = now_data_num < ALMOST_EMPTY_THRESHOLD;

endmodule

/*=================================================================================================================================================================================
                                                                                 R A M   F I F O
=================================================================================================================================================================================*/