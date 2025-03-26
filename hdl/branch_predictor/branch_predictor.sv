import rv32i_types::*;

module branch_predictor (
  input             clk_i,
  input             rst_i,
  input rv32i_word  pc_i,

  // Prediction result, output to IF
  output rv32i_word pc_pred_o,

  // EX stage feedback
  input rv32i_word  insn_pc_i,    // The address of the original instruction.
  input logic       insn_is_br_i, // whether the instruction at that address is a taken branch.
  input rv32i_word  insn_target_i // The target address of the original instruction.
);

assign pc_pred_o = pc_i + 4; // Static not-taken.

endmodule
