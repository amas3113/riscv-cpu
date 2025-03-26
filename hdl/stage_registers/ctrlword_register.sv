import rv32i_types::*;

module ctrlword_register(
  input clk,
  input rst,
  input load,
  input flush,
  input rv32i_ctrl_word in,
  output rv32i_ctrl_word out
);

rv32i_ctrl_word reg_ctrlword;

function void set_defaults();
  reg_ctrlword.branch = 1'b0;
  reg_ctrlword.pcmux_sel = pcmux::pc_plus4;
  reg_ctrlword.alu_sel1 = alumux::rs1_out;
  reg_ctrlword.alu_sel2 = alumux::i_imm;
  reg_ctrlword.alu_op = alu_add;
  reg_ctrlword.cmpmux_sel = cmpmux::rs2_out;
  reg_ctrlword.cmp_op = cmp_beq;
  reg_ctrlword.access_length = mem_ctrl::a_byte;
  reg_ctrlword.access_sign = mem_ctrl::t_signed;
  reg_ctrlword.mem_read = 1'b0;
  reg_ctrlword.mem_write = 1'b0;
  reg_ctrlword.regfilemux_sel = regfilemux::alu_out;
  reg_ctrlword.regfile_write = 1'b0;
endfunction

always_ff @(posedge clk) begin
  if (rst || flush) begin
    set_defaults();
  end else if(load) begin
    reg_ctrlword <= in;
  end else begin
    reg_ctrlword <= reg_ctrlword;
  end        
end

always_comb begin
  out = reg_ctrlword;
end

endmodule: ctrlword_register
