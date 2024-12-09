`ifndef AI_parameters
`define AI_parameters

`define debug               1   // 调试模式
`define device              "xilinx"
`define ACTIVATE_TYPE       0   // 0:RELU 1:LEAKY_RELU

// PE 阵列参数
`define FEATURE_WIDTH       16  // 特征位宽
`define SIGNED_FEATURE      1   // 特征是否有符号
`define WEIGHT_WIDTH        16  // 权重位宽
`define SIGNED_WEIGHT       1   // 权重是否有符号
`define MAC_WIDTH           `FEATURE_WIDTH + `WEIGHT_WIDTH // MAC位宽
`define MAC_OVERFLOW_WIDTH  4   // 预留8位防止溢出
`define MAC_OUTPUT_WIDTH    `MAC_WIDTH + `MAC_OVERFLOW_WIDTH   

`define PE_CORE_NUM         16
`define PE_NUM_PRE_CORE     3
`define PE_ARRAY_SIZE       8

// 量化参数
`define FEATURE_QUANTIZE    5  // 特征量化位宽
`define WEIGHT_QUANTIZE     5  // 权重量化位宽

// DDR读写总线参数
`define MEM_ADDR_WIDTH      32 // 4GB内存地址位宽                                                         
`define MEM_DATA_WIDTH      512     

// DDR 地址参数
`define DDR_PICTURE_ADDR    32'h00000000
`define DDR_WEIGHT_ADDR     32'h01000000 // DDR 权重首地址   
`define WEIGHT_MAX_SIZE     32'h01000000 // 权重最大容量     16MB

`endif