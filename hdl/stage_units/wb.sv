import rv32i_types::*;

`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)
`define MEM_UNALIGNED $fatal("%0t %s %0d: Non-aligned memory access.", $time, `__FILE__, `__LINE__)

module wb_stage(
    input clk, rst,

    // Input from MEM stage.
    input rv32i_word mem_rdata,
    input logic mem_br_en,
    input rv32i_word mem_alu_out,
    input rv32i_ctrl_word mem_ctrlword,
    input logic [4:0] mem_rd,
    input rv32i_word mem_u_imm,
    input rv32i_word mem_pc,
    input logic data_mem_resp,
    
    // RVFI signal
    input rv32i_monitor_word mem_monitor_word, 
    input logic mem_insn_valid,
    input logic load_mem_wb,

    // Outputs.
    output logic regfile_write,      // To ID stage.
    output rv32i_word regfile_wdata, // To ID stage.
    output logic [4:0] regfile_waddr
);

always_comb begin
    if(mem_ctrlword.regfilemux_sel == regfilemux::mem_rdata)
        regfile_write = data_mem_resp;
    else
        regfile_write = mem_ctrlword.regfile_write;
end
// assign regfile_write = mem_ctrlword.regfile_write;
assign regfile_waddr = mem_rd;

/* SEXT/ZEXT logic. */
rv32i_word ext_result;

always_comb begin
    ext_result = 32'hDEADBEEF;
    unique case (mem_ctrlword.access_length)
        mem_ctrl::a_word: ext_result = mem_rdata;

        mem_ctrl::a_half: begin
            if(mem_alu_out[1:0] == 2'b00) begin
                if(mem_ctrlword.access_sign == mem_ctrl::t_unsigned)
                    ext_result = {16'h0, mem_rdata[15:0]};
                else if (mem_ctrlword.access_sign == mem_ctrl::t_signed)
                    ext_result = {{16{mem_rdata[15]}}, mem_rdata[15:0]};
                else ext_result = 32'hDEADECEB;
            end else if(mem_alu_out[1:0] == 2'b10) begin
                if(mem_ctrlword.access_sign == mem_ctrl::t_unsigned)
                    ext_result = {16'h0, mem_rdata[31:16]};
                else if (mem_ctrlword.access_sign == mem_ctrl::t_signed)
                    ext_result = {{16{mem_rdata[31]}}, mem_rdata[31:16]};
                else ext_result = 32'hDEADECEB;
            end else ext_result = 32'hDEADECEB;
        end

        mem_ctrl::a_byte: begin
            if(mem_ctrlword.access_sign == mem_ctrl::t_unsigned)
                unique case(mem_alu_out[1:0])
                    2'b00: ext_result = {24'h0, mem_rdata[7:0]};
                    2'b01: ext_result = {24'h0, mem_rdata[15:8]};
                    2'b10: ext_result = {24'h0, mem_rdata[23:16]};
                    2'b11: ext_result = {24'h0, mem_rdata[31:24]};
                    default: ext_result = 32'hDEADECEB;
                endcase
            else if(mem_ctrlword.access_sign == mem_ctrl::t_signed)
                unique case(mem_alu_out[1:0])
                    2'b00: ext_result = {{24{mem_rdata[7]}},  mem_rdata[7:0]};
                    2'b01: ext_result = {{24{mem_rdata[15]}}, mem_rdata[15:8]};
                    2'b10: ext_result = {{24{mem_rdata[23]}}, mem_rdata[23:16]};
                    2'b11: ext_result = {{24{mem_rdata[31]}}, mem_rdata[31:24]};
                    default: ext_result = 32'hDEADECEB;
                endcase
            else ext_result = 32'hDEADECEB;
        end

        default: ext_result = 32'hDEADECEB;
    endcase
end


// Regfile MUX
always_comb begin
    unique case(mem_ctrlword.regfilemux_sel)
        regfilemux::alu_out:    regfile_wdata = mem_alu_out;
        regfilemux::br_en:      regfile_wdata = {{31{1'b0}}, mem_br_en};
        regfilemux::u_imm:      regfile_wdata = mem_u_imm;
        regfilemux::pc_plus4:   regfile_wdata = mem_pc + 4;
        regfilemux::mem_rdata:  regfile_wdata = ext_result;
        default: `BAD_MUX_SEL;
    endcase
    if(mem_rd == 5'h0)
        regfile_wdata = 32'h0;
end

// RVFI Signals
rv32i_monitor_word monitor_word;
always_comb begin
    monitor_word = mem_monitor_word;

    monitor_word.rvfi_mem_rdata = mem_rdata;
    monitor_word.rvfi_rd_wdata = regfile_wdata;
    if(mem_insn_valid == 1'b0) 
        monitor_word.rvfi_commit = 1'b0;
    else if (mem_ctrlword.regfilemux_sel == regfilemux::mem_rdata)
        monitor_word.rvfi_commit = data_mem_resp;
    else 
        monitor_word.rvfi_commit = load_mem_wb;
end 

endmodule