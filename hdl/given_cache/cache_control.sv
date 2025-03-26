module cache_control (
  input clk,

  /* CPU memory data signals */
  input         mem_read,
  input         mem_write,
  output logic  mem_resp,

  /* Physical memory data signals */
  input         pmem_resp,
  output logic  pmem_read,
  output logic  pmem_write,

  /* Control signals */
  output logic  tag_load,
  output logic  valid_load,
  output logic  dirty_load,
  output logic  dirty_in,
  input         dirty_out,

  input               hit,
  output logic [1:0]  writing,

  // Prefetcher signals
  input         pref_read_i,      // signal from prefetcher to do a prefetch
  output logic  use_pref_addr_o,  // switch datapath mem_addr to mem_addr + 32
  output logic  hook_pref_addr_o, // hook pmem to pref addr for prefetching
  output logic  fetch_o,          // tell prefetcher a fetch occurred
  output logic  pref_resp_o       // respond to prefetcher that prefetch finished
);

/* State Enumeration */
enum int unsigned {
  check_hit,
  read_mem,
  check_pref_hit,
  init_pref,
  pref_wait,
  pref_resp
} state, next_state;

/* State Control Signals */
always_comb begin : state_actions

  /* Defaults */
  tag_load = 1'b0;
  valid_load = 1'b0;
  dirty_load = 1'b0;
  dirty_in = 1'b0;
  writing = 2'b11;

  mem_resp = 1'b0;
  pmem_write = 1'b0;
  pmem_read = 1'b0;

  use_pref_addr_o = 1'b0;
  fetch_o = 1'b0;
  pref_resp_o = 1'b0;
  hook_pref_addr_o = 1'b0;

  case (state)
    check_hit: begin
      if (mem_read || mem_write) begin
        if (hit) begin
          mem_resp = 1'b1;
          if (mem_write) begin
            dirty_load = 1'b1;
            dirty_in = 1'b1;
            writing = 2'b01;
          end
        end else begin
          if (dirty_out)
            pmem_write = 1'b1;
        end
      end
    end

    read_mem: begin
      pmem_read = 1'b1;
      writing = 2'b00;
      fetch_o = 1'b1;
      if (pmem_resp) begin
        tag_load = 1'b1;
        valid_load = 1'b1;
      end
      dirty_load = 1'b1;
      dirty_in = 1'b0;
    end

    // check if prefetched addr is already present
    check_pref_hit: begin
      use_pref_addr_o = 1'b1; // use prefetched addr (cline + 1)
      if (hit) begin
        pref_resp_o = 1'b1;
      end else if (dirty_out) begin // cline miss, must evict dirty cline
        pmem_write = 1'b1;
      end
    end

    // initialize read of memory with prefetched address
    init_pref: begin
      use_pref_addr_o = 1'b1; // use prefetched addr (cline + 1)
      pmem_read = 1'b1;
      hook_pref_addr_o = 1'b1;
    end

    // respond to CPU requests while prefetching
    pref_wait: begin
      pmem_read = 1'b1;
      hook_pref_addr_o = 1'b1;

      if (hit) begin
        mem_resp = 1'b1;
        if (mem_write) begin
          dirty_load = 1'b1;
          dirty_in = 1'b1;
          writing = 2'b01;
        end
      end
    end

    // store prefetched request in cline
    pref_resp: begin  // respond to prefetcher, store prefetched memory
      use_pref_addr_o = 1'b1;
      //if (pmem_resp) begin
      tag_load = 1'b1;    // store tag
      valid_load = 1'b1;  // store valid 1
      writing = 2'b00;    // load from memory
      dirty_load = 1'b1;  // newly read cline is clean
      dirty_in = 1'b0;
      hook_pref_addr_o = 1'b1;
      //end
    end
  endcase
end

/* Next State Logic */
always_comb begin : next_state_logic

  /* Default state transition */
  next_state = state;

  case(state)
    check_hit: begin
      if ((mem_read || mem_write) && !hit) begin  // cache miss
        if (dirty_out) begin  // writeback cline
          if (pmem_resp)
            next_state = read_mem;  // once writeback complete, read new cline
        end else begin
          next_state = read_mem;  // no writeback necessary, read new cline
        end
      end else if (pref_read_i) begin
        next_state = check_pref_hit;
      end
    end

    read_mem: begin
      if (pmem_resp)
        next_state = check_pref_hit;
    end

    check_pref_hit: begin
      if (!hit) begin               // prefetched cline not present already
        if (dirty_out) begin        // prefetched cline must be evicted
          if (pmem_resp) begin      // writeback complete
            next_state = init_pref;
          end
        end else begin              // no writeback necessary, read new cline 
          next_state = init_pref;
        end
      end else begin
        next_state = check_hit;       // prefetched cline already in cache, no need to prefetch
      end
    end

    init_pref: begin
      next_state = pref_wait;
    end

    pref_wait: begin
      if (pmem_resp) begin
        next_state = pref_resp;
      end
    end

    pref_resp: begin
      next_state = check_hit;
    end
  endcase
end

/* Next State Assignment */
always_ff @(posedge clk) begin: next_state_assignment
   state <= next_state;
end

// synthesis translate_off
real icache_hits, icache_misses, inst_read;
real pref_hits, pref_misses, pref_read;
real hits_while_pref;
real cpu_wait_time, avg_mem_latency;
real icache_perf;
real pmem_fetches;

always_ff @(posedge clk) begin
  if (mem_resp)
    inst_read <= inst_read + 1;
  if (state == check_hit && next_state == read_mem)
    icache_misses <= icache_misses + 1;

  if (state == check_pref_hit) begin
    if (next_state == init_pref)
      pref_misses <= pref_misses + 1;
    if (next_state == check_hit)
      pref_hits <= pref_hits + 1;
  end

  if (state == pref_wait && mem_resp)
    hits_while_pref <= hits_while_pref + 1;

  if (mem_read || mem_write)
    cpu_wait_time <= cpu_wait_time + 1;
end

always_comb begin
  icache_hits = inst_read - icache_misses;
  pmem_fetches = icache_misses + pref_misses;

  if (inst_read == 0) begin
    icache_perf = 0;
    avg_mem_latency = 0;
  end else begin
    icache_perf = icache_hits / inst_read;
    avg_mem_latency = cpu_wait_time / inst_read;
  end
end

// synthesis translate_on

endmodule : cache_control
