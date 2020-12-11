// RISCV32I CPU top module
// port modification allowed for debugging purposes

`include "constant.vh"

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

// ROB reset
wire rob_rst;

// reservation station <-> address unit
wire[`IDWidth - 1 : 0] rs_addrunit_a;
wire[`IDWidth - 1 : 0] rs_addrunit_vj;
wire[`ROBWidth - 1 : 0] rs_addrunit_dest;
wire[`IDWidth - 1 : 0] rs_addrunit_opcode;

// load buffer <-> address unit
wire addrunit_lbuffer_en;
wire[`AddressWidth - 1 : 0] addrunit_lbuffer_a;
wire[`ROBWidth - 1 : 0] addrunit_lbuffer_dest;
wire[`IDWidth - 1 : 0] addrunit_lbuffer_opcode;

// reorder buffer <-> address unit
wire[`ROBWidth - 1 : 0] addrunit_rob_h;
wire[`AddressWidth - 1 : 0] addrunit_rob_address;

// ALU <-> reservation station
wire[`IDWidth - 1 : 0] rs_alu_a;
wire[`IDWidth - 1 : 0] rs_alu_vj;
wire[`IDWidth - 1 : 0] rs_alu_vk;
wire[`ROBWidth - 1 : 0] rs_alu_dest;
wire[`AddressWidth - 1 : 0] rs_alu_pc;
wire[`InstTypeWidth - 1 : 0] rs_alu_opcode;

// ALU <-> reorder buffer
wire[`ROBWidth - 1 : 0] alu_rob_h;
wire[`IDWidth - 1 : 0] alu_rob_result;

// branch predictor <-> decoder
wire decoder_bp_en;
wire[`AddressWidth - 1 : 0] decoder_bp_pc;
wire[`AddressWidth - 1 : 0] decoder_bp_target;

// branch predictor <-> instruction queue
wire bp_instqueue_rst;

// branch predictor <-> instruction fetch
wire bp_if_en;
wire[`AddressWidth - 1 : 0] bp_if_pc;

// branch predictor <-> dispatcher
wire bp_dispatcher_taken;

// branch predictor <-> reorder buffer
wire rob_bp_en;
wire rob_bp_correct;
wire[`AddressWidth - 1 : 0] rob_bp_pc;

// datactrl <-> reorder buffer
wire rob_datactrl_en;
wire[2 : 0] rob_datactrl_width;
wire[`AddressWidth - 1 : 0] rob_datactrl_addr;
wire[`IDWidth - 1 : 0] rob_datactrl_data;
wire datactrl_rob_en;

// datactrl <-> load buffer
wire lbuffer_datactrl_en;
wire[`AddressWidth - 1 : 0] lbuffer_datactrl_addr;
wire[2 : 0] lbuffer_datactrl_width;
wire lbuffer_datactrl_sgn;
wire datactrl_lbuffer_en;
wire[`IDWidth - 1 : 0] datactrl_lbuffer_data;

// datactrl <-> ramctrl
wire datactrl_ramctrl_data_en;
wire datactrl_ramctrl_data_rw;
wire datactrl_ramctrl_data_sgn;
wire [2 : 0] datactrl_ramctrl_data_width;
wire ramctrl_datactrl_data_rdy;
wire[`AddressWidth - 1 : 0] datactrl_ramctrl_data_addr;
wire[`IDWidth - 1 : 0] datactrl_ramctrl_data_data;
wire[`IDWidth - 1 : 0] ramctrl_datactrl_data_data;

// decoder <-> instruction queue
wire instqueue_decoder_en;
wire[`IDWidth - 1 : 0] instqueue_decoder_inst;
wire[`AddressWidth - 1 : 0] instqueue_decoder_pc;
wire decoder_instqueue_rst;

// decoder <-> instruction fetch
wire decoder_if_en;
wire[`AddressWidth - 1 : 0] decoder_if_addr;

