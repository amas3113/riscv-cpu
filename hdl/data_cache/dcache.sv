module data_cache #(
    parameter OFFSET_BITS = 5,
    parameter INDEX_BITS  = 8,

    parameter ADDR_WIDTH  = 32,
    parameter LOG2_WAYS   = 3, // 1 - 2 way. 2 - 4 way. 3 - 8 way.
    parameter DATA_WIDTH  = 32
) (
    clk, rst, pmem_resp, pmem_rdata, pmem_address, pmem_wdata, pmem_read, pmem_write,
    mem_read, mem_write, mem_byte_enable_cpu, mem_address, mem_wdata_cpu, mem_resp, mem_rdata_cpu
);


parameter CACHELINE_BIT_WIDTH = 8*(2**OFFSET_BITS); // Real computer engineers use "<<" instead of "**" lol
parameter BYTES_IN_CACHELINE = (2**OFFSET_BITS);
parameter BYTES_IN_CPUWORD   = (DATA_WIDTH/8);

parameter TAG_BITS = ADDR_WIDTH - OFFSET_BITS - INDEX_BITS;
parameter NUM_WAYS = (2**LOG2_WAYS);

input clk, rst;

/* Physical memory signals */
input logic pmem_resp;
input logic [(CACHELINE_BIT_WIDTH-1):0] pmem_rdata;
output logic [(ADDR_WIDTH-1):0] pmem_address;
output logic [(CACHELINE_BIT_WIDTH-1):0] pmem_wdata;
output logic pmem_read;
output logic pmem_write;

/* CPU memory signals */
input logic mem_read;
input logic mem_write;
input logic [(BYTES_IN_CPUWORD-1):0] mem_byte_enable_cpu;
input logic [(ADDR_WIDTH-1):0] mem_address;
input logic [(DATA_WIDTH-1):0] mem_wdata_cpu;
output logic mem_resp;
output logic [(DATA_WIDTH-1):0] mem_rdata_cpu;

/* Memory signals for the cache to use. */
// These signals are connected to decode stage - d.
logic [(CACHELINE_BIT_WIDTH-1):0] d_mem_wdata_line;
logic [(CACHELINE_BIT_WIDTH-1):0] e_mem_rdata_line;
logic [(BYTES_IN_CACHELINE-1):0]  d_mem_byte_enable_line;
logic [(ADDR_WIDTH-1):0]  d_mem_address_line;
assign d_mem_address_line = mem_address;

// First stage is Decode - d
logic [(TAG_BITS-1):0]     d_tag;
logic [(INDEX_BITS-1):0]   d_index;
logic [(OFFSET_BITS-1):0]  d_offset;

logic [(TAG_BITS-1):0]             d_tag_array   [(NUM_WAYS-1):0];
logic [(CACHELINE_BIT_WIDTH-1):0]  d_data_array  [(NUM_WAYS-1):0];
logic                              d_valid_array [(NUM_WAYS-1):0];
logic                              d_dirty_array [(NUM_WAYS-1):0];
logic [(LOG2_WAYS-1):0]            d_lru_array;

// Signals from second stage Execute - e. 
logic [(CACHELINE_BIT_WIDTH-1):0]  e_data_wdata;
logic [(BYTES_IN_CACHELINE-1):0]   e_data_wben;
logic                              e_valid_wdata;
logic                              e_dirty_wdata;
logic [(LOG2_WAYS-1):0]            e_lru_wdata;

logic e_tag_load   [(NUM_WAYS-1):0];
logic e_data_load  [(NUM_WAYS-1):0];
logic e_valid_load [(NUM_WAYS-1):0];
logic e_dirty_load [(NUM_WAYS-1):0];
logic e_lru_load;

