import rv32i_types::*;

module id_ex (
  // Control Signals
  input clk_i,
  input rst_i,
  input load_i,
  input flush_i,

  // Data Input Signals (from ID stage)
  input rv32i_ctrl_word       ctrlword_i,
  input rv32i_word            rs1_data_i,
  input rv32i_word            rs2_data_i,
  input rv32i_word            alu_a_i,
  input rv32i_word            alu_b_i,
  input [4:0]                 rd_addr_i,
  input rv32i_word            i_imm_i,
  input rv32i_word            u_imm_i,
  input rv32i_word            pc_i,
  input rv32i_monitor_word    monitor_i,
  input                       insn_valid_i,

  // Data Output Signals (to EX stage)
  output rv32i_ctrl_word      ctrlword_o,
  output rv32i_word           rs1_data_o,
  output rv32i_word           rs2_data_o,
  output rv32i_word           alu_a_o,
  output rv32i_word           alu_b_o,
  output logic [4:0]          rd_addr_o,
  output rv32i_word           i_imm_o,
  output rv32i_word           u_imm_o,
  output rv32i_word           pc_o,
  output rv32i_monitor_word   monitor_o,
  output logic                insn_valid_o
);

ctrlword_register ctrlword_reg (
  .clk  (clk_i),
  .rst  (rst_i),
  .load (load_i),
  .flush(flush_i),
  .in   (ctrlword_i),
  .out  (ctrlword_o)
);

rvfi_monitor_register monitor_reg (
  .clk  (clk_i),
  .rst  (rst_i),
  .flush(flush_i),
  .load (load_i),
  .in   (monitor_i),
  .out  (monitor_o)
);

always_ff @(posedge clk_i) begin
  if (rst_i) begin
    rs1_data_o    <= 0;
    rs2_data_o    <= 0;
    alu_a_o       <= 0;
    alu_b_o       <= 0;
    rd_addr_o     <= 0;
    i_imm_o       <= 0;
    u_imm_o       <= 0;
    pc_o          <= 0;
    insn_valid_o  <= 0;
  end else if (load_i || flush_i) begin
    rs1_data_o    <= rs1_data_i;
    rs2_data_o    <= rs2_data_i;
    alu_a_o       <= alu_a_i;
    alu_b_o       <= alu_b_i;
    rd_addr_o     <= flush_i ? 5'h0 : rd_addr_i;
    i_imm_o       <= i_imm_i;
    u_imm_o       <= u_imm_i;
    pc_o          <= flush_i ? 32'h0 : pc_i;   // Synthesis translate_off/on
    insn_valid_o  <= flush_i ? 1'b0 : insn_valid_i;      // Reset or Flush
  end
end

endmodule : id_ex