// decoder <-> dispatcher
wire decoder_dispatcher_en;
wire[`RegWidth - 1 : 0] decoder_dispatcher_rs, decoder_dispatcher_rt, decoder_dispatcher_rd;
wire[`IDWidth - 1 : 0] decoder_dispatcher_imm;
wire[`InstTypeWidth - 1 : 0] decoder_dispatcher_opcode;
wire[`AddressWidth - 1 : 0] decoder_dispatcher_pc;
wire[`AddressWidth - 1 : 0] decoder_dispatcher_target;

// dispatcher <-> regfile
wire[`RegWidth - 1 : 0] dispatcher_regfile_rs;
wire regfile_dispatcher_rs_busy;
wire[`IDWidth - 1 : 0] regfile_dispatcher_rs;
wire[`ROBWidth - 1 : 0] regfile_dispatcher_rs_reorder;
wire[`RegWidth - 1 : 0] dispatcher_regfile_rt;
wire regfile_dispatcher_rt_busy;
wire[`IDWidth - 1 : 0] regfile_dispatcher_rt;
wire[`ROBWidth - 1 : 0] regfile_dispatcher_rt_reorder;
wire dispatcher_regfile_rd_en;
wire[`RegWidth - 1 : 0] dispatcher_regfile_rd;
wire[`AddressWidth - 1 : 0] dispatcher_regfile_reorder;

// dispatcher <-> reservation station
wire dispatcher_rs_en;
wire[`IDWidth - 1 : 0] dispatcher_rs_a;
wire[`ROBWidth - 1 : 0] dispatcher_rs_qj;
wire[`IDWidth - 1 : 0] dispatcher_rs_vj;
wire[`ROBWidth - 1 : 0] dispatcher_rs_qk;
wire[`IDWidth - 1 : 0] dispatcher_rs_vk;
wire[`ROBWidth - 1 : 0] dispatcher_rs_dest;
wire[`AddressWidth - 1 : 0] dispatcher_rs_pc;
wire[`InstTypeWidth - 1 : 0] dispatcher_rs_opcode;

// dispatcher <-> reorder buffer
wire[`ROBWidth - 1 : 0] dispatcher_rob_rs_h;
wire rob_dispatcher_rs_ready;
wire[`IDWidth - 1 : 0] rob_dispatcher_rs_value;
wire[`ROBWidth - 1 : 0] dispatcher_rob_rt_h;
wire rob_dispatcher_rt_ready;
wire[`IDWidth - 1 : 0] rob_dispatcher_rt_value;
wire[`ROBWidth - 1 : 0] rob_dispatcher_b;
wire dispatcher_rob_en;
wire[`InstTypeWidth - 1 : 0] dispatcher_rob_opcode;
wire[`RegWidth - 1 : 0] dispatcher_rob_dest;
wire[`AddressWidth - 1 : 0] dispatcher_rob_pc;
wire[`AddressWidth - 1 : 0] dispatcher_rob_target;
wire dispatcher_rob_taken;

// icache <-> instruction fetch
wire[`AddressWidth - 1 : 0] if_icache_inst_addr;
wire icache_if_miss;
wire[`IDWidth - 1 : 0] icache_if_inst_inst;

// icache <-> ramctrl
wire icache_ramctrl_en;
wire ramctrl_icache_inst_rdy;
wire[`AddressWidth - 1 : 0] icache_ramctrl_addr;
wire[`IDWidth - 1 : 0] ramctrl_icache_inst_inst;

// instruction fetch <-> to instruction queue
wire if_instqueue_en;
wire[`IDWidth - 1 : 0] if_instqueue_inst;
wire[`AddressWidth - 1 : 0] if_instqueue_pc;
wire instqueue_if_rdy;

// instruction fetch <-> reorder buffer
wire rob_if_en;
wire[`AddressWidth - 1 : 0] rob_if_pc;

// instruction queue <-> reservation station
wire rs_instqueue_rdy;

// instruction queue <-> reorder buffer
wire rob_instqueue_rdy;

// load buffer <-> reorder buffer
wire[`ROBWidth - 1 : 0] lbuffer_rob_h;
wire[`IDWidth - 1 : 0] lbuffer_rob_result;
wire lbuffer_rob_en;
wire[`ROBWidth - 1 : 0] lbuffer_rob_rob_index;
wire[`LBWidth - 1 : 0] lbuffer_rob_lbuffer_index;
wire[`LBWidth - 1 : 0] rob_lbuffer_index;

// load buffer <-> reservation station
wire lbuffer_rs_rdy;

