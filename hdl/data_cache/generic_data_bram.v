module generic_data_bram (
	aclr,
	byteena_a,
	clock,
	data,
	rdaddress,
	rden,
	wraddress,
	wren,
	q);
    
parameter DATA_WIDTH = 256;
parameter ADDR_WIDTH = 8;
parameter NUM_ENTRIES = 2**ADDR_WIDTH;
parameter NUM_BYTES_PER_ENTRY = DATA_WIDTH/8;

	input	  aclr;
	input	[(NUM_BYTES_PER_ENTRY-1):0]  byteena_a;
	input	  clock;
	input	[(DATA_WIDTH-1):0]  data;
	input	[(ADDR_WIDTH-1):0]  rdaddress;
	input	  rden;
	input	[(ADDR_WIDTH-1):0]  wraddress;
	input	  wren;
	output	[(DATA_WIDTH-1):0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0	  aclr;
	tri1	[(NUM_BYTES_PER_ENTRY-1):0]  byteena_a;
	tri1	  clock;
	tri1	  rden;
	tri0	  wren;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif


	wire [(DATA_WIDTH-1):0] sub_wire0;
	wire [(DATA_WIDTH-1):0] q = sub_wire0[(DATA_WIDTH-1):0];

	altsyncram	altsyncram_component (
				.aclr0 (aclr),
				.address_a (wraddress),
				.address_b (rdaddress),
				.byteena_a (byteena_a),
				.clock0 (clock),
				.data_a (data),
				.rden_b (rden),
				.wren_a (wren),
				.q_b (sub_wire0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({DATA_WIDTH{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "CLEAR0",
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Arria II GX",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = NUM_ENTRIES,
		altsyncram_component.numwords_b = NUM_ENTRIES,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "CLEAR0",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.rdcontrol_reg_b = "CLOCK0",
		altsyncram_component.read_during_write_mode_mixed_ports = "OLD_DATA",
		altsyncram_component.widthad_a = ADDR_WIDTH,
		altsyncram_component.widthad_b = ADDR_WIDTH,
		altsyncram_component.width_a = DATA_WIDTH,
		altsyncram_component.width_b = DATA_WIDTH,
		altsyncram_component.width_byteena_a = NUM_BYTES_PER_ENTRY;


endmodule