module mp4_tb;
`timescale 1ns/10ps

/********************* Do not touch for proper compilation *******************/
// Instantiate Interfaces
tb_itf itf();
rvfi_itf rvfi(itf.clk, itf.rst);

// Instantiate Testbench
source_tb tb(
    .magic_mem_itf(itf),
    .mem_itf(itf),
    .sm_itf(itf),
    .tb_itf(itf),
    .rvfi(rvfi)
);

// For local simulation, add signal for Modelsim to display by default
// Note that this signal does nothing and is not used for anything
bit f;

/****************************** End do not touch *****************************/

/************************ Signals necessary for monitor **********************/
// This section not required until CP2

assign rvfi.commit = (dut.cpu_wb.monitor_word.rvfi_commit) && (dut.cpu_mem_wb.insn_valid_o); // Set high when a valid instruction is modifying regfile or PC
// assign rvfi.halt = 0;   // Set high when you detect an infinite loop
initial rvfi.order = 0;
always @(posedge itf.clk iff rvfi.commit) rvfi.order <= rvfi.order + 1; // Modify for OoO

always_comb begin
/**
The following signals need to be set: */
//Instruction and trap: 
    rvfi.inst = dut.cpu_wb.monitor_word.rvfi_inst;
    rvfi.trap = dut.cpu_wb.monitor_word.rvfi_trap;

// Regfile:
    rvfi.rs1_addr = dut.cpu_wb.monitor_word.rvfi_rs1_addr;
    rvfi.rs2_addr = dut.cpu_wb.monitor_word.rvfi_rs2_addr;
    rvfi.rs1_rdata = dut.cpu_wb.monitor_word.rvfi_rs1_rdata;
    rvfi.rs2_rdata = dut.cpu_wb.monitor_word.rvfi_rs2_rdata;
    rvfi.load_regfile = dut.cpu_wb.monitor_word.rvfi_load_regfile;
    rvfi.rd_addr = dut.cpu_wb.monitor_word.rvfi_rd_addr;
    rvfi.rd_wdata = dut.cpu_wb.monitor_word.rvfi_rd_wdata;

// PC:
    rvfi.pc_rdata = dut.cpu_wb.monitor_word.rvfi_pc_rdata;
    rvfi.pc_wdata = dut.cpu_wb.monitor_word.rvfi_pc_wdata;

// Memory:
    rvfi.mem_addr = dut.cpu_wb.monitor_word.rvfi_mem_addr;
    rvfi.mem_rmask = dut.cpu_wb.monitor_word.rvfi_mem_rmask;
    rvfi.mem_wmask = dut.cpu_wb.monitor_word.rvfi_mem_wmask;
    rvfi.mem_rdata = dut.cpu_wb.monitor_word.rvfi_mem_rdata;
    rvfi.mem_wdata = dut.cpu_wb.monitor_word.rvfi_mem_wdata;

/* Please refer to rvfi_itf.sv for more information.
*/
end

/**************************** End RVFIMON signals ****************************/

/********************* Assign Shadow Memory Signals Here *********************/
// This section not required until CP2
/*
The following signals need to be set:
icache signals:
    itf.inst_read
    itf.inst_addr
    itf.inst_resp
    itf.inst_rdata

dcache signals:
    itf.data_read
    itf.data_write
    itf.data_mbe
    itf.data_addr
    itf.data_wdata
    itf.data_resp
    itf.data_rdata

Please refer to tb_itf.sv for more information.
*/

/*********************** End Shadow Memory Assignments ***********************/

// Set this to the proper value
assign itf.registers = '{default: '0};

/*********************** Instantiate your design here ************************/
/*
The following signals need to be connected to your top level:
Clock and reset signals:
    itf.clk
    itf.rst

Burst Memory Ports:
    itf.mem_read
    itf.mem_write
    itf.mem_wdata
    itf.mem_rdata
    itf.mem_addr
    itf.mem_resp

Please refer to tb_itf.sv for more information.
*/

logic clk, rst;
assign clk = itf.clk;
assign rst = itf.rst;

mp4 dut(
    .clk(clk),
    .rst(rst),

    .pmem_resp(itf.mem_resp),
    .pmem_address(itf.mem_addr),
    .pmem_read(itf.mem_read),
    .pmem_rdata(itf.mem_rdata),
    .pmem_write(itf.mem_write),
    .pmem_wdata(itf.mem_wdata)
);

/* Shadow memory. */
assign itf.inst_read = dut.instr_mem_read;
assign itf.inst_addr = dut.instr_mem_addr;
assign itf.inst_resp = dut.instr_mem_resp;
assign itf.inst_rdata = dut.instr_mem_rdata;

assign itf.data_read =  dut.cpu_wb.mem_ctrlword.mem_read;
assign itf.data_write = dut.cpu_wb.mem_ctrlword.mem_write;
assign itf.data_mbe =   dut.cpu_wb.monitor_word.rvfi_mem_wmask;
assign itf.data_addr =  dut.cpu_wb.monitor_word.rvfi_mem_addr;
assign itf.data_wdata = dut.cpu_wb.monitor_word.rvfi_mem_wdata;
assign itf.data_resp =  dut.data_mem_resp;
assign itf.data_rdata = dut.cpu_wb.monitor_word.rvfi_mem_rdata;

logic [31:0] ex_pc, branch_pc;
assign ex_pc = dut.cpu_ex.ex_pc;
assign branch_pc = dut.cpu_if.pcmux_out;
logic inf_detect;
assign inf_detect = (ex_pc == branch_pc) && (dut.cpu_ex.ex_ctrlword.branch) && (itf.mem_write == 0) && (itf.mem_read == 0);

int detected_times;

always_ff @(posedge clk) begin
    if(rst) begin
        detected_times = 0;
        rvfi.halt = 0;
    end else begin
        if(inf_detect)
            detected_times = detected_times + 1;

        if(detected_times > 10)
            rvfi.halt = 1'b1;
    end
end
/***************************** End Instantiation *****************************/

int dcache_hit_count;
int dcache_miss_count;

always_ff @(posedge clk) begin
    if(rst) begin
        dcache_hit_count = 0;
        dcache_miss_count = 0;
    end

    if(dut.mem_bus.dcache.inst_dcache_controller.state == 2'b00 && (dut.mem_bus.dcache.inst_dcache_controller.e_mem_read || dut.mem_bus.dcache.inst_dcache_controller.e_mem_write)) begin
        if(dut.mem_bus.dcache.inst_dcache_controller.hit)
            dcache_hit_count = dcache_hit_count + 1;
        else
            dcache_miss_count = dcache_miss_count + 1;
    end
end

endmodule
