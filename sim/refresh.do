vlib work
vmap work ./work

vlog ../parameters.v
vlog ../ipcore/simulation/*
vlog ../source/conv_component/*
vlog ../source/order/*
vlog ../source/pool_component/*
vlog ../source/upsample_component/*
vlog ../source/accelerator_control.v
vlog ./tb/*

vsim -c -do "run -all; quit" work.refresh_ddr_data