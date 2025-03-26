package pcmux;
typedef enum bit [1:0] {
    pc_plus4  = 2'b00
    ,alu_out  = 2'b01
    ,alu_mod2 = 2'b10
    ,cond_branch = 2'b11 // If br_en, go alu_out, otherwise go pc_plus4
} pcmux_sel_t;
endpackage

package marmux;
typedef enum bit {
    pc_out = 1'b0
    ,alu_out = 1'b1
} marmux_sel_t;
endpackage

package cmpmux;
typedef enum bit {
    rs2_out = 1'b0
    ,i_imm = 1'b1
} cmpmux_sel_t;
endpackage

package alumux;
typedef enum bit {
    rs1_out = 1'b0
    ,pc_out = 1'b1
} alumux1_sel_t;

typedef enum bit [2:0] {
    i_imm    = 3'b000
    ,u_imm   = 3'b001
    ,b_imm   = 3'b010
    ,s_imm   = 3'b011
    ,j_imm   = 3'b100
    ,rs2_out = 3'b101
} alumux2_sel_t;
endpackage

package regfilemux;
typedef enum bit [2:0] {
    alu_out    = 3'b000
    ,br_en     = 3'b001
    ,u_imm     = 3'b010
    ,mem_rdata = 3'b011
    ,pc_plus4  = 3'b100
} regfilemux_sel_t;
endpackage

package mem_ctrl;
typedef enum bit [1:0] {
    a_byte = 2'b00,
    a_half = 2'b01,
    a_word = 2'b10
} mem_length_sel_t;

typedef enum bit {
    t_signed = 1'b0,
    t_unsigned = 1'b1
} mem_sign_sel_t;
endpackage