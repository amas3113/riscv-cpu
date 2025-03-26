set mp4_path [pwd]

# Compile source code
vlog -quiet -svinputport=relaxed -msglimitcount 1 -msglimit error $mp4_path/hdl/rv32i_mux_types.sv
vlog -quiet -svinputport=relaxed -msglimitcount 1 -msglimit error $mp4_path/hdl/rv32i_types.sv
vlog -quiet -svinputport=relaxed -msglimitcount 1 -msglimit error $mp4_path/hdl/data_cache/dcache_mux_types.sv

vlog -quiet -svinputport=relaxed -msglimitcount 1 -msglimit error $mp4_path/hdl/given_cache/*.sv
vlog -quiet -svinputport=relaxed -msglimitcount 1 -msglimit error $mp4_path/hdl/data_cache/*.v
vlog -quiet -svinputport=relaxed -msglimitcount 1 -msglimit error $mp4_path/hdl/data_cache/*.sv
vlog -quiet -svinputport=relaxed -msglimitcount 1 -msglimit error $mp4_path/hdl/memory_bus/*.sv
vlog -quiet -svinputport=relaxed -msglimitcount 1 -msglimit error $mp4_path/hdl/branch_predictor/*.sv
vlog -quiet -svinputport=relaxed -msglimitcount 1 -msglimit error $mp4_path/hdl/stage_registers/*.sv
vlog -quiet -svinputport=relaxed -msglimitcount 1 -msglimit error $mp4_path/hdl/stage_units/*.sv
vlog -quiet -svinputport=relaxed -msglimitcount 1 -msglimit error $mp4_path/hdl/*.sv
vlog -quiet -svinputport=relaxed -msglimitcount 1 -msglimit error $mp4_path/hvl/*.sv
vlog -quiet -svinputport=relaxed -msglimitcount 1 -msglimit error $mp4_path/hvl/*.v

# Simulate
vsim -quiet -t 1ps -gui -L altera_mf_ver -L work mp4_tb

# Add waves for viewing
add wave sim:/mp4_tb/*
add wave -group {CPU_Top} -radix hexadecimal sim:/mp4_tb/dut/*
add wave -group {Memory Bus} -radix hexadecimal sim:/mp4_tb/dut/mem_bus/*
add wave -group {Data Cache} -radix hexadecimal sim:/mp4_tb/dut/mem_bus/dcache/*
add wave -group {Instruction Cache} -radix hexadecimal sim:/mp4_tb/dut/mem_bus/icache/*
add wave -group {Instruction Cache Performance} -radix decimal sim:/mp4_tb/dut/mem_bus/icache/control/icache_hits
add wave -group {Instruction Cache Performance} -radix decimal sim:/mp4_tb/dut/mem_bus/icache/control/icache_misses
add wave -group {Instruction Cache Performance} -radix decimal sim:/mp4_tb/dut/mem_bus/icache/control/pref_hits
add wave -group {Instruction Cache Performance} -radix decimal sim:/mp4_tb/dut/mem_bus/icache/control/pref_misses
add wave -group {Instruction Cache Performance} -radix decimal sim:/mp4_tb/dut/mem_bus/icache/control/hits_while_pref
add wave -group {Instruction Cache Performance} -radix decimal sim:/mp4_tb/dut/mem_bus/icache/control/inst_read
add wave -group {Instruction Cache Performance} -radix decimal sim:/mp4_tb/dut/mem_bus/icache/control/icache_perf
add wave -group {Instruction Cache Performance} -radix decimal sim:/mp4_tb/dut/mem_bus/icache/control/cpu_wait_time
add wave -group {Instruction Cache Performance} -radix decimal sim:/mp4_tb/dut/mem_bus/icache/control/avg_mem_latency
add wave -group {Instruction Cache Performance} -radix decimal sim:/mp4_tb/dut/mem_bus/icache/control/pmem_fetches
add wave -group {Harzard Detection} -radix hexadecimal sim:/mp4_tb/dut/hzd_unit/*
add wave -group {IF} -radix hexadecimal sim:/mp4_tb/dut/cpu_if/*
add wave -group {IF-ID} -radix hexadecimal sim:/mp4_tb/dut/cpu_if_id/*
add wave -group {ID} -radix hexadecimal sim:/mp4_tb/dut/cpu_id/*
add wave -group {ID-EX} -radix hexadecimal sim:/mp4_tb/dut/cpu_id_ex/*
add wave -group {EX} -radix hexadecimal sim:/mp4_tb/dut/cpu_ex/*
add wave -group {EX-MEM} -radix hexadecimal sim:/mp4_tb/dut/cpu_ex_mem/*
add wave -group {MEM} -radix hexadecimal sim:/mp4_tb/dut/cpu_mem/*
add wave -group {MEM-WB} -radix hexadecimal sim:/mp4_tb/dut/cpu_mem_wb/*
add wave -group {WB} -radix hexadecimal sim:/mp4_tb/dut/cpu_wb/*
add wave -group {RVFI} -radix hexadecimal sim:/mp4_tb/rvfi/*
add wave -radix hexadecimal sim:/mp4_tb/dut/cpu_id/id_regfile/data

view structure
view signals
run -all 

examine -radix hexadecimal /mp4_tb/dut/cpu_id/id_regfile/data

quit
