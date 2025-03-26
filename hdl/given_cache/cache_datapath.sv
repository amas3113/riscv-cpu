module cache_datapath (
  input clk,

  /* CPU memory data signals */
  input [31:0]          mem_byte_enable,
  input [31:0]          mem_address,
  input [255:0]         mem_wdata,
  output logic [255:0]  mem_rdata,

  /* Physical memory data signals */
  input  [255:0]        pmem_rdata,
  output logic [255:0]  pmem_wdata,
  output logic [31:0]   pmem_address,

  /* Control signals */
  input         tag_load,
  input         valid_load,
  input         dirty_load,
  input         dirty_in,
  output logic  dirty_out,

  input         eval_pref_i,
  input [31:0]  pref_addr_i,
  input         hook_pref_addr_i,

  output logic  hit,
  input [1:0]   writing
);

logic [255:0] line_in, line_out;
logic [23:0]  address_tag, tag_out;
logic [2:0]   index;
logic [2:0]   rindex, windex;
logic [31:0]  mask;
logic         valid_out;

logic [31:0]  mem_addr;
logic [255:0] pref_buffer;

always_comb begin
  mem_addr = eval_pref_i ? pref_addr_i : mem_address;
  address_tag = mem_addr[31:8];
  index = mem_addr[7:5];
  hit = valid_out && (tag_out == address_tag);

  if (hook_pref_addr_i) begin
    pmem_address = pref_addr_i;
  end else begin
    pmem_address = (dirty_out) ? {tag_out, mem_addr[7:0]} : mem_addr;
  end
  mem_rdata = line_out;
  pmem_wdata = line_out;

  case (writing)
    2'b00: begin // load from memory
      mask = 32'hFFFFFFFF;
      line_in = pmem_rdata;
    end
    2'b01: begin // write from cpu
      mask = mem_byte_enable;
      line_in = mem_wdata;
    end
    default: begin // don't change data
      mask = 32'b0;
      line_in = mem_wdata;
    end
	endcase
end

always @(posedge clk) begin
  pref_buffer <= pmem_rdata;
end

// rindex, windex
data_array DM_cache (clk, mask, index, index, line_in, line_out);
array #(24) tag (clk, tag_load, index, index, address_tag, tag_out);
array #(1) valid (clk, valid_load, index, index, 1'b1, valid_out);
array #(1) dirty (clk, dirty_load, index, index, dirty_in, dirty_out);

endmodule : cache_datapath
