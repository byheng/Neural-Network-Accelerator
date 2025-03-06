/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module ram_based_fifo #(
    parameter DATA_W  = 64,    
    parameter DEPTH_W = 9,    
    parameter DATA_R  = 16,  
    parameter DEPTH_R = 11,
    parameter DIFF_BIT = (DEPTH_R - DEPTH_W) < 0 ? (DEPTH_W - DEPTH_R) : (DEPTH_R - DEPTH_W),
    parameter BIGGER_PORT = (DATA_W > DATA_R) ? DATA_W : DATA_R,
    parameter WRITE_NUM = 2 ** DEPTH_W,
    parameter READ_NUM = 2 ** DEPTH_R,
    parameter ALMOST_FULL_THRESHOLD = 256,
    parameter ALMOST_EMPTY_THRESHOLD = 2,
    parameter FIRST_WORD_FALL_THROUGH = 0
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

/* ---------------- CHECKING BITWIDTH -----------------*/
initial begin
    if (DATA_W * WRITE_NUM != DATA_R * READ_NUM) begin
        $display("Error: Write port memory should be equal to read port memory, got write port memory is %d, and read port memory is %d.", DATA_W * DEPTH_W, DATA_R * DEPTH_R);
        $finish;
    end
end

/*---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   Internal Registers / Signals
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
reg  [DEPTH_W - 1 : 0]      wrptr_rg  ;     // Write pointer
reg  [DEPTH_R - 1 : 0]      rdptr_rg  ;     // Read pointer
wire [BIGGER_PORT - 1 : 0]  now_data_num;   // Number of data in FIFO
wire [DEPTH_R - 1 : 0]      nxt_rdptr ;     // Next Read pointer
wire [DEPTH_R - 1 : 0]      rdaddr    ;     // Read-address to RAM
wire [DATA_R-1:0]           rdata_wire;
reg  [DATA_R-1:0]           rdata_reg ;
 
wire wren            ;        // Write Enable signal generated iff FIFO is not full
reg  wren_rg         ;        // Write or read Enable signal registered
wire cross_psd       ;        // Write and read Enable signal crossing the pipeline
wire ren_with_cross  ;
wire wen_with_cross  ;
wire rd_pass_wr      ;
wire rd_pass_wr_nxt  ;
wire rden            ;        // Read Enable signal generated iff FIFO is not empty
wire full            ;        // Full signal
wire empty           ;        // Empty signal
reg  empty_rg        ;        // Empty signal (registered)
reg  state_rg        ;        // State
reg  ex_rg           ;        // Exception


/*---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   Instantiation of RAM
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
simulation_ram#(
    .DATA_W    ( DATA_W  ),
    .DATA_R    ( DATA_R  ),
    .DEPTH_W   ( DEPTH_W ),
    .DEPTH_R   ( DEPTH_R )
)return_ram_inst(
    .w_clk     ( system_clk  ),
    .i_wren    ( wren        ),
    .i_waddr   ( wrptr_rg    ),
    .i_wdata   ( i_wrdata    ),
    .r_clk     ( system_clk  ),
    .i_raddr   ( rdaddr      ),
    .o_rdata   ( rdata_wire  )
);

generate
    if (DATA_W > DATA_R) begin : Write_cross_to_Read
        always @ (posedge system_clk or negedge rst_n) begin
            if (!rst_n) begin
                wren_rg <= 1'b0;
            end
            else begin
                wren_rg <= rdptr_rg[DIFF_BIT];
            end
        end
        assign cross_psd = wren_rg ^ rdptr_rg[DIFF_BIT];
        assign wen_with_cross = wren;
        assign ren_with_cross = cross_psd;
        assign rd_pass_wr = rdaddr[DEPTH_R-1:DIFF_BIT] == wrptr_rg;
        assign rd_pass_wr_nxt = wrptr_rg == rdptr_rg[DEPTH_R-1:DIFF_BIT];
        // almost_full and almost_empty
        assign now_data_num = {wrptr_rg, {DIFF_BIT{1'b0}}} - rdptr_rg;
        assign o_almost_full  = now_data_num[BIGGER_PORT-1:DIFF_BIT] >= ALMOST_FULL_THRESHOLD;
        assign o_almost_empty = now_data_num < ALMOST_EMPTY_THRESHOLD;
    end
    else begin : Read_cross_to_Write
        always @ (posedge system_clk or negedge rst_n) begin
            if (!rst_n) begin
                wren_rg <= 1'b0;
            end
            else begin
                wren_rg <= wrptr_rg[DIFF_BIT];
            end
        end
        assign cross_psd = wren_rg  ^ wrptr_rg[DIFF_BIT];
        assign wen_with_cross = cross_psd;
        assign ren_with_cross = rden;
        assign rd_pass_wr = rdaddr == wrptr_rg[DEPTH_W-1:DIFF_BIT];
        assign rd_pass_wr_nxt = rdptr_rg == wrptr_rg[DEPTH_W-1:DIFF_BIT];
        // almost_full and almost_empty
        assign now_data_num = wrptr_rg - {rdptr_rg, {DIFF_BIT{1'b0}}};
        assign o_almost_full  = now_data_num >= ALMOST_FULL_THRESHOLD;
        assign o_almost_empty = now_data_num[BIGGER_PORT-1:DIFF_BIT] < ALMOST_EMPTY_THRESHOLD;
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
            if (wen_with_cross && !ren_with_cross) begin
                state_rg <= 1'b1 ;                        
            end 
            else if (wen_with_cross && ren_with_cross && rd_pass_wr) begin
                ex_rg    <= 1'b1 ;        // Exceptional case where same address is being read and written in FIFO ram
            end
        end
      
        // State where FIFO is filled up
        else begin
            if (!wen_with_cross && ren_with_cross) begin
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
assign full      = (rd_pass_wr_nxt) && (state_rg == 1'b1)            ;
assign empty     = (rd_pass_wr_nxt && (state_rg == 1'b0)) || ex_rg ;

// Write and Read Enables internal
assign wren      = i_wren & !full                                          ;  
assign rden      = i_rden & !empty & !empty_rg                             ;

// Full and Empty to output
assign o_full      = full                                                  ;
assign o_empty     = empty || empty_rg                                     ;

// Read-address to RAM
assign nxt_rdptr   = (rdptr_rg == READ_NUM - 1) ? 'b0 : rdptr_rg + 1        ;
assign rdaddr      = rden ? nxt_rdptr : rdptr_rg                           ;

always@(posedge system_clk or negedge rst_n) begin
    if(!rst_n) begin
        rdata_reg <= 'b0;
    end
    else begin
        if(rden) begin
            rdata_reg <= rdata_wire;
        end
    end
end

generate
    if (FIRST_WORD_FALL_THROUGH) begin
        assign o_rddata = rdata_wire;
    end
    else begin
        assign o_rddata = rdata_reg;
    end
endgenerate

endmodule

/*=================================================================================================================================================================================
                                                                                 R A M   F I F O
=================================================================================================================================================================================*/