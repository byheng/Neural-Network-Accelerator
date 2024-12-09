vlib work
vmap work ./work
vlog ./tb/*.v
vlog ../parameters.v
# vlog ../source/conv_component/*.v
# vlog ../source/pool_component/*.v
# vlog ../source/upsample_component/*.v
# do ../ipcore/simulation/ip_path.do
# add ip
# do ../../../ipcore/shift_register_ram/ip_path.do
# do ../../../ipcore/MAC/ip_path.do
# do ../../../ipcore/bias_buffer/ip_path.do
# do ../../../ipcore/return_fifo/ip_path.do
# do ../../../ipcore/feature_ram/ip_path.do
# do ../../../ipcore/output_buffer/ip_path.do
# do ../../../ipcore/weight_buffer/ip_path.do
# do ../../../ipcore/rgb888_fifo/ip_path.do
# do ../../../ipcore/order_rom/ip_path.do
# do ../../../ipcore/shift_register_ram_small/ip_path.do
# do ../../../ipcore/return_ram/ip_path.do

####################### 不依赖外部 simulation ##########################
# 看波形
# vsim -L work work.conv_control_tb -voptargs=+acc

# view -new wave 
# add wave -position insertpoint sim:/conv_control_tb/u_convolution_control/*

# view -new wave
# add wave -position insertpoint sim:/conv_control_tb/u_convolution_control/u_return_buffer/*

# view -new wave
# add wave -position insertpoint sim:/conv_control_tb/u_convolution_control/u_upsample/*


# 不看波形，加快仿真速度
# vsim -L work work.conv_control_tb
# run 300ms
