module data_cacheline_adapter #(
  parameter CACHELINE_BIT_WIDTH = 256,
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32,
  parameter OFFSET_BITS = 5
) (
  mem_wdata_line, mem_rdata_line, mem_wdata, mem_rdata, mem_byte_enable, mem_byte_enable_line, address
);

parameter DATA_WORDS_PER_CACHELINE = CACHELINE_BIT_WIDTH / DATA_WIDTH; // 8
parameter BYTES_IN_CACHELINE = CACHELINE_BIT_WIDTH/8;                  // 32
parameter BYTES_IN_DATA = DATA_WIDTH/8;                                // 4
parameter LOG_BYTE_ADDRESSING = ($clog2(DATA_WIDTH) - 3); // Bits in address used for indexing a byte in a word.

output logic [(CACHELINE_BIT_WIDTH-1):0] mem_wdata_line;
input  logic [(CACHELINE_BIT_WIDTH-1):0] mem_rdata_line;
input  logic [(DATA_WIDTH-1):0] mem_wdata;
output logic [(DATA_WIDTH-1):0] mem_rdata;
input logic  [(BYTES_IN_DATA-1):0] mem_byte_enable;
output logic [(BYTES_IN_CACHELINE-1):0] mem_byte_enable_line;
input logic  [(ADDR_WIDTH-1):0] address;

assign mem_wdata_line = {DATA_WORDS_PER_CACHELINE{mem_wdata}};
assign mem_rdata = mem_rdata_line[(DATA_WIDTH * address[(OFFSET_BITS-1):LOG_BYTE_ADDRESSING]) +: DATA_WIDTH];
assign mem_byte_enable_line = {{(BYTES_IN_CACHELINE-BYTES_IN_DATA){1'b0}}, mem_byte_enable} << (address[(OFFSET_BITS-1):LOG_BYTE_ADDRESSING]*BYTES_IN_DATA);

endmodule : data_cacheline_adapter
