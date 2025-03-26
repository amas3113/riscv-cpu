package rv32i_types;
// Mux types are in their own packages to prevent identiier collisions
// e.g. pcmux::pc_plus4 and regfilemux::pc_plus4 are seperate identifiers
// for seperate enumerated types
import pcmux::*;
import marmux::*;
import cmpmux::*;
import alumux::*;
import regfilemux::*;

typedef logic [31:0] rv32i_word;
typedef logic [4:0] rv32i_reg;
typedef logic [3:0] rv32i_mem_wmask;

typedef enum bit [6:0] {
    op_lui   = 7'b0110111, //load upper immediate (U type)
    op_auipc = 7'b0010111, //add upper immediate PC (U type)
    op_jal   = 7'b1101111, //jump and link (J type)
    op_jalr  = 7'b1100111, //jump and link register (I type)
    op_br    = 7'b1100011, //branch (B type)
    op_load  = 7'b0000011, //load (I type)
    op_store = 7'b0100011, //store (S type)
    op_imm   = 7'b0010011, //arith ops with register/immediate operands (I type)
    op_reg   = 7'b0110011, //arith ops with register operands (R type)
    op_csr   = 7'b1110011  //control and status register (I type)
} rv32i_opcode;

typedef enum bit [2:0] {
    beq  = 3'b000,
    bne  = 3'b001,
    blt  = 3'b100,
    bge  = 3'b101,
    bltu = 3'b110,
    bgeu = 3'b111
} branch_funct3_t;

typedef enum bit [2:0] {
    lb  = 3'b000,
    lh  = 3'b001,
    lw  = 3'b010,
    lbu = 3'b100,
    lhu = 3'b101
} load_funct3_t;

typedef enum bit [2:0] {
    sb = 3'b000,
    sh = 3'b001,
    sw = 3'b010
} store_funct3_t;

typedef enum bit [2:0] {
    add  = 3'b000, //check bit30 for sub if op_reg opcode
    sll  = 3'b001,
    slt  = 3'b010,
    sltu = 3'b011,
    axor = 3'b100,
    sr   = 3'b101, //check bit30 for logical/arithmetic
    aor  = 3'b110,
    aand = 3'b111
} arith_funct3_t;

typedef enum bit [2:0] {
    alu_add = 3'b000,
    alu_sll = 3'b001,
    alu_sra = 3'b010,
    alu_sub = 3'b011,
    alu_xor = 3'b100,
    alu_srl = 3'b101,
    alu_or  = 3'b110,
    alu_and = 3'b111
} alu_ops;

typedef enum bit [2:0] {
	cmp_beq  = 3'b000,
	cmp_bne  = 3'b001,
	cmp_blt  = 3'b100,
	cmp_bltu = 3'b110,
	cmp_bge  = 3'b101,
	cmp_bgeu = 3'b111,
	cmp_jmp  = 3'b010,
	cmp_njp  = 3'b011
} cmp_ops;

typedef struct {
    // EX stage
    logic branch;
    pcmux::pcmux_sel_t    pcmux_sel;

    alumux::alumux1_sel_t alu_sel1;
    alumux::alumux2_sel_t alu_sel2;
    rv32i_types::alu_ops  alu_op;

    cmpmux::cmpmux_sel_t  cmpmux_sel;
    rv32i_types::cmp_ops  cmp_op;

    // MEM stage
    mem_ctrl::mem_length_sel_t access_length;
    mem_ctrl::mem_sign_sel_t   access_sign;
    logic mem_read;
    logic mem_write;

    // WB stage
    regfilemux::regfilemux_sel_t regfilemux_sel;
    logic regfile_write;

    // For debugging purposes
    rv32i_word insn; // Current instruction.
    rv32i_word pc;   // Current PC
    rv32i_word funct3; // funct3
    rv32i_word funct7; // funct7
} rv32i_ctrl_word;

typedef struct packed {
// Instruction, Trap, Commit:
    logic [31:0]    rvfi_inst;
    logic           rvfi_trap;
    logic           rvfi_commit;

// Regfile:
    logic [4:0]     rvfi_rs1_addr;
    logic [4:0]     rvfi_rs2_addr;
    logic [31:0]    rvfi_rs1_rdata;
    logic [31:0]    rvfi_rs2_rdata;
    logic           rvfi_load_regfile;
    logic [4:0]     rvfi_rd_addr;
    logic [31:0]    rvfi_rd_wdata;

// PC:
    logic [31:0]    rvfi_pc_rdata;
    logic [31:0]    rvfi_pc_wdata;

// Memory:
    logic [31:0]    rvfi_mem_addr;
    logic [3:0]     rvfi_mem_rmask;
    logic [3:0]     rvfi_mem_wmask;
    logic [31:0]    rvfi_mem_rdata;
    logic [31:0]    rvfi_mem_wdata;
} rv32i_monitor_word;

endpackage : rv32i_types

