import rv32i_types::*;

module data_cache_execute #(
    parameter OFFSET_BITS = 5,
    parameter INDEX_BITS  = 8,

    parameter ADDR_WIDTH  = 32,
    parameter LOG2_WAYS   = 3, // 1 - 2 way. 2 - 4 way. 3 - 8 way.
    parameter DATA_WIDTH  = 32
) (
    clk, rst,
    
    offset, index, tag,

    tag_array, data_array, valid_array, dirty_array, lru,

    pmem_rdata, mem_wdata_line, mem_wben_line,

    waymux_out, pmem_address, mem_resp_mux_out, mem_resp,

    load_tag_array, load_valid_array, load_data_array, load_dirty_array, data_array_wdata, data_array_wben, lru_wdata,

    waymux_sel, respmux_sel, mamux_sel, wdata_mux_sel, wren_mux_sel, hitmux_sel, dirty_wren_mux_sel, lru_wdata_mux_sel,

    hit, hit_way,

    load_tag, load_valid, load_data, load_dirty, read_dirty
);


parameter CACHELINE_BIT_WIDTH = 8*(2**OFFSET_BITS); // Real computer engineers use "<<" instead of "**" lol
parameter BYTES_IN_CACHELINE = (2**OFFSET_BITS);
parameter BYTES_IN_CPUWORD   = (DATA_WIDTH/8);

parameter TAG_BITS = ADDR_WIDTH - OFFSET_BITS - INDEX_BITS;
parameter NUM_WAYS = (2**LOG2_WAYS);

input clk, rst;

/* State registers */
input logic [(OFFSET_BITS-1):0] offset;
input logic [(INDEX_BITS-1):0]  index;
input logic [(TAG_BITS-1):0]    tag;
input logic [(TAG_BITS-1):0]            tag_array    [(NUM_WAYS-1):0];
input logic [(CACHELINE_BIT_WIDTH-1):0] data_array   [(NUM_WAYS-1):0];
input logic                             valid_array  [(NUM_WAYS-1):0];
input logic                             dirty_array  [(NUM_WAYS-1):0];
input logic [(LOG2_WAYS-1):0] lru;

/* Inputs */
input logic [(CACHELINE_BIT_WIDTH-1):0] pmem_rdata;
input logic [(CACHELINE_BIT_WIDTH-1):0] mem_wdata_line; // From CPU (latched)
input logic [(BYTES_IN_CACHELINE-1):0]  mem_wben_line;  // From CPU (latched)

/* Outputs */
output logic [(CACHELINE_BIT_WIDTH-1):0] waymux_out; // Connect to pmem_wdata
output logic [(ADDR_WIDTH):0]            pmem_address;
output logic [(CACHELINE_BIT_WIDTH-1):0] mem_resp_mux_out; // Connect to CPU mem_rdata
output logic mem_resp;

/* Outputs to decode stage. */
output logic load_tag_array   [(NUM_WAYS-1):0];
output logic load_valid_array [(NUM_WAYS-1):0];
output logic load_data_array  [(NUM_WAYS-1):0];
output logic load_dirty_array [(NUM_WAYS-1):0];
output logic [(CACHELINE_BIT_WIDTH-1):0] data_array_wdata;
output logic [(BYTES_IN_CACHELINE-1):0]  data_array_wben;
output logic [(LOG2_WAYS-1):0]           lru_wdata;

/* Control Signals */
input dcache_waymux::waymux_sel_t waymux_sel;
input dcache_respmux::respmux_sel_t respmux_sel;
input dcache_mamux::mamux_sel_t mamux_sel;
input dcache_dloadmux::data_wdata_mux_sel_t wdata_mux_sel;
input dcache_dloadmux::data_wren_mux_sel_t wren_mux_sel;
input dcache_hitmux::hitmux_t hitmux_sel;
input dcache_dirtymux::dirty_wren_mux_sel_t dirty_wren_mux_sel;
input dcache_lrumux::lru_wdata_mux_sel_t lru_wdata_mux_sel;

output logic hit;
output logic [(LOG2_WAYS-1):0] hit_way;

input logic load_tag;
input logic load_valid;
input logic load_data;
input logic load_dirty;
output logic read_dirty;

logic [(ADDR_WIDTH-1):0] cpu_mem_addr;
// The memory address requested by the CPU.
assign cpu_mem_addr = {tag, index, offset};
// The memory address of the least recently used data. Victim address of eviction.
assign lru_mem_addr = {tag_array[lru], index, offset};

