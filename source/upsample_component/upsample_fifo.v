/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module ram_based_upsample_fifo #(
    parameter DATA_W  = 256,    
    parameter DEPTH_W = 10,    
    parameter DATA_R  = 128,  
    parameter DEPTH_R = 11,
    parameter WRITE_NUM = 2 ** DEPTH_W,
    parameter READ_NUM = 2 ** DEPTH_R,
    parameter ALMOST_FULL_THRESHOLD = 1000
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
    input                   change_point     ,
    input  [DEPTH_R - 1 : 0]almost_empty_threshold,
    output                  ready_for_output
);


/*---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   Internal Registers / Signals
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
reg  [DEPTH_W - 1 : 0] wrptr_rg         ; // Write pointer
reg  [DEPTH_R - 1 : 0] rdptr_rg         ; // Read pointer
reg  [DEPTH_R - 1 : 0] rdptr_rg_virtual ;
reg                    pointer_select   ;
reg                    rden_rg          ;
wire                   rden_cross       ;
wire [DEPTH_R - 1 : 0] now_data_num     ; // Number of data in FIFO
wire [DEPTH_R - 1 : 0] nxt_rdptr        ; // Next Read pointer   (true pointer)
wire [DEPTH_R - 1 : 0] rdaddr           ; // Read-address to RAM (true pointer)
wire [DEPTH_R - 1 : 0] nxt_rdptr_virtual; // Next Read pointer   (virtual pointer)
wire [DEPTH_R - 1 : 0] rdaddr_virtual   ; // Read-address to RAM (virtual pointer)
wire [DATA_R - 1 : 0]  rddata_wire      ; // Read-data from RAM
reg  [DATA_R - 1 : 0]  rddata_rg        ; // Read-data registered
wire [DEPTH_R - 1 : 0] rdaddr_select    ; // Read-address to RAM (selected)
 
wire wren     ;        // Write Enable signal generated iff FIFO is not full
wire rden     ;        // Read Enable signal generated iff FIFO is not empty
wire full     ;        // Full signal
wire empty    ;        // Empty signal
reg  empty_rg ;        // Empty signal (registered)
reg  state_rg ;        // State
reg  ex_rg    ;        // Exception


/*---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   Instantiation of RAM
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
generate
    if (`device == "xilinx") begin
        upsample_ram upsample_ram_inst (
            .clka   ( system_clk    ),
            .ena    ( 1'b1          ),
            .wea    ( wren          ),
            .addra  ( wrptr_rg      ),
            .dina   ( i_wrdata      ),
            .clkb   ( system_clk    ),  
            .enb    ( 1'b1          ),
            .addrb  ( rdaddr_select ),
            .doutb  ( o_rddata      )
        );
    end
    else if (`device == "simulation") begin
        simulation_ram #(
            .DATA_W    	( 256      ),
            .DATA_R    	( 128      ),
            .DEPTH_W   	( 10       ),
            .DEPTH_R   	( 11       )
        )
        u_simulation_ram(
            .w_clk     	( system_clk    ),
            .i_wren  	( wren          ),
            .i_waddr 	( wrptr_rg      ),
            .i_wdata 	( i_wrdata      ),
            .r_clk     	( system_clk    ),
            .i_raddr 	( rdaddr_select ),
            .o_rdata 	( o_rddata      )
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
        pointer_select <= 1'b0;      // 0 : 虚拟指针，1：真实指针
        rdptr_rg_virtual <= 0;
        rden_rg   <= 1'b0 ;
    end
    else begin   
        if (change_point) begin
            pointer_select <= ~pointer_select;
        end

        /* FIFO write logic */            
        if (wren) begin         
            if (wrptr_rg == WRITE_NUM - 1) begin
                wrptr_rg <= 0               ;        // Reset write pointer  
            end
            else begin
                wrptr_rg <= wrptr_rg + 1    ;        // Increment write pointer            
            end
        end

        // 实际指针变化
        if (rden & pointer_select) begin         
            if (rdptr_rg == READ_NUM - 1) begin
               rdptr_rg <= 0               ;        // Reset read pointer
            end
            else begin
               rdptr_rg <= rdptr_rg + 1    ;        // Increment read pointer            
            end
        end

        // 虚拟指针变化
        if (rden & ~pointer_select) begin         
            if (rdptr_rg_virtual == READ_NUM - 1) begin
               rdptr_rg_virtual <= 0               ;        // Reset read pointer
            end
            else begin
               rdptr_rg_virtual <= rdptr_rg_virtual + 1    ;        // Increment read pointer            
            end
        end

        rden_rg <= rdptr_rg[1];
      
        // State where FIFO is emptied
        if (state_rg == 1'b0) begin
            ex_rg <= 1'b0 ;

            if (wren && !(rden_cross & pointer_select)) begin
                state_rg <= 1'b1 ;                        
            end 
            else if (wren && (rden_cross & pointer_select) && (rdaddr[DEPTH_R-1:1] == wrptr_rg)) begin
                ex_rg    <= 1'b1 ;        // Exceptional case where same address is being read and written in FIFO ram
            end
        end
      
        // State where FIFO is filled up
        else begin
            if (!wren && rden_cross && pointer_select) begin
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
assign rden_cross = rden_rg ^ rdptr_rg[1];

// Full and Empty internal
assign full      = (wrptr_rg == rdptr_rg[DEPTH_R-1:1]) && (state_rg == 1'b1)            ;
assign empty     = ((wrptr_rg == rdptr_rg[DEPTH_R-1:1]) && (state_rg == 1'b0)) || ex_rg ;

// Write and Read Enables internal
assign wren      = i_wren & !full                                          ;  
assign rden      = i_rden & !empty & !empty_rg                             ;

// Full and Empty to output
assign o_full      = full                                                  ;
assign o_empty     = empty || empty_rg                                     ;

// Read-address to RAM (true pointer)
assign nxt_rdptr   = (rdptr_rg == READ_NUM - 1) ? 'b0 : rdptr_rg + 1       ;
assign rdaddr      = (rden & pointer_select) ? nxt_rdptr : rdptr_rg                           ;

// Read-address to RAM (virtual pointer)
assign nxt_rdptr_virtual = (rdptr_rg_virtual == READ_NUM - 1) ? 'b0 : rdptr_rg_virtual + 1       ;
assign rdaddr_virtual    = (rden & ~pointer_select) ? nxt_rdptr_virtual : rdptr_rg_virtual                           ;

// almost_full and almost_empty
assign now_data_num = {wrptr_rg, 1'b0} - rdptr_rg;
assign o_almost_full  = now_data_num[DEPTH_R-1:1] >= ALMOST_FULL_THRESHOLD;
assign o_almost_empty = now_data_num < almost_empty_threshold;

// always @(posedge system_clk) begin
//     if (rden) begin
//         rddata_rg <= rddata_wire;
//     end
// end

// assign o_rddata = rddata_rg;

assign rdaddr_select = (pointer_select) ? rdaddr : rdaddr_virtual;
assign ready_for_output = (pointer_select) ? o_empty : o_almost_empty;
endmodule

/*=================================================================================================================================================================================
                                                                                 R A M   F I F O
=================================================================================================================================================================================*/