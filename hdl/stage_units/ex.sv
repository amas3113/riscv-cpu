import rv32i_types::*;

`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)

module ex_stage (
  input clk,
  input rst,

  /* Signals from ID stage. */
  input rv32i_ctrl_word id_ctrlword,
  input rv32i_word id_alu_in0, id_alu_in1,
  input rv32i_word id_i_rs1, id_i_rs2,
  input rv32i_word id_i_imm, id_u_imm,
  input [4:0] id_i_rd_addr,
  input rv32i_word id_pc,
  input rv32i_monitor_word id_monitor_word,

  /* Forwarding outputs. */
  output logic [4:0] ex_fwd_rs_addr,
  output rv32i_word ex_fwd_rs_data,
  
  /* EX Stage outputs. */
  output rv32i_ctrl_word ex_ctrlword,
  output rv32i_word ex_i_rs2,
  output rv32i_word ex_alu_out,
  output logic ex_br_en,
  output logic [4:0] ex_rd_addr,
  output rv32i_word ex_u_imm,
  output rv32i_word ex_pc,
  output rv32i_monitor_word ex_monitor_word,

  /* Branch (Control) Harzard detection. */
  output rv32i_word if_pc_golden // The absolute correct PC for the next cycle.
);

  assign ex_ctrlword = id_ctrlword;
  assign ex_i_rs2 = id_i_rs2;
  assign ex_rd_addr = id_i_rd_addr;
  assign ex_u_imm = id_u_imm;
  assign ex_pc = id_pc;

  alu ex_alu (
    .aluop(id_ctrlword.alu_op),
    .a    (id_alu_in0),
    .b    (id_alu_in1),
    .f    (ex_alu_out)
  );

  /* CMP mux. */
  rv32i_word cmp_mux_out;
  always_comb begin
    unique case (id_ctrlword.cmpmux_sel)
      cmpmux::i_imm: begin
        cmp_mux_out = id_i_imm;
      end
      cmpmux::rs2_out: begin
        cmp_mux_out = id_i_rs2;
      end
    endcase
  end

  /* CMP unit. */
  cmp ex_cmp(
    .cmpop(id_ctrlword.cmp_op),
    .a    (id_i_rs1),
    .b    (cmp_mux_out),
    .br_en(ex_br_en)
  );

  /* Forwarding. */
  always_comb begin
    if (id_ctrlword.regfile_write == 1'b1) begin
      unique case(id_ctrlword.regfilemux_sel)
        regfilemux::alu_out: begin
          ex_fwd_rs_addr = id_i_rd_addr;
          ex_fwd_rs_data = ex_alu_out;
        end
        regfilemux::br_en: begin
          ex_fwd_rs_addr = id_i_rd_addr;
          ex_fwd_rs_data = {31'h0, ex_br_en};
        end
        regfilemux::u_imm: begin
          ex_fwd_rs_addr = id_i_rd_addr;
          ex_fwd_rs_data = id_u_imm;
        end
        regfilemux::pc_plus4: begin
          ex_fwd_rs_addr = id_i_rd_addr;
          ex_fwd_rs_data = id_pc + 4;
        end
        default: begin
          ex_fwd_rs_addr = 0;
          ex_fwd_rs_data = 0;
        end
      endcase
    end else begin
      ex_fwd_rs_addr = 0;
      ex_fwd_rs_data = 0;
    end
  end

  /* Golden next PC. */
  always_comb begin : IF_GOLDEN_PC_MUX
    unique case (id_ctrlword.pcmux_sel)
      pcmux::pc_plus4: begin
        if_pc_golden = id_pc + 4;
      end
      pcmux::alu_out: begin
        if_pc_golden = ex_alu_out;
      end
      pcmux::alu_mod2: begin
        if_pc_golden = {ex_alu_out[31:1], 1'b0}; 
      end
      pcmux::cond_branch: begin
        if (ex_br_en)
          if_pc_golden = ex_alu_out;
        else
          if_pc_golden = id_pc + 4;
      end
      default: `BAD_MUX_SEL;
    endcase
  end

// RVFI Signals
always_comb begin
  ex_monitor_word = id_monitor_word;
  ex_monitor_word.rvfi_pc_wdata = if_pc_golden;
end

endmodule
