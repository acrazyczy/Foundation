`include "constant.vh"

module dispatcher(
	input wire clk_in,
	input wire rst_in,
	input wire rdy_in,

	//from decoder
	input wire decoder_dispatcher_en_in,
	input wire[`RegWidth - 1 : 0] decoder_dispatcher_rs_in, decoder_dispatcher_rt_in, decoder_dispatcher_rd_in,
	input wire[`IDWidth - 1 : 0] decoder_dispatcher_imm_in,
	input wire[`InstTypeWidth - 1 : 0] decoder_dispatcher_opcode_in,
	input wire[`AddressWidth - 1 : 0] decoder_dispatcher_pc_in,
	input wire[`AddressWidth - 1 : 0] decoder_dispatcher_target_in,

	//from branch predictor
	input wire bp_dispatcher_taken_in,

	//from & to regfile
	output reg[`RegWidth - 1 : 0] dispatcher_regfile_rs_out,
	input wire regfile_dispatcher_rs_busy_in,
	input wire[`IDWidth - 1 : 0] regfile_dispatcher_rs_in,
	input wire[`ROBWidth - 1 : 0] regfile_dispatcher_rs_reorder_in,
	output reg[`RegWidth - 1 : 0] dispatcher_regfile_rt_out,
	input wire regfile_dispatcher_rt_busy_in,
	input wire[`IDWidth - 1 : 0] regfile_dispatcher_rt_in,
	input wire[`ROBWidth - 1 : 0] regfile_dispatcher_rt_reorder_in,
	output wire dispatcher_regfile_rd_en_out,
	output wire[`RegWidth - 1 : 0] dispatcher_regfile_rd_out,
	output wire[`ROBWidth - 1 : 0] dispatcher_regfile_reorder_out,

	//from & to reservation station
	output wire dispatcher_rs_en_out,
	output wire[`IDWidth - 1 : 0] dispatcher_rs_a_out,
	output reg[`ROBWidth - 1 : 0] dispatcher_rs_qj_out,
	output reg[`IDWidth - 1 : 0] dispatcher_rs_vj_out,
	output reg[`ROBWidth - 1 : 0] dispatcher_rs_qk_out,
	output reg[`IDWidth - 1 : 0] dispatcher_rs_vk_out,
	output wire[`ROBWidth - 1 : 0] dispatcher_rs_dest_out,
	output wire[`AddressWidth - 1 : 0] dispatcher_rs_pc_out,
	output wire[`InstTypeWidth - 1 : 0] dispatcher_rs_opcode_out,

	//from & to reorder buffer
	output reg[`ROBWidth - 1 : 0] dispatcher_rob_rs_h_out,
	input wire rob_dispatcher_rs_ready_in,
	input wire[`IDWidth - 1 : 0] rob_dispatcher_rs_value_in,
	output reg[`ROBWidth - 1 : 0] dispatcher_rob_rt_h_out,
	input wire rob_dispatcher_rt_ready_in,
	input wire[`IDWidth - 1 : 0] rob_dispatcher_rt_value_in,
	input wire[`ROBWidth - 1 : 0] rob_dispatcher_b_in,
	output wire dispatcher_rob_en_out,
	output wire[`InstTypeWidth - 1 : 0] dispatcher_rob_opcode_out,
	output wire[`RegWidth - 1 : 0] dispatcher_rob_dest_out,
	output wire[`AddressWidth - 1 : 0] dispatcher_rob_target_out,
	output wire[`AddressWidth - 1 : 0] dispatcher_rob_pc_out,
	output wire dispatcher_rob_taken_out
);

	always @(*) begin
		dispatcher_regfile_rs_out = decoder_dispatcher_rs_in;
		if (regfile_dispatcher_rs_busy_in) begin
			dispatcher_rob_rs_h_out = regfile_dispatcher_rs_reorder_in;
			if (rob_dispatcher_rs_ready_in) begin
				dispatcher_rs_vj_out = rob_dispatcher_rs_value_in;
				dispatcher_rs_qj_out = `ROBWidth'b0;
			end else begin
				dispatcher_rs_vj_out = `IDWidth'b0;
				dispatcher_rs_qj_out = regfile_dispatcher_rs_reorder_in;
			end
		end else begin
			dispatcher_rob_rs_h_out = `ROBWidth'b0;
			dispatcher_rs_vj_out = regfile_dispatcher_rs_in;
			dispatcher_rs_qj_out = `ROBWidth'b0;
		end

		dispatcher_regfile_rt_out = decoder_dispatcher_rt_in;
		if (regfile_dispatcher_rt_busy_in) begin
			dispatcher_rob_rt_h_out = regfile_dispatcher_rt_reorder_in;
			if (rob_dispatcher_rt_ready_in) begin
				dispatcher_rs_vk_out = rob_dispatcher_rt_value_in;
				dispatcher_rs_qk_out = `ROBWidth'b0;
			end else begin
				dispatcher_rs_vk_out = `IDWidth'b0;
				dispatcher_rs_qk_out = regfile_dispatcher_rt_reorder_in;
			end
		end else begin
			dispatcher_rob_rt_h_out = `ROBWidth'b0;
			dispatcher_rs_vk_out = regfile_dispatcher_rt_in;
			dispatcher_rs_qk_out = `ROBWidth'b0;
		end
	end

	assign dispatcher_rob_en_out = decoder_dispatcher_en_in;
	assign dispatcher_rs_en_out = decoder_dispatcher_en_in;
	assign dispatcher_rs_pc_out = decoder_dispatcher_pc_in;
	assign dispatcher_rs_dest_out = rob_dispatcher_b_in;
	assign dispatcher_rob_pc_out = decoder_dispatcher_pc_in;
	assign dispatcher_rob_target_out = decoder_dispatcher_target_in;
	assign dispatcher_rob_taken_out = bp_dispatcher_taken_in;
	assign dispatcher_rs_a_out = decoder_dispatcher_imm_in;
	assign dispatcher_regfile_rd_en_out = decoder_dispatcher_en_in && !(`BEQ <= decoder_dispatcher_opcode_in && decoder_dispatcher_opcode_in <= `BGEU) && !(`SB <= decoder_dispatcher_opcode_in && decoder_dispatcher_opcode_in <= `SW);
	assign dispatcher_regfile_reorder_out = rob_dispatcher_b_in;
	assign dispatcher_regfile_rd_out = decoder_dispatcher_rd_in;
	assign dispatcher_rob_dest_out = decoder_dispatcher_rd_in;
	assign dispatcher_rob_opcode_out = decoder_dispatcher_opcode_in;
	assign dispatcher_rs_opcode_out = decoder_dispatcher_opcode_in;

endmodule : dispatcher