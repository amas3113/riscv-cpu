import rv32i_types::*;

`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)

module mp4 (
    input clk,
    input rst,

    // Physical memory connection.
    input logic             pmem_resp,
    input logic [63:0]      pmem_rdata,
    output logic [31:0]     pmem_address,
    output logic [63:0]     pmem_wdata,
    output logic            pmem_read,
    output logic            pmem_write
);

//  +--------------------------------------------------------------------+
//  |                                                                    |
//  |                               Memory                               |
//  |                                                                    |
//  +--------------------------------------------------------------------+

rv32i_word  instr_mem_addr;
logic       instr_mem_read;
logic       instr_mem_write;
logic       instr_mem_resp;
rv32i_word  instr_mem_rdata;
rv32i_word  instr_mem_wdata;
logic [3:0] instr_mem_byte_enable;

rv32i_word  data_mem_addr;
logic       data_mem_read;
logic       data_mem_write;
logic       data_mem_resp;
rv32i_word  data_mem_rdata;
rv32i_word  data_mem_wdata;
logic [3:0] data_mem_byte_enable;

mem_arbitrator mem_bus(
    .clk, .rst,

    /* IF port. */
    .instr_mem_read, .instr_mem_write, .instr_mem_addr, .instr_mem_wdata,
    .instr_mem_byte_enable, .instr_mem_rdata, .instr_mem_resp,

    /* MEM port. */
    .data_mem_read, .data_mem_write, .data_mem_addr, .data_mem_wdata, 
    .data_mem_byte_enable, .data_mem_rdata, .data_mem_resp,
    
    /* Physical memory port. */
    .pmem_resp, .pmem_rdata, .pmem_address, .pmem_wdata, .pmem_read, .pmem_write
);

/* Signals provided by the hazard detection unit. */
logic ld_if, ld_id, ld_ex, ld_mem, ld_pc;
logic flush_if_id, flush_id_ex, flush_ex_mem, flush_mem_wb;


//  +--------------------------------------------------------------------+
//  |                                                                    |
//  |                              IF stage                              |
//  |                                                                    |
//  +--------------------------------------------------------------------+

logic br_en;                  // Comes from EX stage.
pcmux::pcmux_sel_t pcmux_sel; // Comes from EX stage control word.
rv32i_word alu_out;           // Comes from EX stage.

// Outputs of the IF stage.
rv32i_word if_pc, if_insn;
rv32i_monitor_word if_monitor_word_o;

// Signals for hazard detection unit.
logic if_instr_ready;

// Signals from harzard detection for pipeline control.
rv32i_word if_pc_golden; // Golden next PC. Comes from EX stage.
rv32i_word id_pc_in;     // Next PC, the output of IF/ID interconnect.
logic if_pc_correct;     // If the above two values match. If not, branch prediction failure occured.

// Signals for updating the branch prediction unit. Comes from EX stage.
rv32i_word if_btb_instr_pc;
logic if_btb_instr_is_branch;
rv32i_word if_btb_instr_target;

if_stage cpu_if (
    // 
    .clk_i          (clk),
    .rst_i          (rst),
    .ld_if_i        (ld_if),
    .ld_pc_i        (ld_pc),
    .br_en_i        (br_en),
    .alu_f_i        (alu_out),

    // Memory interface
    .imem_resp_i    (instr_mem_resp),
    .imem_rdata_i   (instr_mem_rdata),

    .imem_addr_o    (instr_mem_addr),
    .imem_read_o    (instr_mem_read),
    .imem_write_o   (instr_mem_write),
    .imem_wdata_o   (instr_mem_wdata),
    .imem_byte_en_o (instr_mem_byte_enable),

    // Pipeline control
    .pc_pred_ok_i   (if_pc_correct),
    .pc_gold_i      (if_pc_golden),

    // Connnection to IF/ID stage
    .pc_o           (if_pc),
    .insn_o         (if_insn),
    .monitor_o      (if_monitor_word_o),

    // Branch predictor update signals
    .insn_pc_i      (if_btb_instr_pc),
    .insn_is_br_i   (if_btb_instr_is_branch),
    .insn_target_i  (if_btb_instr_target),

    // For hazard control use
    .insn_rdy_o     (if_instr_ready)
);

/* IF-ID interconnect. */
rv32i_word id_insn_in;                      // Instruction word. From IF-ID interconnect to ID.
rv32i_monitor_word if_id_monitor_word_o;    // Monitor word. From IF-ID interconnect to ID.
logic if_id_valid_instruction;              // Whether the IF-ID stage contains a valid instruction.

if_id cpu_if_id (
    // Control Signals
    .clk_i          (clk),
    .rst_i          (rst),
    .load_i         (ld_if),
    .flush_i        (flush_if_id),
    
    // Data Input Signals
    .pc_i           (if_pc),
    .insn_i         (if_insn),
    .monitor_i      (if_monitor_word_o),
    .insn_valid_i   (if_instr_ready),

    // Data Output Signals
    .pc_o           (id_pc_in),
    .insn_o         (id_insn_in),
    .monitor_o      (if_id_monitor_word_o),
    .insn_valid_o   (if_id_valid_instruction)
);


//  +--------------------------------------------------------------------+
//  |                                                                    |
//  |                              ID stage                              |
//  |                                                                    |
//  +--------------------------------------------------------------------+

/**** ID stage input signals. ****/
rv32i_word regwrite_data;    // Comes from WB stage.
logic [4:0] regwrite_addr;   // Comes from WB stage.
logic regfile_write;         // Comes from WB stage.

logic [4:0] fwd_rs1_addr;    // Forwarding from EX stage.
rv32i_word fwd_rs1;          // Forwarding from EX stage.

logic [4:0] fwd_rs2_addr;    // Forwarding from MEM stage.
rv32i_word fwd_rs2;          // Forwarding from MEM stage.

/**** ID stage output signals. ****/
rv32i_ctrl_word id_ctrlword;
rv32i_word id_alu_in0;
rv32i_word id_alu_in1;
rv32i_word id_i_rs1;
rv32i_word id_i_rs2;
logic [4:0] id_i_rd_addr;
rv32i_word id_i_imm;
rv32i_word id_u_imm;
rv32i_word id_pc;
rv32i_monitor_word id_monitor_word_o;

/**** ID stage hazard detection signals. ****/
logic [4:0] id_rs1_usage, id_rs2_usage, id_rd_usage;

id_stage cpu_id (
    .clk_i          (clk),
    .rst_i          (rst),

    /* Signals from IF stage */
    .pc_i           (id_pc_in),
    .insn_i         (id_insn_in),

    /* WB regfile write signals */
    .rf_wdata_i     (regwrite_data),
    .rf_waddr_i     (regwrite_addr),
    .rf_wen_i       (regfile_write),

    /* Forwarding signals. */
    .fwd_rs1_addr_i (fwd_rs1_addr),
    .fwd_rs1_data_i (fwd_rs1),
    .fwd_rs2_addr_i (fwd_rs2_addr),
    .fwd_rs2_data_i (fwd_rs2),

    /* Output signals. */
    .ctrlword_o     (id_ctrlword), 
    .alu_a_o        (id_alu_in0),
    .alu_b_o        (id_alu_in1), 
    .rs1_data_o     (id_i_rs1),
    .rs2_data_o     (id_i_rs2),
    .rd_addr_o      (id_i_rd_addr), 
    .i_imm_o        (id_i_imm),
    .u_imm_o        (id_u_imm), 
    .pc_o           (id_pc),

    /* Hazard detection signals. */
    .rs1_usage      (id_rs1_usage),
    .rs2_usage      (id_rs2_usage),
    .rd_usage       (id_rd_usage),

    // RVFI
    .monitor_i      (if_id_monitor_word_o),
    .monitor_o      (id_monitor_word_o)
);

/* ID-EX interconnect */
/***** EX stage input signals. *****/
rv32i_ctrl_word id_ex_ctrlword;
rv32i_word id_ex_alu_in0, id_ex_alu_in1;
rv32i_word id_ex_rs1, id_ex_rs2;
rv32i_word id_ex_i_imm, id_ex_u_imm;
logic [4:0] id_ex_rd_addr;
rv32i_word id_ex_pc;
rv32i_monitor_word id_ex_monitor_word_o;
logic id_ex_valid_instruction;

id_ex cpu_id_ex (
    // Control Signals
    .clk_i          (clk),
    .rst_i          (rst),
    .load_i         (ld_id),
    .flush_i        (flush_id_ex),

    // Data Input Signals
    .ctrlword_i     (id_ctrlword),
    .rs1_data_i     (id_i_rs1),
    .rs2_data_i     (id_i_rs2),
    .alu_a_i        (id_alu_in0),
    .alu_b_i        (id_alu_in1),
    .rd_addr_i      (id_i_rd_addr),
    .i_imm_i        (id_i_imm),
    .u_imm_i        (id_u_imm),
    .pc_i           (id_pc),
    .monitor_i      (id_monitor_word_o),
    .insn_valid_i   (if_id_valid_instruction),

    // Data Output Signals
    .ctrlword_o     (id_ex_ctrlword),
    .rs1_data_o     (id_ex_rs1),
    .rs2_data_o     (id_ex_rs2),
    .alu_a_o        (id_ex_alu_in0),
    .alu_b_o        (id_ex_alu_in1),
    .rd_addr_o      (id_ex_rd_addr),
    .i_imm_o        (id_ex_i_imm),
    .u_imm_o        (id_ex_u_imm),
    .pc_o           (id_ex_pc),
    .monitor_o      (id_ex_monitor_word_o),
    .insn_valid_o   (id_ex_valid_instruction)
);

//  +--------------------------------------------------------------------+
//  |                                                                    |
//  |                              EX stage                              |
//  |                                                                    |
//  +--------------------------------------------------------------------+

/***** EX Stage outputs *****/
rv32i_word ex_i_rs2;
rv32i_word ex_alu_out;
logic ex_br_en;
logic [4:0] ex_rd_addr;
rv32i_word ex_u_imm;
rv32i_word ex_pc;
rv32i_ctrl_word ex_ctrlword;
rv32i_monitor_word ex_monitor_word_o;

/***** EX Stage branch harzard detection *****/
ex_stage cpu_ex(
    .clk, .rst,

    /* Inputs from interstage. */
    .id_ctrlword(id_ex_ctrlword),
    .id_alu_in0(id_ex_alu_in0),
    .id_alu_in1(id_ex_alu_in1),
    .id_i_rs1(id_ex_rs1),
    .id_i_rs2(id_ex_rs2),
    .id_i_imm(id_ex_i_imm),
    .id_u_imm(id_ex_u_imm),
    .id_i_rd_addr(id_ex_rd_addr),
    .id_pc(id_ex_pc),
    .id_monitor_word(id_ex_monitor_word_o),

    /* Forwarding. */
    .ex_fwd_rs_addr(fwd_rs1_addr),
    .ex_fwd_rs_data(fwd_rs1),

    /* Branch (Control) Harzard detection. */
    .if_pc_golden,

    /* Outputs */
    .ex_ctrlword, .ex_i_rs2, .ex_alu_out, .ex_br_en, .ex_rd_addr, .ex_u_imm, .ex_pc, .ex_monitor_word(ex_monitor_word_o)
);

assign br_en = ex_br_en;
assign pcmux_sel = id_ex_ctrlword.pcmux_sel;
assign alu_out = ex_alu_out;

/* EX-IF Branch Prediction table update signals. */
assign if_btb_instr_pc = id_ex_pc;
assign if_btb_instr_is_branch = (if_pc_golden != id_ex_pc + 4);
assign if_btb_instr_target = if_pc_golden;

/* EX-MEM interconnect */
/***** MEM stage input signals. *****/
rv32i_ctrl_word ex_mem_ctrlword;
rv32i_word ex_mem_rs2, ex_mem_alu_out;
logic ex_mem_br_en;
logic [4:0] ex_mem_rd_addr;
rv32i_word ex_mem_u_imm, ex_mem_pc;
rv32i_monitor_word ex_mem_monitor_word_o;

/***** EX-MEM pipeline monitoring. *****/
logic ex_mem_valid_instruction;

ex_mem cpu_ex_mem(
    // Control Signals
    .clk_i          (clk),
    .rst_i          (rst),
    .load_i         (ld_ex),
    .flush_i        (flush_ex_mem),

    // Data Input Signals
    .ctrlword_i     (ex_ctrlword),
    .rs2_data_i     (ex_i_rs2),
    .alu_f_i        (ex_alu_out),
    .br_en_i        (ex_br_en),
    .rd_addr_i      (ex_rd_addr),
    .u_imm_i        (ex_u_imm),
    .pc_i           (ex_pc),
    .monitor_i      (ex_monitor_word_o),
    .insn_valid_i   (id_ex_valid_instruction),

    // Data Output Signals
    .ctrlword_o     (ex_mem_ctrlword),
    .rs2_data_o     (ex_mem_rs2),
    .alu_f_o        (ex_mem_alu_out),
    .br_en_o        (ex_mem_br_en),
    .rd_addr_o      (ex_mem_rd_addr),
    .u_imm_o        (ex_mem_u_imm),
    .pc_o           (ex_mem_pc),
    .monitor_o      (ex_mem_monitor_word_o),
    .insn_valid_o   (ex_mem_valid_instruction)
);

//  +--------------------------------------------------------------------+
//  |                                                                    |
//  |                              MEM stage                             |
//  |                                                                    |
//  +--------------------------------------------------------------------+

/***** MEM stage output signals *****/
rv32i_word mem_rdata;
logic mem_br_en;
rv32i_word mem_alu_out;
rv32i_ctrl_word mem_ctrlword;
logic [4:0] mem_rd_addr;
rv32i_word mem_u_imm, mem_pc;
rv32i_monitor_word mem_monitor_word_o;

mem_stage cpu_mem(
    .clk, .rst,
    .ex_ctrlword(ex_mem_ctrlword),
    .ex_rs2(ex_mem_rs2),
    .ex_alu_out(ex_mem_alu_out),
    .ex_u_imm(ex_mem_u_imm),
    .ex_pc(ex_mem_pc),
    .ex_br_en(ex_mem_br_en),
    .ex_rd_addr(ex_mem_rd_addr),
    .ex_monitor_word(ex_mem_monitor_word_o),

    .data_mem_addr, .data_mem_read, .data_mem_write,
    .data_mem_wdata, .data_mem_rdata,
    .data_mem_byte_enable,
    .data_mem_resp,

    .mem_fwd_rs_addr(fwd_rs2_addr),
    .mem_fwd_rs_data(fwd_rs2),

    .mem_rdata, .mem_br_en, .mem_alu_out, .mem_ctrlword, .mem_rd_addr, .mem_u_imm, .mem_pc, .mem_monitor_word(mem_monitor_word_o)
);

/* MEM-WB interconnect. */
/***** WB stage input signals. *****/
rv32i_ctrl_word mem_wb_ctrlword;
rv32i_word mem_wb_rdata;
rv32i_word mem_wb_alu_out;
logic mem_wb_br_en;
logic [4:0] mem_wb_rd_addr;
rv32i_word mem_wb_u_imm, mem_wb_pc;
logic mem_wb_valid_instruction;
rv32i_monitor_word mem_wb_monitor_word_o;

mem_wb cpu_mem_wb(
    // Control Signals
    .clk_i          (clk),
    .rst_i          (rst),
    .load_i         (ld_mem),
    .flush_i        (flush_mem_wb),

    // Data Input Signals
    .ctrlword_i     (mem_ctrlword),
    .rdata_i        (mem_rdata),
    .alu_f_i        (mem_alu_out),
    .br_en_i        (mem_br_en),
    .rd_addr_i      (mem_rd_addr),
    .u_imm_i        (mem_u_imm),
    .pc_i           (mem_pc),
    .monitor_i      (mem_monitor_word_o),
    .insn_valid_i   (ex_mem_valid_instruction),

    // Data Output Signals
    .ctrlword_o     (mem_wb_ctrlword),
    .rdata_o        (mem_wb_rdata),
    .alu_f_o        (mem_wb_alu_out),
    .br_en_o        (mem_wb_br_en),
    .rd_addr_o      (mem_wb_rd_addr),
    .u_imm_o        (mem_wb_u_imm),
    .pc_o           (mem_wb_pc),
    .monitor_o      (mem_wb_monitor_word_o),
    .insn_valid_o   (mem_wb_valid_instruction)
);

//  +--------------------------------------------------------------------+
//  |                                                                    |
//  |                              WB stage                              |
//  |                                                                    |
//  +--------------------------------------------------------------------+

wb_stage cpu_wb(
    .clk,
    .rst,
    .mem_rdata          (data_mem_rdata),
    .mem_br_en          (mem_wb_br_en),
    .mem_alu_out        (mem_wb_alu_out),
    .mem_ctrlword       (mem_wb_ctrlword),
    .mem_rd             (mem_wb_rd_addr),
    .mem_u_imm          (mem_wb_u_imm),
    .mem_pc             (mem_wb_pc),
    .mem_monitor_word   (mem_wb_monitor_word_o),
    .data_mem_resp,
    .mem_insn_valid(mem_wb_valid_instruction),
    .load_mem_wb(ld_mem),
    
    .regfile_write      (regfile_write),
    .regfile_wdata      (regwrite_data),
    .regfile_waddr      (regwrite_addr)
);

//  +--------------------------------------------------------------------+
//  |                                                                    |
//  |                          Hazard detection                          |
//  |                                                                    |
//  +--------------------------------------------------------------------+

hazard_detection hzd_unit (
    .clk_i                  (clk),
    .rst_i                  (rst),

    // Pipeline monitoring signals
    .if_id_insn_valid_i     (if_id_valid_instruction),
    .id_ex_insn_valid_i     (id_ex_valid_instruction),
    .ex_mem_insn_valid_i    (ex_mem_valid_instruction),
    .mem_wb_insn_valid_i    (mem_wb_valid_instruction),

    // IF signals
    .insn_rdy_i             (if_instr_ready),
    .imem_read_i            (instr_mem_read),
    .imem_resp_i            (instr_mem_resp),
    .pc_i_ok_o              (if_pc_correct),

    // ID signals
    .rs1_addr_i             (id_rs1_usage),
    .rs2_addr_i             (id_rs2_usage),
    .fwd_ex_rd_addr_i       (fwd_rs1_addr),
    .fwd_mem_rd_addr_i      (fwd_rs2_addr),
    .rf_waddr_i             (regfile_write ? regwrite_addr : 5'h0),

    // ID_EX stage registers
    .id_ex_rd_addr_i        (id_ex_rd_addr),

    // EX_MEM stage registers
    .ex_mem_rd_addr_i       (ex_mem_rd_addr),

    // MEM stage, memory access signals
    .dmem_read_i            (data_mem_read),
    .dmem_write_i           (data_mem_write),
    .dmem_resp_i            (data_mem_resp),

    // MEM_WB stage registers
    .mem_wb_rd_addr_i       (mem_wb_rd_addr),
    .mem_wb_ctrlword_i      (mem_wb_ctrlword),

    // Branch (Control) harzard detection
    .pc_i                   (id_pc_in),
    .pc_gold_i              (if_pc_golden),

    // Output control signals
    .ld_if_o                (ld_if),
    .ld_id_o                (ld_id),
    .ld_ex_o                (ld_ex),
    .ld_mem_o               (ld_mem),
    .ld_pc_o                (ld_pc),

    .flush_if_id_o          (flush_if_id),
    .flush_id_ex_o          (flush_id_ex),
    .flush_ex_mem_o         (flush_ex_mem),
    .flush_mem_wb_o         (flush_mem_wb)
);

endmodule : mp4
