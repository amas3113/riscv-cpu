module dcache_bit_altram #(
    parameter INDEX_BITS = 8
) (
    input clock,
    input aclr,
    
    input rden,
    input [(INDEX_BITS-1):0] rdaddress,
    output logic q,

    input wren,
    input [(INDEX_BITS-1):0] wraddress,
    input data
);

parameter NUM_ENTRIES = (2**INDEX_BITS);

logic q1, q2;

assign q = q2;

/* Shadow BRAM. */
// synthesis translate_off
reg mem [NUM_ENTRIES] /* synthesis ramstyle = "M9K" */;

always_ff @(posedge clock) begin
    if(q1 != q2)
        $display("%m @ %0t ps: q1 and q2 mismatch", $time);
end

always_ff @(posedge clock) begin
    if(aclr) begin
        for(int c=0; c<NUM_ENTRIES; c=c+1)
            mem[c] = 0;
    end
	 
    if (wren)
        mem[wraddress] = data;

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

logic last_wdata;
logic bram_q_raw;

always_ff @(posedge clock) begin
    last_rden      <= rden;
    last_wren      <= wren;
    last_wraddress <= wraddress;
    last_rdaddress <= rdaddress;
    last_wdata     <= data;
end

generic_bram #(
    .DATA_WIDTH(1),
    .ADDR_WIDTH(INDEX_BITS)
) inst_dcache_bit_bram (
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