// regfile <-> reorder buffer
wire rob_regfile_en;
wire[`RegWidth - 1 : 0] rob_regfile_d;
wire[`IDWidth - 1 : 0] rob_regfile_value;
wire[`ROBWidth - 1 : 0] rob_regfile_h;
wire rob_regfile_rst;

//reorder buffer <-> reservation station
wire[`ROBWidth - 1 : 0] rs_rob_h;
wire[`IDWidth - 1 : 0] rs_rob_result;

	addrunit addrunit(
		.clk_in                     (clk_in),
		.rst_in                     (rst_in),
		.rdy_in                     (rdy_in),

		.rs_addrunit_a_in           (rs_addrunit_a),
		.rs_addrunit_vj_in          (rs_addrunit_vj),
		.rs_addrunit_dest_in        (rs_addrunit_dest),
		.rs_addrunit_opcode_in      (rs_addrunit_opcode),

		.addrunit_lbuffer_en_out    (addrunit_lbuffer_en),
		.addrunit_lbuffer_a_out     (addrunit_lbuffer_a),
		.addrunit_lbuffer_dest_out  (addrunit_lbuffer_dest),
		.addrunit_lbuffer_opcode_out(addrunit_lbuffer_opcode),

		.rob_addrunit_rst_in        (rob_rst),
		.addrunit_rob_h_out         (addrunit_rob_h),
		.addrunit_rob_address_out   (addrunit_rob_address)
	);

	ALU ALU(
		.clk_in            (clk_in),
		.rst_in            (rst_in),
		.rdy_in            (rdy_in),

		.rs_alu_a_in       (rs_alu_a),
		.rs_alu_vj_in      (rs_alu_vj),
		.rs_alu_vk_in      (rs_alu_vk),
		.rs_alu_dest_in    (rs_alu_dest),
		.rs_alu_pc_in      (rs_alu_pc),
		.rs_alu_opcode_in  (rs_alu_opcode),

		.rob_alu_rst_in    (rob_rst),
		.alu_rob_h_out     (alu_rob_h),
		.alu_rob_result_out(alu_rob_result)
	);

	BP BP(
		.clk_in                 (clk_in),
		.rst_in                 (rst_in),
		.rdy_in                 (rdy_in),

		.decoder_bp_en_in       (decoder_bp_en),
		.decoder_bp_pc_in       (decoder_bp_pc),
		.decoder_bp_target_in   (decoder_bp_target),

		.bp_instqueue_rst_out   (bp_instqueue_rst),

		.bp_if_en_out           (bp_if_en),
		.bp_if_pc_out           (bp_if_pc),

		.bp_dispatcher_taken_out(bp_dispatcher_taken),

		.rob_bp_en_in           (rob_bp_en),
		.rob_bp_correct_in      (rob_bp_correct),
		.rob_bp_pc_in           (rob_bp_pc)
	);

	datactrl datactrl(
		.clk_in                         (clk_in),
		.rst_in                         (rst_in),
		.rdy_in                         (rdy_in),

		.rob_datactrl_en_in             (rob_datactrl_en),
		.rob_datactrl_width_in          (rob_datactrl_width),
		.rob_datactrl_addr_in           (rob_datactrl_addr),
		.rob_datactrl_data_in           (rob_datactrl_data),
		.datactrl_rob_en_out            (datactrl_rob_en),

		.lbuffer_datactrl_en_in         (lbuffer_datactrl_en),
		.lbuffer_datactrl_addr_in       (lbuffer_datactrl_addr),
		.lbuffer_datactrl_width_in      (lbuffer_datactrl_width),
		.lbuffer_datactrl_sgn_in        (lbuffer_datactrl_sgn),
		.datactrl_lbuffer_en_out        (datactrl_lbuffer_en),
		.datactrl_lbuffer_data_out      (datactrl_lbuffer_data),

		.datactrl_ramctrl_data_en_out   (datactrl_ramctrl_data_en),
		.datactrl_ramctrl_data_rw_out   (datactrl_ramctrl_data_rw),
		.datactrl_ramctrl_data_sgn_out  (datactrl_ramctrl_data_sgn),
		.datactrl_ramctrl_data_width_out(datactrl_ramctrl_data_width),
		.ramctrl_datactrl_data_rdy_in   (ramctrl_datactrl_data_rdy),
		.datactrl_ramctrl_data_addr_out (datactrl_ramctrl_data_addr),
		.datactrl_ramctrl_data_data_out (datactrl_ramctrl_data_data),
		.ramctrl_datactrl_data_data_in  (ramctrl_datactrl_data_data)
	);

	decoder decoder(
		.clk_in                       (clk_in),
		.rst_in                       (rst_in),
		.rdy_in                       (rdy_in),

		.instqueue_decoder_en_in      (instqueue_decoder_en),
		.instqueue_decoder_inst_in    (instqueue_decoder_inst),
		.instqueue_decoder_pc_in      (instqueue_decoder_pc),
		.decoder_instqueue_rst_out    (decoder_instqueue_rst),

		.decoder_if_en_out            (decoder_if_en),
		.decoder_if_addr_out          (decoder_if_addr),

		.decoder_bp_target_out        (decoder_bp_target),
		.decoder_bp_en_out            (decoder_bp_en),
		.decoder_bp_pc_out            (decoder_bp_pc),

		.decoder_dispatcher_en_out    (decoder_dispatcher_en),
		.decoder_dispatcher_rs_out    (decoder_dispatcher_rs),
		.decoder_dispatcher_rt_out    (decoder_dispatcher_rt),
		.decoder_dispatcher_rd_out    (decoder_dispatcher_rd),
		.decoder_dispatcher_imm_out   (decoder_dispatcher_imm),
		.decoder_dispatcher_opcode_out(decoder_dispatcher_opcode),
		.decoder_dispatcher_pc_out    (decoder_dispatcher_pc),
		.decoder_dispatcher_target_out(decoder_dispatcher_target)
	);

	dispatcher dispatcher(
		.clk_in                          (clk_in),
		.rst_in                          (rst_in),
		.rdy_in                          (rdy_in),

		.decoder_dispatcher_en_in        (decoder_dispatcher_en),
		.decoder_dispatcher_rs_in        (decoder_dispatcher_rs),
		.decoder_dispatcher_rt_in        (decoder_dispatcher_rt),
		.decoder_dispatcher_rd_in        (decoder_dispatcher_rd),
		.decoder_dispatcher_imm_in       (decoder_dispatcher_imm),
		.decoder_dispatcher_opcode_in    (decoder_dispatcher_opcode),
		.decoder_dispatcher_pc_in        (decoder_dispatcher_pc),
		.decoder_dispatcher_target_in    (decoder_dispatcher_target),

		.bp_dispatcher_taken_in          (bp_dispatcher_taken),

		.dispatcher_regfile_rs_out       (dispatcher_regfile_rs),
		.regfile_dispatcher_rs_busy_in   (regfile_dispatcher_rs_busy),
		.regfile_dispatcher_rs_in        (regfile_dispatcher_rs),
		.regfile_dispatcher_rs_reorder_in(regfile_dispatcher_rs_reorder),
		.dispatcher_regfile_rt_out       (dispatcher_regfile_rt),
		.regfile_dispatcher_rt_busy_in   (regfile_dispatcher_rt_busy),
		.regfile_dispatcher_rt_in        (regfile_dispatcher_rt),
		.regfile_dispatcher_rt_reorder_in(regfile_dispatcher_rt_reorder),
		.dispatcher_regfile_rd_en_out    (dispatcher_regfile_rd_en),
		.dispatcher_regfile_rd_out       (dispatcher_regfile_rd),
		.dispatcher_regfile_reorder_out  (dispatcher_regfile_reorder),

		.dispatcher_rs_en_out            (dispatcher_rs_en),
		.dispatcher_rs_a_out             (dispatcher_rs_a),
		.dispatcher_rs_qj_out            (dispatcher_rs_qj),
		.dispatcher_rs_vj_out            (dispatcher_rs_vj),
		.dispatcher_rs_qk_out            (dispatcher_rs_qk),
		.dispatcher_rs_vk_out            (dispatcher_rs_vk),
		.dispatcher_rs_dest_out          (dispatcher_rs_dest),
		.dispatcher_rs_pc_out            (dispatcher_rs_pc),
		.dispatcher_rs_opcode_out        (dispatcher_rs_opcode),

		.dispatcher_rob_rs_h_out         (dispatcher_rob_rs_h),
		.rob_dispatcher_rs_ready_in      (rob_dispatcher_rs_ready),
		.rob_dispatcher_rs_value_in      (rob_dispatcher_rs_value),
		.dispatcher_rob_rt_h_out         (dispatcher_rob_rt_h),
		.rob_dispatcher_rt_ready_in      (rob_dispatcher_rt_ready),
		.rob_dispatcher_rt_value_in      (rob_dispatcher_rt_value),
		.rob_dispatcher_b_in             (rob_dispatcher_b),
		.dispatcher_rob_en_out           (dispatcher_rob_en),
		.dispatcher_rob_opcode_out       (dispatcher_rob_opcode),
		.dispatcher_rob_dest_out         (dispatcher_rob_dest),
		.dispatcher_rob_pc_out           (dispatcher_rob_pc),
		.dispatcher_rob_taken_out        (dispatcher_rob_taken),
		.dispatcher_rob_target_out       (dispatcher_rob_target)
	);

	icache icache(
		.clk_in                     (clk_in),
		.rst_in                     (rst_in),
		.rdy_in                     (rdy_in),

		.if_icache_inst_addr_in     (if_icache_inst_addr),
		.icache_if_miss_out         (icache_if_miss),
		.icache_if_inst_inst_out    (icache_if_inst_inst),

		.icache_ramctrl_en_out      (icache_ramctrl_en),
		.ramctrl_icache_inst_rdy_in (ramctrl_icache_inst_rdy),
		.icache_ramctrl_addr_out    (icache_ramctrl_addr),
		.ramctrl_icache_inst_inst_in(ramctrl_icache_inst_inst)
	);

	IF IF(
		.clk_in                 (clk_in),
		.rst_in                 (rst_in),
		.rdy_in                 (rdy_in),

		.icache_if_miss_in      (icache_if_miss),
		.icache_if_inst_inst_in (icache_if_inst_inst),
		.if_icache_inst_addr_out(if_icache_inst_addr),

		.if_instqueue_en_out    (if_instqueue_en),
		.if_instqueue_inst_out  (if_instqueue_inst),
		.if_instqueue_pc_out    (if_instqueue_pc),
		.instqueue_if_rdy_in    (instqueue_if_rdy),

		.bp_if_en_in            (bp_if_en),
		.bp_if_pc_in            (bp_if_pc),

		.decoder_if_en_in       (decoder_if_en),
		.decoder_if_addr_in       (decoder_if_addr),

		.rob_if_en_in           (rob_rst),
		.rob_if_pc_in           (rob_if_pc)
	);

	instqueue instqueue(
		.clk_in                    (clk_in),
		.rst_in                    (rst_in),
		.rdy_in                    (rdy_in),

		.if_instqueue_en_in        (if_instqueue_en),
		.if_instqueue_inst_in      (if_instqueue_inst),
		.if_instqueue_pc_in        (if_instqueue_pc),
		.instqueue_if_rdy_out      (instqueue_if_rdy),

		.rs_instqueue_rdy_in       (rs_instqueue_rdy),

		.rob_instqueue_rst_in      (rob_rst),
		.rob_instqueue_rdy_in      (rob_instqueue_rdy),

		.decoder_instqueue_rst_in  (decoder_instqueue_rst),
		.instqueue_decoder_en_out  (instqueue_decoder_en),
		.instqueue_decoder_inst_out(instqueue_decoder_inst),
		.instqueue_decoder_pc_out  (instqueue_decoder_pc),

		.bp_instqueue_rst_in       (bp_instqueue_rst)
	);

	lbuffer lbuffer(
		.clk_in                       (clk_in),
		.rst_in                       (rst_in),
		.rdy_in                       (rdy_in),

		.addrunit_lbuffer_en_in       (addrunit_lbuffer_en),
		.addrunit_lbuffer_a_in        (addrunit_lbuffer_a),
		.addrunit_lbuffer_dest_in     (addrunit_lbuffer_dest),
		.addrunit_lbuffer_opcode_in   (addrunit_lbuffer_opcode),

		.rob_lbuffer_rst_in           (rob__rst),
		.lbuffer_rob_h_out            (lbuffer_rob_h),
		.lbuffer_rob_result_out       (lbuffer_rob_result),
		.lbuffer_rob_en_out           (lbuffer_rob_en),
		.lbuffer_rob_rob_index_out    (lbuffer_rob_rob_index),
		.lbuffer_rob_lbuffer_index_out(lbuffer_rob_lbuffer_index),
		.rob_lbuffer_index_in         (rob_lbuffer_index),

		.lbuffer_rs_rdy_out           (lbuffer_rs_rdy),

		.lbuffer_datactrl_en_out      (lbuffer_datactrl_en),
		.lbuffer_datactrl_addr_out    (lbuffer_datactrl_addr),
		.lbuffer_datactrl_width_out   (lbuffer_datactrl_width),
		.lbuffer_datactrl_sgn_out     (lbuffer_datactrl_sgn),
		.datactrl_lbuffer_en_in       (datactrl_lbuffer_en),
		.datactrl_lbuffer_data_in     (datactrl_lbuffer_data)
	);

	ram_controller ram_controller(
		.clk_in       (clk_in),
		.rst_in       (rst_in),
		.rdy_in       (rdy_in),

		.inst_en_in   (icache_ramctrl_en),
		.inst_rdy_out (ramctrl_icache_inst_rdy),
		.inst_addr_in (icache_ramctrl_addr),
		.inst_inst_out(ramctrl_icache_inst_inst),

		.data_en_in   (datactrl_ramctrl_data_en),
		.data_rw_in   (datactrl_ramctrl_data_rw),
		.data_sgn_in  (datactrl_ramctrl_data_sgn),
		.data_width_in(datactrl_ramctrl_data_width),
		.data_rdy_out (ramctrl_datactrl_data_rdy),
		.data_addr_in (datactrl_ramctrl_data_addr),
		.data_data_in (datactrl_ramctrl_data_data),
		.data_data_out(ramctrl_datactrl_data_data),

		.ram_in       (mem_din),
		.ram_rw_out   (mem_wr),
		.ram_addr_out (mem_a),
		.ram_data_out (mem_dout)
	);

	regfile regfile(
		.clk_in                           (clk_in),
		.rst_in                           (rst_in),
		.rdy_in                           (rdy_in),

		.dispatcher_regfile_rs_in         (dispatcher_regfile_rs),
		.regfile_dispatcher_rs_busy_out   (regfile_dispatcher_rs_busy),
		.regfile_dispatcher_rs_out        (regfile_dispatcher_rs),
		.regfile_dispatcher_rs_reorder_out(regfile_dispatcher_rs_reorder),
		.dispatcher_regfile_rt_in         (dispatcher_regfile_rt),
		.regfile_dispatcher_rt_busy_out   (regfile_dispatcher_rt_busy),
		.regfile_dispatcher_rt_out        (regfile_dispatcher_rt),
		.regfile_dispatcher_rt_reorder_out(regfile_dispatcher_rt_reorder),
		.dispatcher_regfile_rd_en_in      (dispatcher_regfile_rd_en),
		.dispatcher_regfile_rd_in         (dispatcher_regfile_rd),
		.dispatcher_regfile_reorder_in    (dispatcher_regfile_reorder),

		.rob_regfile_en_in                (rob_regfile_en),
		.rob_regfile_d_in                 (rob_regfile_d),
		.rob_regfile_value_in             (rob_regfile_value),
		.rob_regfile_h_in                 (rob_regfile_h),
		.rob_regfile_rst_in               (rob_rst)
	);

	ROB ROB(
		.clk_in                      (clk_in),
		.rst_in                      (rst_in),
		.rdy_in                      (rdy_in),
		.rob_rst_out                 (rob_rst),

		.addrunit_rob_h_in           (addrunit_rob_h),
		.addrunit_rob_address_in     (addrunit_rob_address),

		.alu_rob_h_in                (alu_rob_h),
		.alu_rob_result_in           (alu_rob_result),

		.rob_bp_en_out               (rob_bp_en),
		.rob_bp_correct_out          (rob_bp_correct),
		.rob_bp_pc_out               (rob_bp_pc),

		.dispatcher_rob_rs_h_in      (dispatcher_rob_rs_h),
		.rob_dispatcher_rs_ready_out (rob_dispatcher_rs_ready),
		.rob_dispatcher_rs_value_out (rob_dispatcher_rs_value),
		.dispatcher_rob_rt_h_in      (dispatcher_rob_rt_h),
		.rob_dispatcher_rt_ready_out (rob_dispatcher_rt_ready),
		.rob_dispatcher_rt_value_out (rob_dispatcher_rt_value),
		.rob_dispatcher_b_out        (rob_dispatcher_b),
		.dispatcher_rob_en_in        (dispatcher_rob_en),
		.dispatcher_rob_opcode_in    (dispatcher_rob_opcode),
		.dispatcher_rob_dest_in      (dispatcher_rob_dest),
		.dispatcher_rob_pc_in        (dispatcher_rob_pc),
		.dispatcher_rob_taken_in     (dispatcher_rob_taken),
		.dispatcher_rob_target_in    (dispatcher_rob_target),

		.rob_if_pc_out               (rob_if_pc),

		.rob_instqueue_rdy_out       (rob_instqueue_rdy),

		.lbuffer_rob_h_in            (lbuffer_rob_h),
		.lbuffer_rob_result_in       (lbuffer_rob_result),
		.lbuffer_rob_en_in           (lbuffer_rob_en),
		.lbuffer_rob_rob_index_in    (lbuffer_rob_rob_index),
		.lbuffer_rob_lbuffer_index_in(lbuffer_rob_lbuffer_index),
		.rob_lbuffer_index_out       (rob_lbuffer_index),

		.rob_regfile_en_out          (rob_regfile_en),
		.rob_regfile_d_out           (rob_regfile_d),
		.rob_regfile_value_out       (rob_regfile_value),
		.rob_regfile_h_out           (rob_regfile_h),

		.rs_rob_h_in                 (rs_rob_h),
		.rs_rob_result_in            (rs_rob_result),

		.rob_datactrl_en_out         (rob_datactrl_en),
		.rob_datactrl_addr_out       (rob_datactrl_addr),
		.rob_datactrl_width_out      (rob_datactrl_width),
		.rob_datactrl_data_out       (rob_datactrl_data),
		.datactrl_rob_en_in          (datactrl_rob_en)
	);

	RS RS(
		.clk_in                 (clk_in),
		.rst_in                 (rst_in),
		.rdy_in                 (rdy_in),

		.rs_instqueue_rdy_out   (rs_instqueue_rdy),

		.dispatcher_rs_en_in    (dispatcher_rs_en),
		.dispatcher_rs_a_in     (dispatcher_rs_a),
		.dispatcher_rs_qj_in    (dispatcher_rs_qj),
		.dispatcher_rs_vj_in    (dispatcher_rs_vj),
		.dispatcher_rs_qk_in    (dispatcher_rs_qk),
		.dispatcher_rs_vk_in    (dispatcher_rs_vk),
		.dispatcher_rs_dest_in  (dispatcher_rs_dest),
		.dispatcher_rs_pc_in    (dispatcher_rs_pc),
		.dispatcher_rs_opcode_in(dispatcher_rs_opcode),

		.lbuffer_rs_rdy_in      (lbuffer_rs_rdy),

		.rs_rob_h_out           (rs_rob_h),
		.rs_rob_result_out       (rs_rob_result),
		.rob_rs_rst_in          (rob_rst),

		.rs_addrunit_a_out      (rs_addrunit_a),
		.rs_addrunit_vj_out     (rs_addrunit_vj),
		.rs_addrunit_qk_out     (rs_addrunit_qk),
		.rs_addrunit_vk_out     (rs_addrunit_vk),
		.rs_addrunit_dest_out   (rs_addrunit_dest),
		.rs_addrunit_opcode_out (rs_addrunit_opcode),

		.rs_alu_a_out           (rs_alu_a),
		.rs_alu_vj_out          (rs_alu_vj),
		.rs_alu_vk_out          (rs_alu_vk),
		.rs_alu_dest_out        (rs_alu_dest),
		.rs_alu_pc_out          (rs_alu_pc),
		.rs_alu_opcode_out      (rs_alu_opcode),

		.cdb_alu_b_in           (alu_rob_h),
		.cdb_alu_result_in      (alu_rob_result),
		.cdb_lbuffer_b_in       (lbuffer_rob_h),
		.cdb_lbuffer_result_in  (lbuffer_rob_result)
	);
endmodule