/***** Tag matching *****/
always_comb begin
	hit = 1'b0;
	hit_way = {LOG2_WAYS{1'b0}};

    for(int i=0; i<NUM_WAYS; i=i+1) begin: tag_match
        if(tag_array[i] == tag) begin
            if(valid_array[i] == 1'b1) begin
                    hit = 1'b1;
                    hit_way = i;
                    break;
            end
        end
    end
end

/***** Way MUX *****/
always_comb begin
    unique case(waymux_sel)
        dcache_waymux::wayhit: begin
            waymux_out = data_array[hit_way];
        end
        dcache_waymux::waylru: begin
            waymux_out = data_array[lru];
        end
    endcase
end

/***** Memory response MUX *****/
always_comb begin
    unique case(respmux_sel)
        dcache_respmux::waymux_out: begin
            mem_resp_mux_out = waymux_out;
        end
        dcache_respmux::pmem_read: begin
            mem_resp_mux_out = pmem_rdata;
        end
    endcase
end

/***** PMEM Address MUX *****/
always_comb begin
    unique case(mamux_sel)
        dcache_mamux::waylru: begin
            pmem_address = lru_mem_addr;
        end
        dcache_mamux::cpu: begin
            pmem_address = cpu_mem_addr;
        end
    endcase
end

/***** CPU mem_resp MUX *****/
always_comb begin
    unique case(hitmux_sel)
        dcache_hitmux::as_hit: mem_resp = hit;
        dcache_hitmux::force_zero: mem_resp = 1'b0;
        dcache_hitmux::force_one: mem_resp = 1'b1;
        default: mem_resp = 1'b0;
    endcase
end

/* Decode / demux control signals. */

/***** Load Tag array demux *****/
always_comb begin
    for(int i=0; i<NUM_WAYS; i=i+1) begin
        if(i == lru)
            load_tag_array[i] = load_tag;
        else
            load_tag_array[i] = 1'b0;
    end
end

/***** Load valid array demux *****/
always_comb begin
    for(int i=0; i<NUM_WAYS; i=i+1) begin
        if(i == lru)
            load_valid_array[i] = load_valid;
        else
            load_valid_array[i] = 1'b0;
    end
end


/***** Load dirty array demux *****/
logic [(LOG2_WAYS-1):0] dirty_wren_mux_out;
always_comb begin
    unique case(dirty_wren_mux_sel)
        dcache_dirtymux::way_lru: begin
            dirty_wren_mux_out = lru;
        end
        dcache_dirtymux::way_hit: begin
            dirty_wren_mux_out = hit_way;
        end
    endcase

    for(int i=0; i<NUM_WAYS; i=i+1) begin
        if(i == dirty_wren_mux_out)
            load_dirty_array[i] = load_dirty;
        else
            load_dirty_array[i] = 1'b0;
    end
end

/***** Read dirty array MUX *****/
always_comb begin
    read_dirty = dirty_array[lru];
end

/***** Data write enable MUX *****/
logic [(LOG2_WAYS-1):0] data_wren_mux_out;
always_comb begin
    unique case(wren_mux_sel)
        dcache_dloadmux::as_hit: data_wren_mux_out = hit_way;
        dcache_dloadmux::as_lru: data_wren_mux_out = lru;
    endcase

    for(int i=0; i<NUM_WAYS; i=i+1) begin
        if(i == data_wren_mux_out)
            load_data_array[i] = load_data;
        else
            load_data_array[i] = 1'b0;
    end
end

/***** Data write data MUX *****/
logic [(CACHELINE_BIT_WIDTH-1):0] mem_wben_line_extended;
always_comb begin
    for(int i=0; i<CACHELINE_BIT_WIDTH; i=i+1) begin
        mem_wben_line_extended[i] = mem_wben_line[i/8];
    end
end

always_comb begin
    unique case(wdata_mux_sel)
        dcache_dloadmux::from_cpu: begin
            data_array_wdata = mem_wdata_line;
            data_array_wben = mem_wben_line;
        end
        dcache_dloadmux::from_mem: begin
            data_array_wdata = pmem_rdata;
            data_array_wben = {BYTES_IN_CACHELINE{1'b1}};
        end
        dcache_dloadmux::mem_mask_cpu: begin
            data_array_wdata = (pmem_rdata & (~mem_wben_line_extended)) | (mem_wdata_line & mem_wben_line_extended);
            data_array_wben = {BYTES_IN_CACHELINE{1'b1}};
        end
    endcase
end

/***** LRU wdata MUX *****/
// Note: This is not just a MUX!!
// Normally we use pseudo-LRU, choosing the opposite way as least recently used.
// But when the cache is not full (some ways are invalid), it chooses the next invalid way no matter what the MUX selects.
logic all_ways_full;
always_comb begin
    lru_wdata = ~lru;
    all_ways_full = 1'b1;

    for(int i=0; i<NUM_WAYS; i=i+1) begin
        if(valid_array[i] == 1'b0) begin
            lru_wdata = i;
            all_ways_full = 1'b0;
            break;
        end
    end

    if(all_ways_full) begin
        unique case(lru_wdata_mux_sel)
            dcache_lrumux::inv_lru: lru_wdata = ~lru;
            dcache_lrumux::inv_hit: lru_wdata = ~hit_way;
        endcase
    end
end

endmodule
