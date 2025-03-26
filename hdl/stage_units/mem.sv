import rv32i_types::*;

`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)
`define MEM_UNALIGNED $fatal("%0t %s %0d: Non-aligned memory access.", $time, `__FILE__, `__LINE__)

module mem_stage(
    input clk, rst,

    /* Input signals from EX stage. */
    input rv32i_ctrl_word ex_ctrlword,
    input rv32i_word ex_rs2, ex_alu_out,
    input rv32i_word ex_u_imm, ex_pc,
    input logic ex_br_en,
    input logic [4:0] ex_rd_addr,
    input rv32i_monitor_word ex_monitor_word,

    /* Output signals to RAM. */
    output rv32i_word data_mem_addr,
    output logic data_mem_read, data_mem_write,
    output rv32i_word data_mem_wdata,
    input rv32i_word data_mem_rdata,
    output logic [3:0] data_mem_byte_enable,
    input logic data_mem_resp,

    /* Forwarding outputs. */
    output logic [4:0] mem_fwd_rs_addr,
    output rv32i_word mem_fwd_rs_data,

    /* MEM stage outputs. */
    output rv32i_word mem_rdata,
    output logic mem_br_en,
    output rv32i_word mem_alu_out,
    output rv32i_ctrl_word mem_ctrlword,
    output logic [4:0] mem_rd_addr,
    output rv32i_word mem_u_imm, mem_pc,
    output rv32i_monitor_word mem_monitor_word
);

assign mem_br_en = ex_br_en;
assign mem_ctrlword = ex_ctrlword;
assign mem_alu_out = ex_alu_out;
assign mem_rd_addr = ex_rd_addr;
assign mem_u_imm = ex_u_imm;
assign mem_pc = ex_pc;
assign data_mem_read = ex_ctrlword.mem_read;
assign data_mem_write = ex_ctrlword.mem_write;

/* Byte enable logic. */
always_comb begin
    data_mem_addr = {ex_alu_out[31:2], 2'b00};
	data_mem_byte_enable = 4'b1010;
	 
    unique case(ex_ctrlword.access_length)
        mem_ctrl::a_word: begin
            if(ex_alu_out[1:0] == 2'b00) begin
                data_mem_byte_enable = 4'b1111;
            end else `MEM_UNALIGNED;
        end

        mem_ctrl::a_half: begin
            if(ex_alu_out[1:0] == 2'b00) begin
                data_mem_byte_enable = 4'b0011;
            end else if(ex_alu_out[1:0] == 2'b10) begin
                data_mem_byte_enable = 4'b1100;
            end else `MEM_UNALIGNED;
        end

        mem_ctrl::a_byte: begin
            data_mem_byte_enable = (4'b0001 << ex_alu_out[1:0]);
        end

        default: data_mem_byte_enable = 4'b1010;
    endcase
end

/* Save logic. */
always_comb begin
    data_mem_wdata = 32'hDEADBEEF;
    unique case(ex_ctrlword.access_length)
        mem_ctrl::a_word: begin
            data_mem_wdata = ex_rs2;
        end

        mem_ctrl::a_half: begin
            unique case(ex_alu_out[1:0])
                2'b00: data_mem_wdata = {16'h0000, ex_rs2[15:0]};
                2'b10: data_mem_wdata = {ex_rs2[15:0], 16'h0000};
                default: data_mem_wdata = 32'hDEADECEB;
            endcase
        end

        mem_ctrl::a_byte: begin
            unique case(ex_alu_out[1:0])
                2'b00: data_mem_wdata = {24'h000000, ex_rs2[7:0]};
                2'b01: data_mem_wdata = {16'h0000, ex_rs2[7:0], 8'h00};
                2'b10: data_mem_wdata = {8'h00, ex_rs2[7:0], 16'h0000};
                2'b11: data_mem_wdata = {ex_rs2[7:0], 24'h000000};
                default: data_mem_wdata = 32'hDEADECEB;
            endcase
        end

        default: data_mem_wdata = 32'hDEADECEB;
    endcase
end

/* SEXT/ZEXT logic. */
// rv32i_word ext_result;

// always_comb begin
//     ext_result = 32'hDEADBEEF;
//     unique case (ex_ctrlword.access_length)
//         mem_ctrl::a_word: ext_result = data_mem_rdata;

