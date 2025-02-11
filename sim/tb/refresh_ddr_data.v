`include "../../parameters.v"
module refresh_ddr_data();

parameter DATA_WIDTH       = 512;
parameter ADDR_WIDTH       = 32;
parameter STRB_WIDTH       = (DATA_WIDTH/8);
parameter ID_WIDTH         = 8;
parameter PIPELINE_OUTPUT  = 0;
parameter VALID_ADDR_WIDTH = ADDR_WIDTH - $clog2(STRB_WIDTH);
parameter WORD_WIDTH       = STRB_WIDTH;
parameter WORD_SIZE        = DATA_WIDTH/WORD_WIDTH;
parameter memory_patch     = "../compile/simulation_data/memory_patch.txt";
parameter weight_data_path = "../compile/compile_out/WeightAndBias.bin";
parameter picture_data_path= "../compile/compile_out/picture.bin";

reg [DATA_WIDTH-1:0] mem[1310719:0];  // 80 MB
integer i, j;
// 读取权重文件
integer file, o, addr, d, times;
reg [31:0]weight_first_addr, bias_first_addr, picture_first_addr;
reg [7:0] byte_data[63:0];
integer out_file, in_file;
initial begin
    for (i = 0; i < 2**VALID_ADDR_WIDTH; i = i + 2**(VALID_ADDR_WIDTH/2)) begin
        for (j = i; j < i + 2**(VALID_ADDR_WIDTH/2); j = j + 1) begin
            mem[j] = 0;
        end
    end
    // load weight
    file = $fopen(weight_data_path, "rb");
    addr = 0;
    weight_first_addr = `DDR_WEIGHT_ADDR / 64;
    while (!$feof(file)) begin
        o = $fread(byte_data, file);
        mem[weight_first_addr + addr] = {byte_data[63], byte_data[62], byte_data[61], byte_data[60], byte_data[59], byte_data[58], byte_data[57], byte_data[56], byte_data[55], byte_data[54], 
                                         byte_data[53], byte_data[52], byte_data[51], byte_data[50], byte_data[49], byte_data[48], byte_data[47], byte_data[46], byte_data[45], byte_data[44], 
                                         byte_data[43], byte_data[42], byte_data[41], byte_data[40], byte_data[39], byte_data[38], byte_data[37], byte_data[36], byte_data[35], byte_data[34], 
                                         byte_data[33], byte_data[32], byte_data[31], byte_data[30], byte_data[29], byte_data[28], byte_data[27], byte_data[26], byte_data[25], byte_data[24], 
                                         byte_data[23], byte_data[22], byte_data[21], byte_data[20], byte_data[19], byte_data[18], byte_data[17], byte_data[16], byte_data[15], byte_data[14], 
                                         byte_data[13], byte_data[12], byte_data[11], byte_data[10], byte_data[9], byte_data[8], byte_data[7], byte_data[6], byte_data[5], byte_data[4], 
                                         byte_data[3], byte_data[2], byte_data[1], byte_data[0]};
        addr = addr + 1;
    end
    $display("read data num: %d", addr<<6);
    $fclose(file);
    // load picture
    file = $fopen(picture_data_path, "rb");
    addr = 0;
    picture_first_addr = `DDR_PICTURE_ADDR / 64;
    while (!$feof(file)) begin
        o = $fread(byte_data, file);
        mem[picture_first_addr + addr] = {byte_data[63], byte_data[62], byte_data[61], byte_data[60], byte_data[59], byte_data[58], byte_data[57], byte_data[56], byte_data[55], byte_data[54], 
                                         byte_data[53], byte_data[52], byte_data[51], byte_data[50], byte_data[49], byte_data[48], byte_data[47], byte_data[46], byte_data[45], byte_data[44], 
                                         byte_data[43], byte_data[42], byte_data[41], byte_data[40], byte_data[39], byte_data[38], byte_data[37], byte_data[36], byte_data[35], byte_data[34], 
                                         byte_data[33], byte_data[32], byte_data[31], byte_data[30], byte_data[29], byte_data[28], byte_data[27], byte_data[26], byte_data[25], byte_data[24], 
                                         byte_data[23], byte_data[22], byte_data[21], byte_data[20], byte_data[19], byte_data[18], byte_data[17], byte_data[16], byte_data[15], byte_data[14], 
                                         byte_data[13], byte_data[12], byte_data[11], byte_data[10], byte_data[9], byte_data[8], byte_data[7], byte_data[6], byte_data[5], byte_data[4], 
                                         byte_data[3], byte_data[2], byte_data[1], byte_data[0]};
        addr = addr + 1;
    end
    $display("read data num: %d", addr<<6);
    $fclose(file);
    // save mem to txt
    file = $fopen(memory_patch, "w");
    $writememh(memory_patch, mem);
    $fclose(file);
end
endmodule