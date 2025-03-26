module dcache_data_altram #(
    parameter INDEX_BITS  = 8,
    parameter OFFSET_BITS = 5
) (
    clock, aclr, rden, rdaddress, q, wren, wraddress, data, byteena_a
);

parameter CACHELINE_BIT_WIDTH = 8*(2**OFFSET_BITS); // Real computer engineers use "<<" instead of "**" lol
parameter BYTES_IN_CACHELINE = (2**OFFSET_BITS);
parameter NUM_ENTRIES = (2**INDEX_BITS);

input clock;
input aclr;

input rden;
input [(INDEX_BITS-1):0] rdaddress;
output logic [(CACHELINE_BIT_WIDTH-1):0] q;

input wren;
input [(INDEX_BITS-1):0] wraddress;
input [(CACHELINE_BIT_WIDTH-1):0] data;
input [(BYTES_IN_CACHELINE-1):0] byteena_a;

logic [(CACHELINE_BIT_WIDTH-1):0] q1, q2;

assign q = q2;

// synthesis translate_off
reg [(CACHELINE_BIT_WIDTH-1):0] mem [NUM_ENTRIES] /* synthesis ramstyle = "M9K" */;

always_ff @(posedge clock) begin
    if(q1 != q2)
        $display("%m @ %0t ps: q1 and q2 mismatch", $time);
end

always_ff @(posedge clock) begin
    for (int i=0; i < BYTES_IN_CACHELINE; i=i+1)
        mem[wraddress][8*i +:8] = (wren && byteena_a[i]) ? data[8*i +:8] : mem[wraddress][8*i +:8];

    if (rden)
        q1 = mem[rdaddress];
end
// synthesis translate_on

/* Real BRAM */
logic last_rden;
logic last_wren;
logic [(INDEX_BITS-1):0] last_wraddress;
logic [(INDEX_BITS-1):0] last_rdaddress;
logic rden_override;

logic [(CACHELINE_BIT_WIDTH-1):0] last_wdata;
logic [(CACHELINE_BIT_WIDTH-1):0] bram_q_raw;
logic [(CACHELINE_BIT_WIDTH-1):0] last_extended_mask;

always_ff @(posedge clock) begin
    last_rden      <= rden;
    last_wren      <= wren;
    last_wraddress <= wraddress;
    last_rdaddress <= rdaddress;
    last_wdata     <= data;
    for(int i=0; i<CACHELINE_BIT_WIDTH; i=i+1)
        last_extended_mask[i] <= byteena_a[i/8];
end

generic_data_bram #(
    .DATA_WIDTH(CACHELINE_BIT_WIDTH),
    .ADDR_WIDTH(INDEX_BITS)
) inst_dcache_data(
    .clock, .aclr,
    .rden(rden || rden_override), .rdaddress, .q(bram_q_raw),
    .wren, .wraddress, .data, .byteena_a
);

always_comb begin
    rden_override = 0;
    q2 = bram_q_raw;

    if(last_wren && last_rden && last_wraddress == last_rdaddress) begin
        q2 = (bram_q_raw & (~last_extended_mask)) | (last_wdata & last_extended_mask);
        if(rdaddress == last_rdaddress)
            rden_override = 1;
    end
end


endmodule