//         mem_ctrl::a_half: begin
//             if(ex_alu_out[1:0] == 2'b00) begin
//                 if(ex_ctrlword.access_sign == mem_ctrl::t_unsigned)
//                     ext_result = {16'h0, data_mem_rdata[15:0]};
//                 else if (ex_ctrlword.access_sign == mem_ctrl::t_signed)
//                     ext_result = {{16{data_mem_rdata[15]}}, data_mem_rdata[15:0]};
//                 else ext_result = 32'hDEADECEB;
//             end else if(ex_alu_out[1:0] == 2'b10) begin
//                 if(ex_ctrlword.access_sign == mem_ctrl::t_unsigned)
//                     ext_result = {16'h0, data_mem_rdata[31:16]};
//                 else if (ex_ctrlword.access_sign == mem_ctrl::t_signed)
//                     ext_result = {{16{data_mem_rdata[31]}}, data_mem_rdata[31:16]};
//                 else ext_result = 32'hDEADECEB;
//             end else `MEM_UNALIGNED;
//         end

//         mem_ctrl::a_byte: begin
//             if(ex_ctrlword.access_sign == mem_ctrl::t_unsigned)
//                 unique case(ex_alu_out[1:0])
//                     2'b00: ext_result = {24'h0, data_mem_rdata[7:0]};
//                     2'b01: ext_result = {24'h0, data_mem_rdata[15:8]};
//                     2'b10: ext_result = {24'h0, data_mem_rdata[23:16]};
//                     2'b11: ext_result = {24'h0, data_mem_rdata[31:24]};
//                     default: ext_result = 32'hDEADECEB;
//                 endcase
//             else if(ex_ctrlword.access_sign == mem_ctrl::t_signed)
//                 unique case(ex_alu_out[1:0])
//                     2'b00: ext_result = {{24{data_mem_rdata[7]}},  data_mem_rdata[7:0]};
//                     2'b01: ext_result = {{24{data_mem_rdata[15]}}, data_mem_rdata[15:8]};
//                     2'b10: ext_result = {{24{data_mem_rdata[23]}}, data_mem_rdata[23:16]};
//                     2'b11: ext_result = {{24{data_mem_rdata[31]}}, data_mem_rdata[31:24]};
//                     default: ext_result = 32'hDEADECEB;
//                 endcase
//             else ext_result = 32'hDEADECEB;
//         end

//         default: ext_result = 32'hDEADECEB;
//     endcase
// end

/* Forwarding. */
always_comb begin
    if(ex_ctrlword.regfile_write == 1'b1) begin
        unique case(ex_ctrlword.regfilemux_sel)
            regfilemux::alu_out: begin
                mem_fwd_rs_addr = mem_rd_addr;
                mem_fwd_rs_data = mem_alu_out;
            end
            regfilemux::br_en: begin
                mem_fwd_rs_addr = mem_rd_addr;
                mem_fwd_rs_data = {31'h0, ex_br_en};
            end
            regfilemux::u_imm: begin
                mem_fwd_rs_addr = mem_rd_addr;
                mem_fwd_rs_data = ex_u_imm;
            end
            regfilemux::pc_plus4: begin
                mem_fwd_rs_addr = mem_rd_addr;
                mem_fwd_rs_data = mem_pc + 4;
            end
            // regfilemux::mem_rdata: begin
            //     if(data_mem_resp) begin
            //         mem_fwd_rs_addr = mem_rd_addr;
            //         mem_fwd_rs_data = ext_result;
            //     end else begin
            //         mem_fwd_rs_addr = 0;
            //         mem_fwd_rs_data = 0;
            //     end
            // end
            default: begin
                mem_fwd_rs_addr = 0;
                mem_fwd_rs_data = 0;
            end
        endcase
    end else begin
        mem_fwd_rs_addr = 0;
        mem_fwd_rs_data = 0;
    end
end
assign mem_rdata = 32'h0C1EA2ED;

// RVFI Signals
always_comb begin
    mem_monitor_word = ex_monitor_word;
    // mem_monitor_word.rvfi_mem_addr = data_mem_addr;
    mem_monitor_word.rvfi_mem_rmask = data_mem_read ? data_mem_byte_enable : 0;
    mem_monitor_word.rvfi_mem_wmask = data_mem_write ? data_mem_byte_enable : 0;
    // mem_monitor_word.rvfi_mem_rdata = data_mem_rdata;
    mem_monitor_word.rvfi_mem_wdata = data_mem_wdata;
    mem_monitor_word.rvfi_mem_addr = data_mem_addr;
end

endmodule