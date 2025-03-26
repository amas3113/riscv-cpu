`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)

import rv32i_types::*;

module id_stage (
  // Basic signals
  input clk_i,
  input rst_i,

  // Signals from IF stage
  input rv32i_word          insn_i,
  input rv32i_word          pc_i,
  input rv32i_monitor_word  monitor_i,

  // Output signals
  output rv32i_ctrl_word    ctrlword_o,
  output rv32i_word         alu_a_o,
  output rv32i_word         alu_b_o,
  output rv32i_word         rs1_data_o,
  output rv32i_word         rs2_data_o,
  output logic [4:0]        rd_addr_o,
  output rv32i_word         i_imm_o,
  output rv32i_word         u_imm_o,
  output rv32i_word         pc_o,
  output rv32i_monitor_word monitor_o,

  // Regfile signals from WB stage
  input rv32i_word  rf_wdata_i,
  input [4:0]       rf_waddr_i,
  input rf_wen_i,   // regfile_write_en_i

  // Forwarding Unit
  input rv32i_word  fwd_rs1_data_i,
  input [4:0]       fwd_rs1_addr_i,
  input rv32i_word  fwd_rs2_data_i,
  input [4:0]       fwd_rs2_addr_i,

  // Hazard detection
  output logic [4:0]  rs1_usage,
  output logic [4:0]  rs2_usage,
  output logic [4:0]  rd_usage
);

  /* Instruction breakdown. */
  rv32i_word i_imm, u_imm, b_imm, s_imm, j_imm;
  logic [2:0] funct3;
  logic [6:0] funct7;
  rv32i_opcode opcode;
  logic [4:0] rs1_addr, rs2_addr, rd_addr;

  `define sext(imm) 32'(signed'(imm))

  always_comb begin
    funct3 = insn_i[14:12];
    funct7 = insn_i[31:25];
    opcode = rv32i_opcode'(insn_i[6:0]);

    i_imm = {{21{insn_i[31]}}, insn_i[30:20]};
    s_imm = {{21{insn_i[31]}}, insn_i[30:25], insn_i[11:7]};
    b_imm = {{20{insn_i[31]}}, insn_i[7], insn_i[30:25], insn_i[11:8], 1'b0};
    u_imm = {insn_i[31:12], 12'h000};
    j_imm = {{12{insn_i[31]}}, insn_i[19:12], insn_i[20], insn_i[30:21], 1'b0};

    rs1_addr = insn_i[19:15];
    rs2_addr = insn_i[24:20];
    rd_addr  = insn_i[11:7];

    i_imm_o = i_imm;
    u_imm_o = u_imm;

    pc_o      = pc_i;
    rd_addr_o = rd_addr;
  end

  rv32i_word raw_rs1, raw_rs2;

  regfile id_regfile(
    .clk(clk_i), .rst(rst_i),
    .load(rf_wen_i),

    /* rs1 and rs2 */
    .src_a(rs1_addr), .reg_a(raw_rs1),
    .src_b(rs2_addr), .reg_b(raw_rs2),

    /* rd */
    .dest(rf_waddr_i), .in(rf_wdata_i)
  );

  /* 
   * Forwarding Unit
   * raw_rs1 and raw_rs2 signals are the raw register values read from the regfile.
   * rs1_data_o and rs2_data_o are the register values with forwarding taken into account.
   */
  always_comb begin
    if (fwd_rs1_addr_i == rs1_addr && fwd_rs1_addr_i != 5'b00000)
      rs1_data_o = fwd_rs1_data_i;
    else if (fwd_rs2_addr_i == rs1_addr && fwd_rs2_addr_i != 5'b00000)
      rs1_data_o = fwd_rs2_data_i;
    else
      rs1_data_o = raw_rs1;
    
    if (fwd_rs1_addr_i == rs2_addr && fwd_rs1_addr_i != 5'b00000)
      rs2_data_o = fwd_rs1_data_i;
    else if (fwd_rs2_addr_i == rs2_addr && fwd_rs2_addr_i != 5'b00000)
      rs2_data_o = fwd_rs2_data_i;
    else
      rs2_data_o = raw_rs2;
  end

  /* Control ROM */
  logic rs1_is_used, rs2_is_used;
  control_rom id_ctrlrom(
    .clk(clk_i), .rst(rst_i),
    .opcode, .funct3, .funct7,
    .insn(insn_i), .pc(pc_i),

    .ctrl_word(ctrlword_o),

    .rs1_is_used, .rs2_is_used
  );

  /* ALU MUX */
  always_comb begin
    unique case(ctrlword_o.alu_sel1)
      alumux::rs1_out: alu_a_o = rs1_data_o;
      alumux::pc_out:  alu_a_o = pc_o;
      default: `BAD_MUX_SEL;
    endcase

    unique case(ctrlword_o.alu_sel2)
      alumux::i_imm:    alu_b_o = i_imm;
      alumux::u_imm:    alu_b_o = u_imm;
      alumux::b_imm:    alu_b_o = b_imm;
      alumux::s_imm:    alu_b_o = s_imm;
      alumux::j_imm:    alu_b_o = j_imm;
      alumux::rs2_out:  alu_b_o = rs2_data_o;
      default: `BAD_MUX_SEL;
    endcase
  end

  /* Generating hazard detection signals. */
  always_comb begin
    if (rs1_is_used)
      rs1_usage = rs1_addr;
    else
      rs1_usage = 5'b00000;

    if (rs2_is_used)
      rs2_usage = rs2_addr;
    else
      rs2_usage = 5'b00000;
    
    if (ctrlword_o.regfile_write)
      rd_usage = rd_addr;
    else
      rd_usage = 5'b00000;
  end

  // RVFI Signals
  always_comb begin
    monitor_o = monitor_i;
    monitor_o.rvfi_rs1_addr = rs1_usage;
    monitor_o.rvfi_rs2_addr = rs2_usage;
    monitor_o.rvfi_rs1_rdata = rs1_usage ? rs1_data_o : 0;
    monitor_o.rvfi_rs2_rdata = rs2_usage ? rs2_data_o : 0;
    monitor_o.rvfi_load_regfile = ctrlword_o.regfile_write;
    monitor_o.rvfi_rd_addr = rd_usage;
  end

endmodule
