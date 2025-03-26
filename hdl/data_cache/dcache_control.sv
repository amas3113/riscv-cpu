module data_cache_controller #(
    parameter LOG2_WAYS = 3
) (
    input clk, rst,

    /* Input signals. */
    input logic hit,
    input logic [(LOG2_WAYS-1):0] hit_way,
    input logic e_mem_read,
    input logic e_mem_write,
    input logic pmem_resp,
    input logic read_dirty,

    /* Output signals. */
    output dcache_waymux::waymux_sel_t waymux_sel,
    output dcache_respmux::respmux_sel_t respmux_sel,
    output dcache_mamux::mamux_sel_t mamux_sel,
    output dcache_dloadmux::data_wdata_mux_sel_t wdata_mux_sel,
    output dcache_dloadmux::data_wren_mux_sel_t wren_mux_sel,
    output dcache_hitmux::hitmux_t hitmux_sel,
    output dcache_dirtymux::dirty_wren_mux_sel_t dirty_wren_mux_sel,
    output dcache_lrumux::lru_wdata_mux_sel_t lru_wdata_mux_sel,

    output logic load_state_registers,
    
    output logic load_tag,
    output logic load_valid,
    output logic load_data,
    output logic load_dirty,
    output logic load_lru,
    output logic wdata_valid,
    output logic wdata_dirty,
    output logic pmem_read,
    output logic pmem_write
);

// Defaults
function void set_defaults();
    load_state_registers = 1'b1;
      
    waymux_sel = dcache_waymux::wayhit;
    respmux_sel = dcache_respmux::waymux_out;
    mamux_sel = dcache_mamux::cpu;
    wdata_mux_sel = dcache_dloadmux::mem_mask_cpu;
    wren_mux_sel = dcache_dloadmux::as_hit;
    hitmux_sel = dcache_hitmux::as_hit;
    dirty_wren_mux_sel = dcache_dirtymux::way_hit;
    lru_wdata_mux_sel = dcache_lrumux::inv_hit;

    load_tag = 1'b0;
    load_valid = 1'b0;
    load_data = 1'b0;
    load_dirty = 1'b0;
    load_lru = 1'b0;
    wdata_valid = 1'b0;
    wdata_dirty = 1'b0;
    pmem_read = 1'b0;
    pmem_write = 1'b0;
endfunction

// Load the LRU array.
function void fn_load_lru(dcache_lrumux::lru_wdata_mux_sel_t in);
    lru_wdata_mux_sel = in;
    load_lru = 1'b1;
endfunction

// Load the dirty array. Can either load the LRU way or HIT way.
function void fn_load_dirty(dcache_dirtymux::dirty_wren_mux_sel_t mux, logic ldvalue);
    dirty_wren_mux_sel = mux;
    wdata_dirty = ldvalue;
    load_dirty = 1'b1;
endfunction

// Load data. Can either load the LRU way or HIT way.
function void fn_load_data(dcache_dloadmux::data_wdata_mux_sel_t datamux, dcache_dloadmux::data_wren_mux_sel_t wrenmux);
    wdata_mux_sel = datamux;
    wren_mux_sel = wrenmux;
    load_data = 1'b1;
endfunction

// Load new tag. Always load the LRU way.
function void fn_load_tag();
    load_tag = 1'b1;
endfunction

// Load valid bit. Always load the LRU way. Always load 1.
function void set_valid();
    wdata_valid = 1'b1;
    load_valid = 1'b1;
endfunction

// Read data at CPU address from memory.
function void setup_readmiss();
    hitmux_sel = dcache_hitmux::force_zero;
    mamux_sel = dcache_mamux::cpu;
    pmem_read = 1'b1;
    respmux_sel = dcache_respmux::pmem_read;
    load_state_registers = 1'b0;
endfunction

// Put LRU data into physical memory.
function void setup_writeback();
    hitmux_sel = dcache_hitmux::force_zero;
    mamux_sel = dcache_mamux::waylru;
    waymux_sel = dcache_waymux::waylru;
    pmem_write = 1'b1;
    load_state_registers = 1'b0;
endfunction

enum bit [1:0] {
    IDLE = 2'b00, WAIT_MEM_READ, WAIT_MEM_WB
} state, next_state;

always_comb begin
    set_defaults();

    unique case(state)
        IDLE: begin
            if(e_mem_read) begin
                if(hit) begin
                    // Hit in cache. Deliver cache data to mem_read.
                    hitmux_sel = dcache_hitmux::as_hit;
                    waymux_sel = dcache_waymux::wayhit;
                    respmux_sel = dcache_respmux::waymux_out;
                    fn_load_lru(dcache_lrumux::inv_hit);
                    load_state_registers = 1'b1;
                    next_state = IDLE;
                end else begin
                    // Cache Miss.
                    if(read_dirty) begin
                        setup_writeback();
                        next_state = WAIT_MEM_WB;
                    end else begin
                        setup_readmiss();
                        next_state = WAIT_MEM_READ;
                    end
                end
            end else if (e_mem_write) begin
                if(hit) begin
                    // Hit in cache. Deliver CPU write data to cache.
                    fn_load_data(dcache_dloadmux::from_cpu, dcache_dloadmux::as_hit);
                    fn_load_lru(dcache_lrumux::inv_hit);
                    fn_load_dirty(dcache_dirtymux::way_hit, 1'b1);
                    load_state_registers = 1'b1;
                    next_state = IDLE;
                end else begin
                    if(read_dirty) begin
                        setup_writeback();
                        next_state = WAIT_MEM_WB;
                    end else begin
                        setup_readmiss();
                        next_state = WAIT_MEM_READ;
                    end
                end
            end else begin
                next_state = IDLE;
            end
        end

        WAIT_MEM_READ: begin
            setup_readmiss();

            if(pmem_resp) begin
                if(e_mem_read) begin
                    fn_load_data(dcache_dloadmux::from_mem, dcache_dloadmux::as_lru);
                    fn_load_lru(dcache_lrumux::inv_lru);
                    respmux_sel = dcache_respmux::pmem_read;
                    hitmux_sel = dcache_hitmux::force_one;
                    set_valid();
                    fn_load_tag();
                    fn_load_dirty(dcache_dirtymux::way_lru, 1'b0);
                end else if(e_mem_write) begin
                    fn_load_data(dcache_dloadmux::mem_mask_cpu, dcache_dloadmux::as_lru);
                    fn_load_lru(dcache_lrumux::inv_lru);
                    hitmux_sel = dcache_hitmux::force_one;
                    set_valid();
                    fn_load_tag();
                    fn_load_dirty(dcache_dirtymux::way_lru, 1'b1);
                end else
                    $fatal("%0t %s %0d: Unexpected memory load.", $time, `__FILE__, `__LINE__);

                load_state_registers = 1'b1;
                next_state = IDLE;
            end else begin
                load_state_registers = 1'b0;
                next_state = WAIT_MEM_READ;
            end
        end

        WAIT_MEM_WB: begin
            setup_writeback();

            if(pmem_resp) begin
                setup_readmiss();
                next_state = WAIT_MEM_READ;
            end else begin
                load_state_registers = 1'b0;
                next_state = WAIT_MEM_WB;
            end
        end
    endcase
end

always_ff @(posedge clk) begin
    if(rst)
        state <= IDLE;
    else
        state <= next_state;
end

endmodule