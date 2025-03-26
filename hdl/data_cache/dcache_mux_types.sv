import rv32i_types::*;

package dcache_waymux;
typedef enum bit {
    wayhit = 1'b0,
    waylru = 1'b1
} waymux_sel_t;
endpackage

package dcache_dloadmux;
typedef enum bit[1:0] {
    from_cpu = 2'b00,
    from_mem = 2'b01,
    mem_mask_cpu = 2'b10
} data_wdata_mux_sel_t;

typedef enum bit {
    as_lru = 1'b0,
    as_hit = 1'b1
} data_wren_mux_sel_t;
endpackage

package dcache_respmux;
typedef enum bit {
    waymux_out = 1'b0,
    pmem_read = 1'b1
} respmux_sel_t;
endpackage

package dcache_mamux;
typedef enum bit {
    waylru = 1'b0,
    cpu = 1'b1
} mamux_sel_t;
endpackage

// Provides CPU mem_resp signal.
package dcache_hitmux;
typedef enum bit[1:0] {
    as_hit = 2'b00,
    force_zero = 2'b10,
    force_one = 2'b11
} hitmux_t;
endpackage

package dcache_dirtymux;
typedef enum bit {
    way_hit = 1'b0,
    way_lru = 1'b1
} dirty_wren_mux_sel_t;
endpackage

package dcache_lrumux;
typedef enum bit {
    inv_lru = 1'b0,
    inv_hit = 1'b1
} lru_wdata_mux_sel_t;
endpackage
