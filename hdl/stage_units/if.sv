`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)

import rv32i_types::*;

module if_stage (
    input logic         clk_i,
    input logic         rst_i,
    input logic         ld_if_i,    // currently unused
    input logic         ld_pc_i,
    input logic         br_en_i,    // currently unused
	input rv32i_word    alu_f_i,    // currently unused

    // Memory interface
    input logic         imem_resp_i,
    input rv32i_word    imem_rdata_i,

    output rv32i_word   imem_addr_o,
    output logic        imem_read_o,
    output logic        imem_write_o,
    output rv32i_word   imem_wdata_o,
    output logic [3:0]  imem_byte_en_o,

    // Pipeline control
    input logic         pc_pred_ok_i,   // Is pc_pred correct?
    input rv32i_word    pc_gold_i,      // Golden pc value (should never be wrong)

    // Connection to IF/ID stage
    output rv32i_word           pc_o,
    output rv32i_word           insn_o,
    output rv32i_monitor_word   monitor_o,

    // Branch Predictor update signals
    input rv32i_word    insn_pc_i,
    input logic         insn_is_br_i,
    input rv32i_word    insn_target_i,

    // For hazard control use
    output logic        insn_rdy_o // Possibly redundant signal
);

rv32i_word pcmux_out;
rv32i_word pc_pred;

assign pcmux_out        = pc_pred_ok_i ? pc_pred : pc_gold_i;    // pc_mux

assign imem_addr_o      = pc_o;
assign imem_write_o     = 1'b0;
assign imem_wdata_o     = 32'h00000000;
assign imem_byte_en_o   = 4'b1111;

pc_register pc_reg (
    .clk  (clk_i),
    .rst  (rst_i),
    .load (ld_pc_i),
    .in   (pcmux_out),
    .out  (pc_o)
);

branch_predictor if_branch_predictor (
    .clk_i,
    .rst_i,
    .pc_i           (pc_o),
    .pc_pred_o      (pc_pred),
    .insn_pc_i      (insn_pc_i),
    .insn_is_br_i   (insn_is_br_i),
    .insn_target_i  (insn_target_i)
);

// RVFI Signals
always_comb begin
    monitor_o = '0;

    monitor_o.rvfi_inst         = insn_o;
    monitor_o.rvfi_pc_rdata     = pc_o;
    monitor_o.rvfi_mem_rmask    = 4'b1111;
    monitor_o.rvfi_mem_wmask    = 4'b1111;
end

// Memory Exchange FSM
enum bit {IDLE, LOADING} state, next_state;

function void set_defaults();
    insn_o      = imem_resp_i ? imem_rdata_i : 32'h00000000;
    imem_read_o = rst_i ? 1'b0 : 1'b1;
    insn_rdy_o  = imem_resp_i;
    next_state  = LOADING;
endfunction

always @(posedge clk_i) begin
    if (rst_i)  state <= IDLE;
    else        state <= next_state;
end

always_comb begin
    set_defaults();
    
    unique case (state)
        IDLE:       ;   // currently, do nothing
        LOADING:    ;   // currently, do nothing
        default:    `BAD_MUX_SEL;
    endcase
end

endmodule
