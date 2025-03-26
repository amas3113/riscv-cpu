module cache (
  input clk,

  /* Physical memory signals */
  input           pmem_resp,
  input [255:0]   pmem_rdata,
  output [31:0]   pmem_address,
  output [255:0]  pmem_wdata,
  output          pmem_read,
  output          pmem_write,

  /* CPU memory signals */
  input           mem_read,
  input           mem_write,
  input [3:0]     mem_byte_enable_cpu,
  input [31:0]    mem_address,
  input [31:0]    mem_wdata_cpu,
  output          mem_resp,
  output [31:0]   mem_rdata_cpu
);

logic tag_load;
logic valid_load;
logic dirty_load;
logic dirty_in;
logic dirty_out;

logic hit;
logic [1:0] writing;

logic [255:0] mem_wdata;
logic [255:0] mem_rdata;
logic [31:0]  mem_byte_enable;

logic fetch;
logic pref_resp;
logic pref_read;
logic [31:0] pref_addr;
logic eval_pref;
logic hook_pref_addr;

cache_control control (
  .pref_read_i      (pref_read),
  .use_pref_addr_o  (eval_pref),
  .fetch_o          (fetch),
  .pref_resp_o      (pref_resp),
  .hook_pref_addr_o (hook_pref_addr),
  .*
);

cache_datapath datapath(
  .eval_pref_i      (eval_pref),
  .pref_addr_i      (pref_addr),
  .hook_pref_addr_i (hook_pref_addr),
  .*
);

line_adapter bus (
  .mem_wdata_line       (mem_wdata),
  .mem_rdata_line       (mem_rdata),
  .mem_wdata            (mem_wdata_cpu),
  .mem_rdata            (mem_rdata_cpu),
  .mem_byte_enable      (mem_byte_enable_cpu),
  .mem_byte_enable_line (mem_byte_enable),
  .address              (mem_address)
);

prefetcher prefetch (
  .fetch_i      (fetch),
  .pref_resp_i  (pref_resp),
  .pref_read_o  (pref_read),
  .pref_addr_o  (pref_addr),
  .mem_addr_i   (mem_address)
);

endmodule : cache
