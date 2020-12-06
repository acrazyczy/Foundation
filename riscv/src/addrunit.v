`include "constant.vh"

module addrunit(
	input wire clk_in,
	input wire rst_in,
	input wire rdy_in,

	//from reservation station
	input wire[`IDWidth - 1 : 0] rs_addrunit_a_in,
	input wire[`IDWidth - 1 : 0] rs_addrunit_vj_in,
	input wire[`ROBWidth - 1 : 0] rs_addrunit_dest_in,
	input wire[`IDWidth - 1 : 0] rs_addrunit_opcode_in,

	//to lbuffer
	output wire addrunit_lbuffer_en_out,
	output wire[`AddressWidth - 1 : 0] addrunit_lbuffer_a_out,
	output wire[`ROBWidth - 1 : 0] addrunit_lbuffer_dest_out,
	output wire[`IDWidth - 1 : 0] addrunit_lbuffer_opcode_out,

	//from & to reorder buffer
	input wire rob_addrunit_rst_in,
	output wire[`ROBWidth - 1 : 0] addrunit_rob_h_out,
	output wire[`AddressWidth - 1 : 0] addrunit_rob_address_out
);
	always @(*) begin
		if (rst_in) begin
			addrunit_lbuffer_en_out = 1'b0;
		end else if (rdy_in) if (rs_addrunit_opcode_in == `NOP) addrunit_lbuffer_en_out = 1'b0;
		else begin
			if (`LB <= rs_addrunit_opcode_in && rs_addrunit_opcode_in <= `LHU) begin
				addrunit_lbuffer_en_out = 1'b1;
				addrunit_lbuffer_dest_out = rs_addrunit_dest_in;
				addrunit_lbuffer_a_out = rs_addrunit_vj_in + rs_addrunit_a_in;
				addrunit_lbuffer_opcode_out = rs_addrunit_opcode_in;
			end
			addrunit_rob_h_out = rs_addrunit_dest_in;
			addrunit_rob_address_out = rs_addrunit_vj_in + rs_addrunit_a_in;
		end
	end
endmodule : addrunit