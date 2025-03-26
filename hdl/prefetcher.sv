module prefetcher (
    // Control Signals
    input logic         fetch_i,        // cache controller indicates memory fetch
    input logic         pref_resp_i,    // cache controller indicates prefetch complete
    output logic        pref_read_o,    // prefetcher requests a read
    output reg  [31:0]  pref_addr_o,    // prefetcher address (should be missed addr + 4)

    // CPU memory signals
    input logic [31:0]  mem_addr_i    // mem addr that missed
);

always @(posedge fetch_i, posedge pref_resp_i) begin
    if (fetch_i) begin
        pref_addr_o <= mem_addr_i + 32'h20;
        pref_read_o <= 1'b1;    
    end else if (pref_resp_i) begin
        pref_read_o <= 1'b0;
    end
    
end

endmodule : prefetcher