/* State registers from d to e*/
logic load_state_registers; // <-- Control signal
logic [(OFFSET_BITS-1):0]          e_offset;
logic [(INDEX_BITS-1):0]           e_index;
logic [(TAG_BITS-1):0]             e_tag;
logic [(TAG_BITS-1):0]             e_tag_array    [(NUM_WAYS-1):0];
logic [(CACHELINE_BIT_WIDTH-1):0]  e_data_array   [(NUM_WAYS-1):0];
logic                              e_valid_array  [(NUM_WAYS-1):0];
logic                              e_dirty_array  [(NUM_WAYS-1):0];
logic [(LOG2_WAYS-1):0]            e_lru_array;
logic [(CACHELINE_BIT_WIDTH-1):0]  e_mem_wdata_line;
logic [(BYTES_IN_CACHELINE-1):0]   e_mem_wben_line;
logic                              e_mem_read;
logic                              e_mem_write;

/* Control Signals for execute stage. */
dcache_waymux::waymux_sel_t waymux_sel;
dcache_respmux::respmux_sel_t respmux_sel;
dcache_mamux::mamux_sel_t mamux_sel;
dcache_dloadmux::data_wdata_mux_sel_t wdata_mux_sel;
dcache_dloadmux::data_wren_mux_sel_t wren_mux_sel;
dcache_hitmux::hitmux_t hitmux_sel;
dcache_dirtymux::dirty_wren_mux_sel_t dirty_wren_mux_sel;
dcache_lrumux::lru_wdata_mux_sel_t lru_wdata_mux_sel;

logic hit;
logic [(LOG2_WAYS-1):0] hit_way;
logic load_tag;
logic load_valid;
logic load_data;
logic load_dirty;
logic read_dirty;

data_cacheline_adapter #(
    .CACHELINE_BIT_WIDTH(CACHELINE_BIT_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .OFFSET_BITS(OFFSET_BITS)
) inst_d_dcacheline_adapter (
    .address(mem_address),
    .mem_wdata(mem_wdata_cpu),
    // .mem_rdata(mem_rdata_cpu),
    .mem_byte_enable(mem_byte_enable_cpu),

    .mem_wdata_line(d_mem_wdata_line),
    // .mem_rdata_line(d_mem_rdata_line),
    .mem_byte_enable_line(d_mem_byte_enable_line)
);

data_cacheline_adapter #(
    .CACHELINE_BIT_WIDTH(CACHELINE_BIT_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .OFFSET_BITS(OFFSET_BITS)
) inst_e_cacheline_adapter (
    .address({e_tag, e_index, e_offset}),
    .mem_rdata(mem_rdata_cpu),
    .mem_rdata_line(e_mem_rdata_line)
);

data_cache_decoder #(
    .OFFSET_BITS(OFFSET_BITS),
    .INDEX_BITS(INDEX_BITS),
    .ADDR_WIDTH(ADDR_WIDTH),
    .LOG2_WAYS(LOG2_WAYS),
    .DATA_WIDTH(DATA_WIDTH)
) inst_dcache_decoder (
    .clk, .rst, .load(load_state_registers),

    .mem_address(d_mem_address_line),
    .offset(d_offset), .index(d_index), .tag(d_tag),

    .tag_array_out(d_tag_array), .data_array_out(d_data_array),
    .valid_array_out(d_valid_array), .dirty_array_out(d_dirty_array),
    .lru_array_out(d_lru_array),

    .tag_array_wdata(e_tag),
    .data_array_wdata(e_data_wdata),
    .data_array_wben(e_data_wben),
    .valid_array_wdata(e_valid_wdata),
    .dirty_array_wdata(e_dirty_wdata),
    .lru_wdata(e_lru_wdata),

    .tag_load(e_tag_load),
    .data_load(e_data_load),
    .valid_load(e_valid_load),
    .dirty_load(e_dirty_load),
    .lru_load(e_lru_load),

    .write_to_index(e_index)
);

