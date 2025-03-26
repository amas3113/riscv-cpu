module data_cache_decoder #(
    parameter OFFSET_BITS = 5,
    parameter INDEX_BITS  = 8,

    parameter ADDR_WIDTH  = 32,
    parameter LOG2_WAYS   = 3, // 1 - 2 way. 2 - 4 way. 3 - 8 way.
    parameter DATA_WIDTH  = 32
) (
    clk, rst, load,

    mem_address,

    offset, index, tag,

    tag_array_out, data_array_out, valid_array_out, dirty_array_out, lru_array_out,

    tag_array_wdata, data_array_wdata, data_array_wben, valid_array_wdata, dirty_array_wdata, lru_wdata,
    write_to_index,

    tag_load, data_load, valid_load, dirty_load, lru_load
);

parameter CACHELINE_BIT_WIDTH = 8*(2**OFFSET_BITS); // Real computer engineers use "<<" instead of "**" lol
parameter BYTES_IN_CACHELINE = (2**OFFSET_BITS);
parameter BYTES_IN_CPUWORD   = (DATA_WIDTH/8);

parameter TAG_BITS = ADDR_WIDTH - OFFSET_BITS - INDEX_BITS;
parameter NUM_WAYS = (2**LOG2_WAYS);

input clk, rst, load;

/* CPU memory signals */
input logic [(ADDR_WIDTH-1):0] mem_address;

/* Decoded Address */
output logic [(OFFSET_BITS-1):0]  offset;
output logic [(INDEX_BITS-1):0]  index;
output logic [(TAG_BITS-1):0] tag;

/* Outputs */
output logic [(TAG_BITS-1):0] tag_array_out [(NUM_WAYS-1):0];
output logic [(CACHELINE_BIT_WIDTH-1):0] data_array_out [(NUM_WAYS-1):0];

output logic valid_array_out [(NUM_WAYS-1):0];
output logic dirty_array_out [(NUM_WAYS-1):0];
output logic [(LOG2_WAYS-1):0] lru_array_out;

/* Inputs */
input logic [(TAG_BITS-1):0] tag_array_wdata;
input logic [(CACHELINE_BIT_WIDTH-1):0] data_array_wdata;
input logic [(BYTES_IN_CACHELINE-1):0] data_array_wben;  // Write Byte enable
input logic valid_array_wdata;       // From control
input logic dirty_array_wdata;       // From control
input logic [(LOG2_WAYS-1):0] lru_wdata;         // From execute MUX
input logic [(INDEX_BITS-1):0] write_to_index; // Old index (from previous clock cycle)

/* Control Signals */
input logic tag_load   [(NUM_WAYS-1):0];
input logic data_load  [(NUM_WAYS-1):0];         // Write
input logic valid_load [(NUM_WAYS-1):0];
input logic dirty_load [(NUM_WAYS-1):0];
input logic lru_load;

/***** Address Decode *****/
assign offset = mem_address[(OFFSET_BITS-1):0];
assign index = mem_address[(OFFSET_BITS+INDEX_BITS-1):OFFSET_BITS];
assign tag = mem_address[(ADDR_WIDTH-1):(OFFSET_BITS+INDEX_BITS)];

/***** BRAM for Tag Array *****/
genvar i;
generate
    for(i=0; i<NUM_WAYS; i=i+1) begin : tag_arrays
        dcache_tag_altram #(
            .TAG_BITS(TAG_BITS),
            .INDEX_BITS(INDEX_BITS)
        ) inst_dcache_tag_arr (
            .clock(clk),
            .aclr(rst),

            .rden(load),
            .rdaddress(index),
            .q(tag_array_out[i]),

            .wraddress(write_to_index),
            .data(tag_array_wdata),
            .wren(tag_load[i])
        );
    end
endgenerate

/***** BRAM for Data Array *****/
generate
    for(i=0; i<NUM_WAYS; i=i+1) begin: data_arrays
        dcache_data_altram #(
            .INDEX_BITS(INDEX_BITS),
            .OFFSET_BITS(OFFSET_BITS)
        ) inst_dcache_data_arr (
            .clock(clk),
            .aclr(rst),

            .rden(load),
            .rdaddress(index),
            .q(data_array_out[i]),
            
            .wraddress(write_to_index),
            .data(data_array_wdata),
            .wren(data_load[i]),
            .byteena_a(data_array_wben)
        );

    end
endgenerate

/***** BRAM for Valid Array *****/
generate
    for(i=0; i<NUM_WAYS; i=i+1) begin: valid_arrays
        dcache_bit_altram #(
            .INDEX_BITS(INDEX_BITS)
        ) inst_dcache_valid_arr (
            .clock(clk),
            .aclr(rst),

            .rden(load),
            .rdaddress(index),
            .q(valid_array_out[i]),

            .wraddress(write_to_index),
            .data(valid_array_wdata),
            .wren(valid_load[i])
        );
    end
endgenerate

/***** BRAM for Dirty Array *****/
generate
    for(i=0; i<NUM_WAYS; i=i+1) begin: dirty_arrays
        dcache_bit_altram #(
            .INDEX_BITS(INDEX_BITS)
        ) inst_dcache_dirty_arr(
            .clock(clk),
            .aclr(rst),

            .rden(load),
            .rdaddress(index),
            .q(dirty_array_out[i]),

            .wraddress(write_to_index),
            .data(dirty_array_wdata),
            .wren(dirty_load[i])
        );
    end
endgenerate

/***** LRU Array *****/
logic [(LOG2_WAYS-1):0] lru_arr_out_raw;
dcache_lru_altram #(
    .LOG2_WAYS(LOG2_WAYS),
    .INDEX_BITS(INDEX_BITS)
) inst_dcache_lru_arr(
    .clock(clk),
    .aclr(rst),
    
    .rden(load),
    .rdaddress(index),
    .q(lru_array_out),

    .wraddress(write_to_index),
    .data(lru_wdata),
    .wren(lru_load)
);

endmodule

