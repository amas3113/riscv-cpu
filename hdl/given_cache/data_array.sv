module data_array (
  input                 clk,
  input [31:0]          write_en,
  input [2:0]           rindex,
  input [2:0]           windex,
  input [255:0]         datain,
  output logic [255:0]  dataout
);

logic [255:0] data [8] = '{default: '0};

always_comb begin
  for (int i = 0; i < 32; i++) begin
    dataout[8*i +: 8] = (write_en[i] & (rindex == windex)) ? datain[8*i +: 8] : data[rindex][8*i +: 8];
  end
end

always_ff @(posedge clk) begin
  for (int i = 0; i < 32; i++) begin
	  data[windex][8*i +: 8] <= write_en[i] ? datain[8*i +: 8] : data[windex][8*i +: 8];
  end
end

endmodule : data_array
