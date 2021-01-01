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
	output wire[`AddressWidth - 1 : 0] bp_if_pc_out,

	//from reorder buffer
	input wire rob_bp_en_in,
	input wire rob_bp_correct_in,
	input wire[`AddressWidth - 1 : 0] rob_bp_pc_in
);
	localparam mask = (1 << 7) - 1;

	reg[1 : 0] prediction[mask : 0];
	integer i;

	always @(posedge clk_in) begin
		if (rst_in) for (i = 0;i <= mask;i = i + 1) prediction[i] <= 2'b01;
		else if (rdy_in && rob_bp_en_in) begin
			if (rob_bp_correct_in)
				prediction[(rob_bp_pc_in >> 2) & mask] <= prediction[(rob_bp_pc_in >> 2) & mask] ^ (^ prediction[(rob_bp_pc_in >> 2) & mask]);
			else
				prediction[(rob_bp_pc_in >> 2) & mask] <= prediction[(rob_bp_pc_in >> 2) & mask] ^ 1 ^ ((^ prediction[(rob_bp_pc_in >> 2) & mask]) << 1);
		end
	end

	assign bp_taken_out = decoder_bp_en_in && (prediction[(decoder_bp_pc_in >> 2) & mask] > 2'b01);
	assign bp_if_pc_out = prediction[(decoder_bp_pc_in >> 2) & mask] > 2'b01 ? decoder_bp_target_in : decoder_bp_pc_in + 4;
endmodule : BP