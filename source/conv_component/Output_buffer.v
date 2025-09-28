/*
    created by  : <Xidian University>
    created date: 2024-09-24
    author      : <zhiquan huang>
*/
`timescale 1ns/100fs

`include "../../parameters.v"

module Output_buffer #(
    parameter MAC_OUTPUT_WIDTH = `MAC_OUTPUT_WIDTH // 36
)
(
    input                                  system_clk   ,
    input                                  rst_n        ,
    // refresh buffer   
    input                                  refresh_req  ,

    input                                  adder_pulse  ,
    output[MAC_OUTPUT_WIDTH*8-1:0]         adder_feature, // --> convolution_core

    input [MAC_OUTPUT_WIDTH*8-1:0]         feature_in   , // <-- convolution_core, 8个通道的卷积结果
    input                                  feature_valid
);

reg [14:0]  uram_write_addr;
reg [14:0]  uram_read_addr;
wire[71:0]  uram_read_data[3:0]; 

genvar i;
generate
    for (i=0; i<4; i=i+1) begin: output_buffer
        if (`device == "xilinx") begin
            xpm_memory_sdpram #(
                .ADDR_WIDTH_A           (15),               // DECIMAL
                .ADDR_WIDTH_B           (15),               // DECIMAL
                .AUTO_SLEEP_TIME        (0),                // DECIMAL
                .BYTE_WRITE_WIDTH_A     (72),               // DECIMAL
                .CASCADE_HEIGHT         (0),                // DECIMAL
                .CLOCKING_MODE          ("common_clock"),   // String
                .ECC_MODE               ("no_ecc"),         // String
                .MEMORY_INIT_FILE       ("none"),           // String
                .MEMORY_INIT_PARAM      ("0"),              // String
                .MEMORY_OPTIMIZATION    ("true"),           // String
                .MEMORY_PRIMITIVE       ("ultra"),          // String
                .MEMORY_SIZE            (32768*72),         // DECIMAL
                .MESSAGE_CONTROL        (0),                // DECIMAL
                .READ_DATA_WIDTH_B      (72),               // DECIMAL
                .READ_LATENCY_B         (3),                // DECIMAL
                .READ_RESET_VALUE_B     ("0"),              // String
                .RST_MODE_A             ("SYNC"),           // String
                .RST_MODE_B             ("SYNC"),           // String
                .SIM_ASSERT_CHK         (1),                // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
                .USE_EMBEDDED_CONSTRAINT(0),                // DECIMAL
                .USE_MEM_INIT           (1),                // DECIMAL
                .USE_MEM_INIT_MMI       (0),                // DECIMAL
                .WAKEUP_TIME            ("disable_sleep"),  // String
                .WRITE_DATA_WIDTH_A     (72),               // DECIMAL
                .WRITE_MODE_B           ("read-first"),     // String
                .WRITE_PROTECT          (1)                 // DECIMAL
            )
            xpm_memory_sdpram_inst (
                .dbiterrb       (),
                .sbiterrb       (),
                .clka           (system_clk),                     
                .clkb           (system_clk),     
                .dina           (feature_in[i*MAC_OUTPUT_WIDTH*2+:MAC_OUTPUT_WIDTH*2]),  // 每个通道包含2个MAC的结果
                .addra          (uram_write_addr),               
                .doutb          (uram_read_data[i]),           
                .addrb          (uram_read_addr),          
                .ena            (1'b1),                       
                .enb            (1'b1),                       
                .injectdbiterra (1'b0), 
                .injectsbiterra (1'b0), 
                .regceb         (1'b1),                
                .rstb           (1'b0),                   
                .sleep          (1'b0),                 
                .wea            (feature_valid)                        
            );
        end
        else if (`device == "simulation") begin
            // simulation_ram #(
            //     .DATA_W    	( 72      ),
            //     .DATA_R    	( 72      ),
            //     .DEPTH_W   	( 15      ),
            //     .DEPTH_R   	( 15      ),
            //     .DELAY     	( 2       )
            // )
            // u_simulation_ram(
            //     .w_clk     	( system_clk                                            ),
            //     .i_wren  	( feature_valid                                         ),
            //     .i_waddr 	( uram_write_addr                                       ),
            //     .i_wdata 	( feature_in[i*MAC_OUTPUT_WIDTH*2+:MAC_OUTPUT_WIDTH*2]  ),
            //     .r_clk     	( system_clk                                            ),
            //     .i_raddr 	( uram_read_addr                                        ),
            //     .o_rdata 	( uram_read_data[i]                                     )   
            // );

            SDPRAM #(
                .DEPTH 	( 2**15 ),
                .WIDTH 	( 72    ),
                .DELAY  ( 2     ))
            u_SDPRAM(
                .clock 	( system_clk                                            ),
                .reset 	( ~rst_n                                                ),
                .wen   	( feature_valid                                         ),
                .ren   	( 1'b1                                                  ),
                .waddr 	( uram_write_addr                                       ),
                .raddr 	( uram_read_addr                                        ),
                .din   	( feature_in[i*MAC_OUTPUT_WIDTH*2+:MAC_OUTPUT_WIDTH*2]  ), // 每个通道包含2个MAC的结果
                .dout  	( uram_read_data[i]                                     )
            );
        end
    end
endgenerate

always @(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        uram_write_addr <= 0;
    end
    else if (refresh_req) begin
        uram_write_addr <= 0;
    end
    else if (feature_valid) begin
        uram_write_addr <= uram_write_addr + 1;
    end
end

always @(posedge system_clk or negedge rst_n) begin
    if(~rst_n) begin
        uram_read_addr <= 0;
    end
    else if (refresh_req) begin
        uram_read_addr <= 0;
    end
    else if (adder_pulse) begin
        uram_read_addr <= uram_read_addr + 1;
    end
end

// 合并4个通道的输出，每个通道包含2个MAC的结果
assign adder_feature = {uram_read_data[3], uram_read_data[2], uram_read_data[1], uram_read_data[0]};

endmodule