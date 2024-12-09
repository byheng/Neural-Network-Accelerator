/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../source/parameters.v"

module ram_based_fifo_return_buffer #(
    parameter DATA_W  = 8,    
    parameter DEPTH_W = 12,    
    parameter DATA_R  = 128,  
    parameter DEPTH_R = 8,
    parameter WRITE_NUM = 2 ** DEPTH_W,
    parameter READ_NUM = 2 ** DEPTH_R,
    parameter ALMOST_FULL_THRESHOLD = 2 ** (DEPTH_W - 1) - 1,
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
    output                  o_almost_empty   ,        // Almost empty signal
    input                   pull_down
);


/*---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   Internal Registers / Signals
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
reg  [DEPTH_W - 1 : 0] wrptr_rg  ; // Write pointer
reg  [DEPTH_R - 1 : 0] rdptr_rg  ; // Read pointer
wire [DEPTH_W - 1 : 0] now_data_num; // Number of data in FIFO
wire [DEPTH_R - 1 : 0] nxt_rdptr ; // Next Read pointer
wire [DEPTH_R - 1 : 0] rdaddr    ; // Read-address to RAM
 
wire wren            ;        // Write Enable signal generated iff FIFO is not full
reg  wren_rg         ;        // Write Enable signal registered
wire wren_cross_psd  ;
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
    if (`device == "simulation") begin
        simulation_ram#(
            .DATA_W    ( DATA_W  ),
            .DATA_R    ( DATA_R  ),
            .DEPTH_W   ( DEPTH_W ),
            .DEPTH_R   ( DEPTH_R )
        )return_ram_inst(
            .clk       ( system_clk  ),
            .i_wren    ( wren        ),
            .i_waddr   ( wrptr_rg    ),
            .i_wdata   ( i_wrdata    ),
            .i_raddr   ( rdaddr      ),
            .o_rdata   ( o_rddata    )
        );
    end
    else begin
        return_ram return_ram_inst (
            .wr_data    (i_wrdata   ),    
            .wr_addr    (wrptr_rg   ),    
            .wr_en      (wren       ),      
            .wr_clk     (system_clk ),     
            .wr_rst     (~rst_n     ),     
            .rd_addr    (rdaddr     ),    
            .rd_data    (o_rddata   ),    
            .rd_clk     (system_clk ),     
            .rd_rst     (~rst_n     )      
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
       wren_rg   <= 1'b0 ;
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
        else if (pull_down) begin
            wrptr_rg <= {(wrptr_rg[DEPTH_W-1:4] + 1), 4'b0000};
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

        // 读写位宽不对等，因此在计算full和empty时读信号需要重定义，现在读写位宽差4位，因此采写指针的第四位上升沿
        wren_rg <= wrptr_rg[4];
      
        // State where FIFO is emptied
        if (state_rg == 1'b0) begin
            ex_rg <= 1'b0 ;

            if (wren_cross_psd && !rden) begin
                state_rg <= 1'b1 ;                        
            end 
            else if (wren_cross_psd && rden && (rdaddr == wrptr_rg[DEPTH_W-1:4])) begin
                ex_rg    <= 1'b1 ;        // Exceptional case where same address is being read and written in FIFO ram
            end
        end
      
        // State where FIFO is filled up
        else begin
            if (!wren_cross_psd && rden) begin
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
// 读使能跨到输出段的使能信号
assign wren_cross_psd = wren_rg ^ wrptr_rg[4];

// Full and Empty internal
assign full      = (wrptr_rg[DEPTH_W-1:4] == rdptr_rg) && (state_rg == 1'b1)            ;
assign empty     = ((wrptr_rg[DEPTH_W-1:4] == rdptr_rg) && (state_rg == 1'b0)) || ex_rg ;

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
assign now_data_num = wrptr_rg - {rdptr_rg, 4'b0};
assign o_almost_full  = now_data_num >= ALMOST_FULL_THRESHOLD;
assign o_almost_empty = now_data_num[DEPTH_W-1:4] < ALMOST_EMPTY_THRESHOLD;

endmodule

/*=================================================================================================================================================================================
                                                                                 R A M   F I F O
=================================================================================================================================================================================*/