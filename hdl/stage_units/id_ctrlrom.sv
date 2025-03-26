import rv32i_types::*;

`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)

module control_rom(
    input clk, rst,

    /* Core signals. */
    input rv32i_opcode opcode,
    input logic [6:0] funct7,
    input logic [2:0] funct3,

    /* Purely for debugging. */
    input rv32i_word insn,
    input rv32i_word pc,

    output rv32i_ctrl_word ctrl_word,

    /* For hazard detection. */
    output logic rs1_is_used,
    output logic rs2_is_used
);

assign ctrl_word.insn = insn;
assign ctrl_word.pc = pc;
assign ctrl_word.funct7 = funct7;
assign ctrl_word.funct3 = funct3;

function void set_defaults();
    ctrl_word.branch = 1'b0;
    ctrl_word.pcmux_sel = pcmux::pc_plus4;
    
    ctrl_word.alu_sel1 = alumux::rs1_out;
    ctrl_word.alu_sel2 = alumux::i_imm;
    ctrl_word.alu_op = alu_add;

    ctrl_word.cmpmux_sel = cmpmux::rs2_out;
    ctrl_word.cmp_op = cmp_beq;

    ctrl_word.access_length = mem_ctrl::a_byte;
    ctrl_word.access_sign = mem_ctrl::t_signed;
    ctrl_word.mem_read = 1'b0;
    ctrl_word.mem_write = 1'b0;

    ctrl_word.regfilemux_sel = regfilemux::alu_out;
    ctrl_word.regfile_write = 1'b0;

    rs1_is_used = 1'b0;
    rs2_is_used = 1'b0;
endfunction

function void set_regfile(input regfilemux::regfilemux_sel_t regfilemux_sel);
    ctrl_word.regfile_write = 1'b1;
    ctrl_word.regfilemux_sel = regfilemux_sel;
endfunction

function void set_branch(input pcmux::pcmux_sel_t pcmux_sel);
    ctrl_word.pcmux_sel = pcmux_sel;
    ctrl_word.branch = 1'b1;
endfunction

function void set_alu(
    input alu_ops alu_op,
    input alumux::alumux1_sel_t sel1, 
    input alumux::alumux2_sel_t sel2    
);
    ctrl_word.alu_sel1 = sel1;
    ctrl_word.alu_sel2 = sel2;
    ctrl_word.alu_op = alu_op;
endfunction

function void set_cmp(
    input cmp_ops cmp_op,
    input cmpmux::cmpmux_sel_t sel2
);
    ctrl_word.cmp_op = cmp_op;
    ctrl_word.cmpmux_sel = sel2;
endfunction

function void set_mread(
    input load_funct3_t m_funct3
);
    ctrl_word.mem_read = 1'b1;
    unique case(m_funct3)
        lb: begin
            ctrl_word.access_length = mem_ctrl::a_byte;
            ctrl_word.access_sign   = mem_ctrl::t_signed;
        end
        lh: begin
            ctrl_word.access_length = mem_ctrl::a_half;
            ctrl_word.access_sign   = mem_ctrl::t_signed;
        end
        lw: begin
            ctrl_word.access_length = mem_ctrl::a_word;
            ctrl_word.access_sign   = mem_ctrl::t_signed;
        end
        lbu: begin
            ctrl_word.access_length = mem_ctrl::a_byte;
            ctrl_word.access_sign   = mem_ctrl::t_unsigned;
        end
        lhu: begin
            ctrl_word.access_length = mem_ctrl::a_half;
            ctrl_word.access_sign   = mem_ctrl::t_unsigned;
        end
        default: `BAD_MUX_SEL;
    endcase
endfunction

