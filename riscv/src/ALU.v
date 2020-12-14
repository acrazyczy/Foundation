`include "constant.vh"

module ALU(
	input clk_in,
	input rst_in,
	input rdy_in,

	//from reservation station
	input wire[`IDWidth - 1 : 0] rs_alu_a_in,
	input wire[`IDWidth - 1 : 0] rs_alu_vj_in,
	input wire[`IDWidth - 1 : 0] rs_alu_vk_in,
	input wire[`ROBWidth - 1 : 0] rs_alu_dest_in,
	input wire[`AddressWidth - 1 : 0] rs_alu_pc_in,
	input wire[`InstTypeWidth - 1 : 0] rs_alu_opcode_in,

	//from & to reorder buffer
	input wire rob_alu_rst_in,
	output reg[`ROBWidth - 1 : 0] alu_rob_h_out,
	output reg[`IDWidth - 1 : 0] alu_rob_result_out,
	output reg[`AddressWidth : 0] alu_rob_addr_out
);

	always @(*) begin
		if (rst_in) alu_rob_h_out = `ROBWidth'b0;
		else if (rdy_in)
			if (rob_alu_rst_in || rs_alu_opcode_in == `NOP) alu_rob_h_out = `ROBWidth'b0;
			else begin
				alu_rob_h_out = rs_alu_dest_in;
				case (rs_alu_opcode_in)
					`BEQ: alu_rob_result_out = rs_alu_vj_in == rs_alu_vk_in;
					`BNE: alu_rob_result_out = rs_alu_vj_in != rs_alu_vk_in;
					`BLT: alu_rob_result_out = $signed(rs_alu_vj_in) < $signed(rs_alu_vk_in);
					`BGE: alu_rob_result_out = $signed(rs_alu_vj_in) >= $signed(rs_alu_vk_in);
					`BLTU: alu_rob_result_out = rs_alu_vj_in < rs_alu_vk_in;
					`BGEU: alu_rob_result_out = rs_alu_vj_in >= rs_alu_vk_in;
					`LUI: alu_rob_result_out = rs_alu_a_in;
					`AUIPC: alu_rob_result_out = rs_alu_pc_in + rs_alu_a_in;
					`JAL: alu_rob_result_out = rs_alu_pc_in + 4;
					`JALR: begin
						alu_rob_result_out = rs_alu_pc_in + 4;
						alu_rob_addr_out = rs_alu_a_in + rs_alu_vj_in;
					end
					`ADDI: alu_rob_result_out = rs_alu_vj_in + rs_alu_a_in;
					`SLTI: alu_rob_result_out = $unsigned($signed(rs_alu_vj_in) < $signed(rs_alu_a_in));
					`SLTIU: alu_rob_result_out = $unsigned(rs_alu_vj_in < rs_alu_a_in);
					`XORI: alu_rob_result_out = rs_alu_vj_in ^ rs_alu_a_in;
					`ORI: alu_rob_result_out = rs_alu_vj_in | rs_alu_a_in;
					`ANDI: alu_rob_result_out = rs_alu_vj_in & rs_alu_a_in;
					`SLLI: alu_rob_result_out = rs_alu_vj_in << rs_alu_a_in;
					`SRLI: alu_rob_result_out = rs_alu_vj_in >> rs_alu_a_in;
					`SRAI: alu_rob_result_out = $signed(rs_alu_vj_in) >> rs_alu_a_in;
					`ADD: alu_rob_result_out = rs_alu_vj_in + rs_alu_vk_in;
					`SUB: alu_rob_result_out = rs_alu_vj_in - rs_alu_vk_in;
					`SLL: alu_rob_result_out = rs_alu_vj_in << rs_alu_vk_in;
					`SLT: alu_rob_result_out = $unsigned($signed(rs_alu_vj_in) < $signed(rs_alu_vk_in));
					`SLTU: alu_rob_result_out = $unsigned(rs_alu_vj_in < rs_alu_vk_in);
					`XOR: alu_rob_result_out = rs_alu_vj_in ^ rs_alu_vk_in;
					`SRL: alu_rob_result_out = rs_alu_vj_in >> rs_alu_vk_in;
					`SRA: alu_rob_result_out = $signed(rs_alu_vj_in) >> rs_alu_vk_in;
					`OR: alu_rob_result_out = rs_alu_vj_in | rs_alu_vk_in;
					`AND: alu_rob_result_out = rs_alu_vj_in & rs_alu_vk_in;
					default: alu_rob_result_out = `IDWidth'b0;
				endcase
			end
	end
endmodule : ALU