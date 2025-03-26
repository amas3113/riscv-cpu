import rv32i_types::*;

module rvfi_monitor_register(
  input clk,
  input rst,
  input load,
  input flush,
  input rv32i_monitor_word in,
  output rv32i_monitor_word out
);

  rv32i_monitor_word reg_monitor_word;

  function void set_defaults();
    // Instruction and Trap:
    reg_monitor_word.rvfi_inst = 32'b0;
    reg_monitor_word.rvfi_trap = 1'b0;

    // Regfile:
    reg_monitor_word.rvfi_rs1_addr = 5'b0;
    reg_monitor_word.rvfi_rs2_addr = 5'b0;
    reg_monitor_word.rvfi_rs1_rdata = 32'b0;
    reg_monitor_word.rvfi_rs2_rdata = 32'b0;
    reg_monitor_word.rvfi_load_regfile = 1'b0;
    reg_monitor_word.rvfi_rd_addr = 5'b0;
    reg_monitor_word.rvfi_rd_wdata = 32'b0;

    // PC:
    reg_monitor_word.rvfi_pc_rdata = 32'b0;
    reg_monitor_word.rvfi_pc_wdata = 32'b0;

    // Memory:
    reg_monitor_word.rvfi_mem_addr = 32'b0;
    reg_monitor_word.rvfi_mem_rmask = 4'b1111;
    reg_monitor_word.rvfi_mem_wmask = 4'b1111;
    reg_monitor_word.rvfi_mem_rdata = 32'b0;
    reg_monitor_word.rvfi_mem_wdata = 32'b0;
  endfunction

  always_ff @(posedge clk) begin
    if (rst || flush) begin
      set_defaults();
    end else if(load) begin
      reg_monitor_word <= in;
    end else begin
      reg_monitor_word <= reg_monitor_word;
    end        
  end

  always_comb begin
    out = reg_monitor_word;
  end

endmodule: rvfi_monitor_register
