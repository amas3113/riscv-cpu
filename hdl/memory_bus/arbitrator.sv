import rv32i_types::*;

`define BAD_MUX_SEL $fatal("%0t %s %0d: Illegal mux select", $time, `__FILE__, `__LINE__)

module mem_arbitrator(
    input clk,
    input rst,

    // Instruction memory port.
    input instr_mem_read,
    input instr_mem_write,
    input rv32i_word instr_mem_addr,
    input rv32i_word instr_mem_wdata,
    input [3:0] instr_mem_byte_enable,
    output rv32i_word instr_mem_rdata,
    output logic instr_mem_resp,

    // Data memory port.
    input data_mem_read,
    input data_mem_write,
    input rv32i_word data_mem_addr,
    input rv32i_word data_mem_wdata,
    input [3:0] data_mem_byte_enable,
    output rv32i_word data_mem_rdata,
    output logic data_mem_resp,

    // Physical memory port.
    output logic [31:0] pmem_address,
    output logic [63:0] pmem_wdata,
    input [63:0] pmem_rdata,
    output logic pmem_read, pmem_write,
    input pmem_resp
);

// Cacheline adapter connections.
logic cline_resp;
logic [255:0] cline_rdata;
logic [31:0] cline_address;
logic [255:0] cline_wdata;
logic cline_read;
logic cline_write;

cacheline_adaptor cline_adaptor(
    .clk,
    .reset_n  (~rst),

    .line_i   (cline_wdata),
    .line_o   (cline_rdata),
    .address_i(cline_address),
    .read_i   (cline_read),
    .write_i  (cline_write),
    .resp_o   (cline_resp),

    .burst_i  (pmem_rdata),
    .burst_o  (pmem_wdata),
    .address_o(pmem_address),
    .read_o   (pmem_read),
    .write_o  (pmem_write),
    .resp_i   (pmem_resp)
);

// icache
logic ipmem_resp;
logic [255:0] ipmem_rdata;
logic [31:0] ipmem_address;
logic [255:0] ipmem_wdata;
logic ipmem_read;
logic ipmem_write;

cache icache (
  .clk,
  /* Physical Memory signals. */
  .pmem_resp    (ipmem_resp),
  .pmem_rdata   (ipmem_rdata),
  .pmem_address (ipmem_address),
  .pmem_wdata   (ipmem_wdata),
  .pmem_read    (ipmem_read),
  .pmem_write   (ipmem_write),

  /* CPU memory signals. */
  .mem_read           (instr_mem_read),
  .mem_write          (instr_mem_write),
  .mem_byte_enable_cpu(instr_mem_byte_enable),
  .mem_address        (instr_mem_addr),
  .mem_wdata_cpu      (instr_mem_wdata),
  .mem_resp           (instr_mem_resp),
  .mem_rdata_cpu      (instr_mem_rdata)
);

// dcache
logic dpmem_resp;
logic [255:0] dpmem_rdata;
logic [31:0] dpmem_address;
logic [255:0] dpmem_wdata;
logic dpmem_read;
logic dpmem_write;

data_cache # (
  .OFFSET_BITS(5),
  .INDEX_BITS(7),
  .ADDR_WIDTH(32),
  .LOG2_WAYS(2),
  .DATA_WIDTH(32)
) dcache (
  .clk,
  .rst,

  /* Physical Memory signals. */
  .pmem_resp    (dpmem_resp),
  .pmem_rdata   (dpmem_rdata),
  .pmem_address (dpmem_address),
  .pmem_wdata   (dpmem_wdata),
  .pmem_read    (dpmem_read),
  .pmem_write   (dpmem_write),

  /* CPU memory signals. */
  .mem_read           (data_mem_read),
  .mem_write          (data_mem_write),
  .mem_byte_enable_cpu(data_mem_byte_enable),
  .mem_address        (data_mem_addr),
  .mem_wdata_cpu      (data_mem_wdata),
  .mem_resp           (data_mem_resp),
  .mem_rdata_cpu      (data_mem_rdata)
);

enum bit [1:0] {
  idle, serving_instr, serving_data
} state, next_state;

assign ipmem_rdata = cline_rdata;
assign dpmem_rdata = cline_rdata;

function void set_defaults();
  ipmem_resp = 1'b0;
  dpmem_resp = 1'b0;
  cline_address = 32'b0;
  cline_wdata = 256'b0;
  cline_read = 1'b0;
  cline_write = 1'b0;
endfunction

// State Signals
always_comb begin
  set_defaults();
  unique case(state)
    idle: ;
    serving_instr: begin
      /* Hook instruction cache onto physical memory. */
      ipmem_resp = cline_resp;
      cline_address = ipmem_address;
      cline_wdata = ipmem_wdata;
      cline_read = ipmem_read;
      cline_write = ipmem_write;
    end
    serving_data: begin
      /* Hook data cache onto physical memory. */
      dpmem_resp = cline_resp;
      cline_address = dpmem_address;
      cline_wdata = dpmem_wdata;
      cline_read = dpmem_read;
      cline_write = dpmem_write;
    end

    default: `BAD_MUX_SEL;
  endcase
end

// Next state logic
always_comb begin
  next_state = state;
  case (state)
    idle: begin
      if (ipmem_read || ipmem_write) begin
        next_state = serving_instr;
      end else if (dpmem_read || dpmem_write) begin
        next_state = serving_data;
      end
    end
    serving_instr: begin
      if (ipmem_resp) begin
        if (dpmem_read || dpmem_write) begin
          next_state = serving_data;
        end else begin
          next_state = idle;
        end
      end
    end
    serving_data: begin
      if (dpmem_resp) begin
        if (ipmem_read || ipmem_write) begin
          next_state = serving_instr;
        end else begin
          next_state = idle;
        end
      end
    end
    default: `BAD_MUX_SEL;
  endcase
end

always_ff @(posedge clk) begin
  if (rst) begin
    state <= idle;
  end else begin
    state <= next_state;
  end
end

endmodule
