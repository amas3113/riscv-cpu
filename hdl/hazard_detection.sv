import rv32i_types::*;

module hazard_detection (
    input logic         clk_i,                  // currently unused
    input logic         rst_i,

    // Pipeline monitoring signals
    input logic         if_id_insn_valid_i,     // currently unused
    input logic         id_ex_insn_valid_i,
    input logic         ex_mem_insn_valid_i,    // currently unused
    input logic         mem_wb_insn_valid_i,    // currently unused

    // Input signals from IF stage, for memory latency detection (waiting for memory)
    input logic         insn_rdy_i,             // This signal is not verified to be working.
    input logic         imem_read_i,            // Raw memory signal
    input logic         imem_resp_i,            // Raw memory signal.

    // Input signals from ID stage
    input logic [4:0]   rs1_addr_i,
    input logic [4:0]   rs2_addr_i,             // when == 5'h0, it means such register is not used.
    input logic [4:0]   fwd_ex_rd_addr_i,
    input logic [4:0]   fwd_mem_rd_addr_i,
    input logic [4:0]   rf_waddr_i,

    // Input signals from ID_EX stage registers
    input logic [4:0]   id_ex_rd_addr_i,
    
    // Input signals from EX_MEM stage registers
    input logic [4:0]   ex_mem_rd_addr_i,
    input rv32i_ctrl_word mem_wb_ctrlword_i,

    // Input from MEM stage, for memory latency detection (waiting for memory)
    input logic         dmem_read_i,
    input logic         dmem_write_i,
    input logic         dmem_resp_i,
    
    // Input signals from MEM_WB stage registers (probably not needed because it is always forwarded)
    input logic [4:0]   mem_wb_rd_addr_i, 

    // Branch (Control) harzard detection (pc_gold_i != pc_i means the output of pc_i register is wrong (see diagram))
    input rv32i_word    pc_i, 
    input rv32i_word    pc_gold_i,

    // Controls IF stage load memory
    output logic        pc_i_ok_o,

    // Load the pipeline stage registers
    // Note: If a previous stage is not loaded, and the following stage is loaded (not flushed)
    //       It will lead to the same instruction being repeated.
    output logic        ld_if_o,
    output logic        ld_id_o,
    output logic        ld_ex_o,
    output logic        ld_mem_o,
    output logic        ld_pc_o,

    // The flush signals load a bubble in the corresponding state registers (NOP)
    // If the stage registers after the flushed registers is not loaded, the flushed instruction is lost
    output logic        flush_if_id_o,
    output logic        flush_id_ex_o,
    output logic        flush_ex_mem_o,
    output logic        flush_mem_wb_o
);

logic rs1_ex_dep;       // ID rs1 depends on EX rd
logic rs2_ex_dep;       // ID rs2 depends on EX rd
logic ex_hzd;           // ID depends on EX

logic rs1_mem_dep;      // ID rs1 depends on MEM rd
logic rs2_mem_dep;      // ID rs2 depends on MEM rd
logic mem_hzd;          // ID depends on MEM

logic ex_can_fwd_rs1;   // EX can forward rs1 data (rs1 does not depend on mem_rdata)
logic ex_can_fwd_rs2;   // EX can forward rs2 data (rs2 does not depend on mem_rdata)

logic mem_can_fwd_rs1;  // MEM can forward rs1 data ()
logic mem_can_fwd_rs2;  // MEM can forward rs2 data ()

logic rs1_wb_dep;
logic rs2_wb_dep;
logic wb_can_fwd_rs1;
logic wb_can_fwd_rs2;
logic wb_hzd;

// Difference between dependency and forwarding ability is subtle, check for optimizations/more explicit declarations
// to simplify/make more clear the difference.

