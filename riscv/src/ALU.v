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
	output wire[`ROBWidth - 1 : 0] alu_rob_h_out,
	output reg[`IDWidth - 1 : 0] alu_rob_result_out,
	output reg[`AddressWidth - 1 : 0] alu_rob_addr_out
);

	always @(*) begin
		alu_rob_result_out = `IDWidth'b0;
		alu_rob_addr_out = `AddressWidth'b0;
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
		endcase
	end

	assign alu_rob_h_out = !rst_in && !rob_alu_rst_in && rs_alu_opcode_in != `NOP ? rs_alu_dest_in : `ROBWidth'b0;
endmodule : ALU