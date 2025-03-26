import rv32i_types::*;

module if_id (
  // Control Signals
  input clk_i,
  input rst_i,
  input load_i,
  input flush_i,

  // Data Input Signals (from IF stage)
  input rv32i_word          pc_i,
  input rv32i_word          insn_i,
  input rv32i_monitor_word  monitor_i,
  input                     insn_valid_i,

  // Data Output Signals (to ID Stage)
  output rv32i_word         pc_o,
  output rv32i_word         insn_o,
  output rv32i_monitor_word monitor_o,
  output logic              insn_valid_o
);

  rv32i_word pc_write;
  assign pc_write = flush_i ? 32'hAAAAAAAA : pc_i;   // Synthesis translate_off/on
  wire rof_i = rst_i || flush_i;                     // Reset or Flush

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      pc_o            <= 0;
      insn_o          <= 0;
      insn_valid_o    <= 0;
    end else if (load_i || flush_i) begin
      pc_o            <= pc_write;
      insn_o          <= flush_i ? 0 : insn_i;
      insn_valid_o    <= flush_i ? 1'b0 : insn_valid_i;
    end
  end

rvfi_monitor_register monitor_reg (
  .clk  (clk_i),
  .rst  (rst_i),
  .flush(flush_i),
  .load (load_i),
  .in   (monitor_i),
  .out  (monitor_o)
);

endmodule : if_id
