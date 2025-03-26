.PHONY: all compile simulate clean

# modelsim compilation process...
# vlog compiles SystemVerilog code, using work/ dir as libary (i.e. for imported
# 	packages)
# vsim runs the simulator, often to dump vcd file for waveviewing...
all: simulate

compile:
	./rv_load_memory.sh src/mp4-cp1.s memory.lst 32

# .do can optionally compile at simulation runtime...
simulate:
	vsim -c -do mp4.do

clean:
	rm -r work/ transcript memory.lst vsim.wlf
