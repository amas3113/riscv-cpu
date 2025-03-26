module dcache_lru_altram #(
    parameter LOG2_WAYS = 3,
    parameter INDEX_BITS = 8
) (
    clock, aclr, rden, rdaddress, q, wren, wraddress, data
);

parameter NUM_ENTRIES = (2**INDEX_BITS);

input clock;
input aclr;

input rden;
input [(INDEX_BITS-1):0] rdaddress;
output logic [(LOG2_WAYS-1):0] q;

input wren;
input [(INDEX_BITS-1):0] wraddress;
input [(LOG2_WAYS-1):0] data;

logic [(LOG2_WAYS-1):0] q1, q2;
assign q = q2;

/* Shadow BRAM. */
// synthesis translate_off
logic [(LOG2_WAYS-1):0] mem [NUM_ENTRIES]  /* synthesis ramstyle = "M9K" */;

always_ff @(posedge clock) begin
    if(q1 != q2)
        $display("%m @ %0t ps: q1 and q2 mismatch", $time);
end

always_ff @(posedge clock) begin
    if(aclr) begin
        for(int c=0; c < NUM_ENTRIES; c=c+1)
            mem[c] <= 0;
    end else begin
        if (wren)
            mem[wraddress] = data;
        
        if (rden)
            q1 = mem[rdaddress];
    end
end
// synthesis translate_on

/* Real BRAM */
logic last_rden;
logic last_wren;
logic [(INDEX_BITS-1):0] last_wraddress;
logic [(INDEX_BITS-1):0] last_rdaddress;
logic rden_override;

logic [(LOG2_WAYS-1):0] last_wdata;
logic [(LOG2_WAYS-1):0] bram_q_raw;

always_ff @(posedge clock) begin
    last_rden      <= rden;
    last_wren      <= wren;
    last_wraddress <= wraddress;
    last_rdaddress <= rdaddress;
    last_wdata     <= data;
end

generic_bram #(
	.DATA_WIDTH(LOG2_WAYS),
	.ADDR_WIDTH(INDEX_BITS)
) inst_dcache_tag_bram(
// dcache_lru_bram inst_dcache_tag_bram(
    .clock, .aclr,
    .rden(rden || rden_override), .rdaddress, .q(bram_q_raw),
    .wren, .wraddress, .data
);

always_comb begin
    rden_override = 0;
    q2 = bram_q_raw;

    if(last_wren && last_rden && last_wraddress == last_rdaddress) begin
        q2 = last_wdata;
        if(rdaddress == last_rdaddress)
            rden_override = 1;
    end
end


endmodule