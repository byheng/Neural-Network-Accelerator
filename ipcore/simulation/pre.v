module pre #(
 parameter W = 8
)(
 input  wire         clk,
 input  wire         rst_n,

 input  wire         wr_en,
 output wire         wr_vld,
 input  wire         rd_en,
 output wire         rd_vld,

 output wire         fifo_rd_en,
 output wire         fifo_reg_en,
 input  wire [W-1:0] fifo_data,
 input  wire         fifo_empty,
 input  wire         fifo_full,

 output wire [W-1:0] pre_rd_data,
 output wire         pre_rd_empty,
 output wire         pre_rd_full
   );

assign wr_vld = ~fifo_full;
assign pre_rd_full = fifo_full;

wire         drm_rd_en;
wire         drm_reg_out;
reg          drm_vld;
reg          drm_reg_vld;
reg          drm_reg_empty;
wire         reg_out;
reg          reg_vld;
reg          reg_empty;
reg  [W-1:0] reg_data;

assign drm_reg_out = drm_vld & (~drm_reg_vld | reg_out);
assign reg_out = drm_reg_vld & (~reg_vld | rd_en);
assign drm_rd_en = ~fifo_empty & (~drm_vld | drm_reg_out | rd_en);

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    drm_vld <= 1'b0;
  else
    drm_vld <= drm_rd_en | (drm_vld & ~drm_reg_out);
end

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    drm_reg_vld <= 1'b0;
  else
    drm_reg_vld <= drm_vld | (drm_reg_vld & ~reg_out);
end

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    reg_vld <= 1'b0;
  else
    reg_vld <= drm_reg_vld | (reg_vld & ~rd_en);
end

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    drm_reg_empty <= 1'b0;
  else
    drm_reg_empty <= (~drm_vld & ~drm_reg_vld) | (~drm_vld & reg_out);
end

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    reg_empty <= 1'b1;
  else
    reg_empty <= (~drm_reg_vld & ~reg_vld) | (~drm_reg_vld & rd_en);
end

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    reg_data <= {W{1'b0}};
  else if(reg_out)
    reg_data <= fifo_data;
end

assign rd_vld = reg_vld;
assign fifo_rd_en = drm_rd_en;
assign pre_rd_data = reg_data;
assign pre_rd_empty = reg_empty;
assign fifo_reg_en = drm_reg_out;

endmodule