data_cache_state_registers #(
    .OFFSET_BITS(OFFSET_BITS),
    .INDEX_BITS(INDEX_BITS),
    .ADDR_WIDTH(ADDR_WIDTH),
    .LOG2_WAYS(LOG2_WAYS),
    .DATA_WIDTH(DATA_WIDTH),
    .CACHELINE_BIT_WIDTH(CACHELINE_BIT_WIDTH),
    .BYTES_IN_CACHELINE(BYTES_IN_CACHELINE),
    .BYTES_IN_CPUWORD(BYTES_IN_CPUWORD),
    .TAG_BITS(TAG_BITS),
    .NUM_WAYS(NUM_WAYS)
) inst_dcache_stateregs (
    .clk, .rst, .load(load_state_registers),
    .offset_in(d_offset),
    .index_in(d_index),
    .tag_in(d_tag),
    .tag_array_in(d_tag_array),
    .data_array_in(d_data_array),
    .valid_array_in(d_valid_array),
    .dirty_array_in(d_dirty_array),
    .lru_in(d_lru_array),
    .mem_wdata_line_in(d_mem_wdata_line),
    .mem_wben_line_in(d_mem_byte_enable_line),
    .mem_read_in(mem_read),
    .mem_write_in(mem_write),

    .offset_out(e_offset),
    .index_out(e_index),
    .tag_out(e_tag),
    .tag_array_out(e_tag_array),
    .data_array_out(e_data_array),
    .valid_array_out(e_valid_array),
    .dirty_array_out(e_dirty_array),
    .lru_out(e_lru_array),
    .mem_wdata_line_out(e_mem_wdata_line),
    .mem_wben_line_out(e_mem_wben_line),
    .mem_read_out(e_mem_read),
    .mem_write_out(e_mem_write)
);

data_cache_execute #(
    .OFFSET_BITS(OFFSET_BITS),
    .INDEX_BITS(INDEX_BITS),
    .ADDR_WIDTH(ADDR_WIDTH),
    .LOG2_WAYS(LOG2_WAYS),
    .DATA_WIDTH(DATA_WIDTH)
) inst_dcache_execute (
    .clk, .rst,
    .offset(e_offset), .index(e_index), .tag(e_tag),

    .tag_array(e_tag_array), .data_array(e_data_array),
    .valid_array(e_valid_array), .dirty_array(e_dirty_array), .lru(e_lru_array),
    .pmem_rdata(pmem_rdata),
    .mem_wdata_line(e_mem_wdata_line),
    .mem_wben_line(e_mem_wben_line),

    .waymux_out(pmem_wdata),
    .pmem_address(pmem_address),
    .mem_resp_mux_out(e_mem_rdata_line),
    .mem_resp(mem_resp),

    .load_tag_array(e_tag_load),
    .load_valid_array(e_valid_load),
    .load_data_array(e_data_load),
    .load_dirty_array(e_dirty_load),
    .data_array_wdata(e_data_wdata),
    .data_array_wben(e_data_wben),
    .lru_wdata(e_lru_wdata),

    .waymux_sel, .respmux_sel, .mamux_sel, .wdata_mux_sel,
    .wren_mux_sel, .hitmux_sel, .dirty_wren_mux_sel, .lru_wdata_mux_sel,

    .hit, .hit_way, .load_tag, .load_valid, .load_data, .load_dirty, .read_dirty
);

data_cache_controller #(
    .LOG2_WAYS(LOG2_WAYS)
) inst_dcache_controller(
    .clk, .rst,

    .hit, .hit_way, .e_mem_read, .e_mem_write, .pmem_resp,
    .read_dirty,

    .waymux_sel, .respmux_sel, .mamux_sel, .wdata_mux_sel,
    .wren_mux_sel, .hitmux_sel, .dirty_wren_mux_sel, .lru_wdata_mux_sel,

    .load_state_registers,

    .load_tag, .load_valid, .load_data, .load_dirty, .load_lru(e_lru_load),

    .wdata_valid(e_valid_wdata),
    .wdata_dirty(e_dirty_wdata),

    .pmem_read, .pmem_write
);

endmodule