function void set_mwrite(
    input store_funct3_t m_funct3
);
    ctrl_word.mem_write = 1'b1;
    unique case(m_funct3)
        sb: begin
            ctrl_word.access_length = mem_ctrl::a_byte;
            ctrl_word.access_sign   = mem_ctrl::t_unsigned;
        end
        sh: begin
            ctrl_word.access_length = mem_ctrl::a_half;
            ctrl_word.access_sign   = mem_ctrl::t_unsigned;
        end
        sw: begin
            ctrl_word.access_length = mem_ctrl::a_word;
            ctrl_word.access_sign   = mem_ctrl::t_unsigned;
        end
        default: `BAD_MUX_SEL;
    endcase
endfunction

always_comb begin
    set_defaults();
    unique case(opcode)
        op_lui: begin
            set_regfile(regfilemux::u_imm);
        end

        op_auipc: begin
            set_alu(alu_add, alumux::pc_out, alumux::u_imm);
            set_regfile(regfilemux::alu_out);
        end

        op_jal: begin
            set_alu(alu_add, alumux::pc_out, alumux::j_imm);
            set_cmp(cmp_jmp, cmpmux::rs2_out);
            set_regfile(regfilemux::pc_plus4);
            set_branch(pcmux::alu_out);
        end

        op_jalr: begin
            set_alu(alu_add, alumux::rs1_out, alumux::i_imm);
            set_cmp(cmp_jmp, cmpmux::rs2_out);
            set_regfile(regfilemux::pc_plus4);
            set_branch(pcmux::alu_mod2);
            rs1_is_used = 1'b1;
        end

        op_br: begin
            set_alu(alu_add, alumux::pc_out, alumux::b_imm);
            set_cmp(cmp_ops'(funct3), cmpmux::rs2_out);
            set_branch(pcmux::cond_branch);
            rs1_is_used = 1'b1;
            rs2_is_used = 1'b1;
        end

        op_load: begin
            set_alu(alu_add, alumux::rs1_out, alumux::i_imm);
            set_regfile(regfilemux::mem_rdata);
            set_mread(load_funct3_t'(funct3));
            rs1_is_used = 1'b1;
        end

        op_store: begin
            set_alu(alu_add, alumux::rs1_out, alumux::s_imm);
            set_mwrite(store_funct3_t'(funct3));
            rs1_is_used = 1'b1;
            rs2_is_used = 1'b1;
        end

        op_imm: begin
            rs1_is_used = 1'b1;
            case(arith_funct3_t'(funct3))
                slt: begin
                    set_cmp(cmp_blt, cmpmux::i_imm);
                    set_regfile(regfilemux::br_en);
                end
                sltu: begin
                    set_cmp(cmp_bltu, cmpmux::i_imm);
                    set_regfile(regfilemux::br_en);
                end
                sr: begin
                    set_regfile(regfilemux::alu_out);
                    if(funct7 == 7'b0100000) begin
                        set_alu(alu_sra, alumux::rs1_out, alumux::i_imm);
                    end else begin
                        set_alu(alu_ops'(funct3), alumux::rs1_out, alumux::i_imm);
                    end
                end
                default: begin
                    set_alu(alu_ops'(funct3), alumux::rs1_out, alumux::i_imm);
                    set_regfile(regfilemux::alu_out);
                end
            endcase
        end

        op_reg: begin
            rs1_is_used = 1'b1;
            rs2_is_used = 1'b1;
            case(arith_funct3_t'(funct3))
                slt: begin
                    set_cmp(cmp_blt, cmpmux::rs2_out);
                    set_regfile(regfilemux::br_en);
                end
                sltu: begin
                    set_cmp(cmp_bltu, cmpmux::rs2_out);
                    set_regfile(regfilemux::br_en);
                end
                sr: begin
                    set_regfile(regfilemux::alu_out);
                    if(funct7 == 7'b0100000) begin
                        set_alu(alu_sra, alumux::rs1_out, alumux::rs2_out);
                    end else begin
                        set_alu(alu_ops'(funct3), alumux::rs1_out, alumux::rs2_out);
                    end
                end
                add: begin
                    set_regfile(regfilemux::alu_out);
                    if(funct7 == 7'b0100000) begin
                        set_alu(alu_sub, alumux::rs1_out, alumux::rs2_out);
                    end else begin
                        set_alu(alu_ops'(funct3), alumux::rs1_out, alumux::rs2_out);
                    end
                end
                default: begin
                    set_alu(alu_ops'(funct3), alumux::rs1_out, alumux::rs2_out);
                    set_regfile(regfilemux::alu_out);
                end
            endcase
        end

        default: set_defaults();
    endcase
end

endmodule