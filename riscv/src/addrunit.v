`include "constant.vh"

module addrunit(
	input wire clk_in,
	input wire rst_in,
	input wire rdy_in,

	//from reservation station
	input wire[`IDWidth - 1 : 0] rs_addrunit_a_in,
	input wire[`IDWidth - 1 : 0] rs_addrunit_vj_in,
	input wire[`ROBWidth - 1 : 0] rs_addrunit_dest_in,
	input wire[`InstTypeWidth - 1 : 0] rs_addrunit_opcode_in,

	//to lbuffer
	output wire addrunit_lbuffer_en_out,
	output wire[`AddressWidth - 1 : 0] addrunit_lbuffer_a_out,
	output wire[`ROBWidth - 1 : 0] addrunit_lbuffer_dest_out,
	output wire[`InstTypeWidth - 1 : 0] addrunit_lbuffer_opcode_out,

	//from & to reorder buffer
	input wire rob_addrunit_rst_in,
	output wire[`ROBWidth - 1 : 0] addrunit_rob_h_out,
	output wire[`AddressWidth - 1 : 0] addrunit_rob_address_out
);
	assign addrunit_lbuffer_dest_out = rs_addrunit_dest_in;
	assign addrunit_lbuffer_a_out = rs_addrunit_vj_in + rs_addrunit_a_in;
	assign addrunit_lbuffer_opcode_out = rs_addrunit_opcode_in;
	assign addrunit_rob_address_out = rs_addrunit_vj_in + rs_addrunit_a_in;
	assign addrunit_lbuffer_en_out = `LB <= rs_addrunit_opcode_in && rs_addrunit_opcode_in <= `LHU;
	assign addrunit_rob_h_out = rs_addrunit_opcode_in != `NOP ? rs_addrunit_dest_in : `ROBWidth'b0;
endmodule : addrunit