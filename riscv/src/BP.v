`include "constant.vh"

module BP(
	input wire clk_in,
	input wire rst_in,
	input wire rdy_in,
	output wire bp_taken_out,

	//from decoder
	input wire decoder_bp_en_in,
	input wire[`AddressWidth - 1 : 0] decoder_bp_pc_in,
	input wire[`AddressWidth - 1 : 0] decoder_bp_target_in,

	//to instruction fetch
	output reg[`AddressWidth - 1 : 0] bp_if_pc_out,

	//from reorder buffer
	input wire rob_bp_en_in,
	input wire rob_bp_correct_in,
	input wire[`AddressWidth - 1 : 0] rob_bp_pc_in
);
	localparam mask = (1 << 7) - 1;

	reg[1 : 0] prediction[mask : 0];
	integer i;

	always @(*) begin
		if (rst_in) begin
			for (i = 0;i <= mask;i = i + 1) prediction[i] = 2'b01;
		end else if (rdy_in) begin
			if (decoder_bp_en_in)
				if (prediction[(decoder_bp_pc_in >> 2) & mask] > 2'b01) bp_if_pc_out = decoder_bp_target_in;
				else bp_if_pc_out = decoder_bp_pc_in + 4;
			if (rob_bp_en_in)
				if (rob_bp_correct_in)
					prediction[(rob_bp_pc_in >> 2) & mask] = prediction[(rob_bp_pc_in >> 2) & mask] ^ (^ prediction[(rob_bp_pc_in >> 2) & mask]);
				else
					prediction[(rob_bp_pc_in >> 2) & mask] = prediction[(rob_bp_pc_in >> 2) & mask] ^ 1 ^ ((^ prediction[(rob_bp_pc_in >> 2) & mask]) << 1);
		end
	end

	assign bp_taken_out = !rst_in && decoder_bp_en_in && (prediction[(decoder_bp_pc_in >> 2) & mask] > 2'b01);
endmodule : BP