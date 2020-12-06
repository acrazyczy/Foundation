// RISCV32I CPU top module
// port modification allowed for debugging purposes

module cpu(
	input  wire                 clk_in,			// system clock signal
	input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

	input  wire [ 7:0]          mem_din,		// data input bus
	output wire [ 7:0]          mem_dout,		// data output bus
	output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
	output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

	IF IF(
		.clk_in(),
		.rst_in(),
		.rdy_in(),

		.icache_if_rdy_in(),
		.icache_if_miss_in(),
		.icache_if_inst_inst_in(),
		.if_icache_en_out(),
		.if_icache_inst_addr_out(),

		.if_instqueue_en_out(),
		.if_instqueue_inst_out(),
		.if_instqueue_pc_out(),
		.instqueue_if_rdy_in(),

		.bp_if_en_in(),
		.bp_if_pc_in(),

		.decoder_if_en_in(),
		.decoder_if_pc_in(),

		.rob_if_en_in(),
		.rob_if_pc_in()
	);

	instqueue instqueue(
		.clk_in                    (clk_in),
		.rst_in                    (rst_in),
		.rdy_in                    (rdy_in),

		.if_instqueue_en_in        (if_instqueue_en_in),
		.if_instqueue_inst_in      (if_instqueue_inst_in),
		.if_instqueue_pc_in        (if_instqueue_pc_in),
		.instqueue_if_rdy_out      (instqueue_if_rdy_out),

		.rs_instqueue_rdy_in       (rs_instqueue_rdy_in)

		.rob_instqueue_rst_in      (rob_instqueue_rst_in)
		.rob_instqueue_rdy_in      (rob_instqueue_rdy_in)
	);

endmodule