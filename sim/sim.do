vlib work
vmap work ./work

vlog ../ipcore/simulation/FIFO/*.v
vlog ../ipcore/simulation/SRAM/*.v
vlog ../parameters.v
vlog ../source/conv_component/*
vlog ../source/order/*
vlog ../source/pool_component/*
vlog ../source/upsample_component/*
vlog ../source/*.v
vlog ./tb/*

vsim -c -do "run -all; quit" work.conv_control_tb