module data_cache_state_registers #(
    parameter OFFSET_BITS = 5,
    parameter INDEX_BITS = 8,
    
    parameter ADDR_WIDTH  = 32,
    parameter LOG2_WAYS   = 3, // 1 - 2 way. 2 - 4 way. 3 - 8 way.
    parameter DATA_WIDTH  = 32,

    /* These should be calculations instead of hard numbers. */
    /* Calculation provided by upper layer to simplify code. */
    parameter CACHELINE_BIT_WIDTH = 256,
    parameter BYTES_IN_CACHELINE = 32,
    parameter BYTES_IN_CPUWORD = 4,
    parameter TAG_BITS = 19,
    parameter NUM_WAYS = 8
) (
    input clk, rst, load,

    input logic [(OFFSET_BITS-1):0] offset_in,
    input logic [(INDEX_BITS-1):0] index_in,
    input logic [(TAG_BITS-1):0] tag_in,
    input logic [(TAG_BITS-1):0] tag_array_in [(NUM_WAYS-1):0],
    input logic [(CACHELINE_BIT_WIDTH-1):0] data_array_in [(NUM_WAYS-1):0],
    input logic valid_array_in [(NUM_WAYS-1):0],
    input logic dirty_array_in [(NUM_WAYS-1):0],
    input logic [(LOG2_WAYS-1):0] lru_in,
    input logic [(CACHELINE_BIT_WIDTH-1):0] mem_wdata_line_in,
    input logic [(BYTES_IN_CACHELINE-1):0] mem_wben_line_in,
    input logic mem_read_in,
    input logic mem_write_in,

    output logic [(OFFSET_BITS-1):0] offset_out,
    output logic [(INDEX_BITS-1):0] index_out,
    output logic [(TAG_BITS-1):0] tag_out,
    output logic [(TAG_BITS-1):0] tag_array_out [(NUM_WAYS-1):0],
    output logic [(CACHELINE_BIT_WIDTH-1):0] data_array_out [(NUM_WAYS-1):0],
    output logic valid_array_out [(NUM_WAYS-1):0],
    output logic dirty_array_out [(NUM_WAYS-1):0],
    output logic [(LOG2_WAYS-1):0] lru_out,
    output logic [(CACHELINE_BIT_WIDTH-1):0] mem_wdata_line_out,
    output logic [(BYTES_IN_CACHELINE-1):0] mem_wben_line_out,
    output logic mem_read_out,
    output logic mem_write_out
);

always_ff @(posedge clk) begin
    if(rst) begin
        offset_out <= 0;
        index_out <= 0;
        tag_out <= 0;
        mem_wdata_line_out <= 0;
        mem_wben_line_out <= 0;
        mem_read_out <= 0;
        mem_write_out <= 0;
    end else if (load) begin
        offset_out <= offset_in;
        index_out <= index_in;
        tag_out <= tag_in;
        mem_wdata_line_out <= mem_wdata_line_in;
        mem_wben_line_out <= mem_wben_line_in;
        mem_read_out <= mem_read_in;
        mem_write_out <= mem_write_in;
    end
end

/* BRAM signals. Not latched! */
assign tag_array_out = tag_array_in;
assign data_array_out = data_array_in;
assign valid_array_out = valid_array_in;
assign dirty_array_out = dirty_array_in;
assign lru_out = lru_in;

endmodule