always_comb begin
    pc_i_ok_o       = (~id_ex_insn_valid_i) || (pc_gold_i == pc_i);

    rs1_ex_dep      = (rs1_addr_i == id_ex_rd_addr_i) && (rs1_addr_i != 5'd0);
    rs2_ex_dep      = (rs2_addr_i == id_ex_rd_addr_i) && (rs2_addr_i != 5'd0);

    ex_can_fwd_rs1  = (rs1_addr_i == fwd_ex_rd_addr_i);
    ex_can_fwd_rs2  = (rs2_addr_i == fwd_ex_rd_addr_i);

    ex_hzd          = (rs1_ex_dep && !ex_can_fwd_rs1) || (rs2_ex_dep && !ex_can_fwd_rs2);

    rs1_mem_dep     = (rs1_addr_i == ex_mem_rd_addr_i) && (rs1_addr_i != 5'd0);
    rs2_mem_dep     = (rs2_addr_i == ex_mem_rd_addr_i) && (rs2_addr_i != 5'd0);

    mem_can_fwd_rs1 = (rs1_addr_i == fwd_mem_rd_addr_i);
    mem_can_fwd_rs2 = (rs2_addr_i == fwd_mem_rd_addr_i);

    mem_hzd         = (rs1_mem_dep && !mem_can_fwd_rs1) || (rs2_mem_dep && !mem_can_fwd_rs2);

    rs1_wb_dep      = (rs1_addr_i == mem_wb_rd_addr_i) && (rs1_addr_i != 5'd0);
    rs2_wb_dep      = (rs2_addr_i == mem_wb_rd_addr_i) && (rs2_addr_i != 5'd0);

    wb_can_fwd_rs1  = (rs1_addr_i == rf_waddr_i);
    wb_can_fwd_rs2  = (rs2_addr_i == rf_waddr_i);

    wb_hzd          = (rs1_wb_dep &&!wb_can_fwd_rs1) || (rs2_wb_dep &&!wb_can_fwd_rs2);
end

function void set_defaults();
    ld_if_o         = 1'b1;
    ld_id_o         = 1'b1;
    ld_ex_o         = 1'b1;
    ld_mem_o        = 1'b1;
    ld_pc_o         = 1'b1;

    flush_if_id_o   = 1'b0;
    flush_id_ex_o   = 1'b0;
    flush_ex_mem_o  = 1'b0;
    flush_mem_wb_o  = 1'b0;
endfunction

function void set_loads(int i);
    ld_pc_o         = 1'(i);
    ld_if_o         = 1'(i);
    ld_id_o         = 1'(i);
    ld_ex_o         = 1'(i);
    ld_mem_o        = 1'(i);
endfunction

always_comb begin
    set_defaults();

    if (rst_i) begin
        set_loads(0);

        flush_if_id_o       = 1'b0;
        flush_id_ex_o       = 1'b0;
        flush_ex_mem_o      = 1'b0;
        flush_mem_wb_o      = 1'b0;
    end else begin              // Control (Branching Harzard)
        // Highest priority events happen at the end of the pipeline.
        // Since if the follwing stage cannot continue, the prior stages must not proceed.

        // Priority: WB stage must not evict. MEM-WB stage registers must not load.
        if ((mem_wb_ctrlword_i.mem_write || mem_wb_ctrlword_i.mem_read) && ~dmem_resp_i)
            // Data memory latency.
            set_loads(0);
        // Priority: MEM stage must not evict. EX-MEM stage registers must not load.
            // No such case.
        // Priority: EX stage must not evict. ID-EX stage registers must not load.
            // No such case.
        // Priority: ID stage must not evict. IF-ID stage registers must not load.
        else if (~pc_i_ok_o) begin
            // Branching harzard. Command in ID stage is not correct.
            flush_if_id_o   = 1'b1;     // Dispose the instruction in the IF stage (incorrect addr).
            flush_id_ex_o   = 1'b1;     // Dispose the instruction in the ID stage (incorrect addr).
            ld_pc_o         = 1'b1;
        end else if (ex_hzd || mem_hzd || wb_hzd) begin
            // Data harzard from various stages to ID.
            flush_id_ex_o   = 1'b1;
            ld_if_o         = 1'b0;     
            ld_pc_o         = 1'b0;
        // Priority: IF stage is not providing instruction. IF-ID must not load.
        end else if (~insn_rdy_i) begin  // IF stage memory latency.
            ld_pc_o = 1'b0;
            ld_if_o = 1'b0;
            flush_if_id_o = 1'b1;
            ld_id_o = 1'b1;
            ld_ex_o = 1'b1;
            ld_mem_o = 1'b1;
        end 
        // $display("%0t: Data harzard EX->ID(rs1:%d)", $time, rs1_addr_i);
        // WB -> ID check.
        // No need to check. WB is always forwarded.
    end
end

endmodule