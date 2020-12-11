`include "constant.vh"

module IF(
	input wire clk_in,
	input wire rst_in,
	input wire rdy_in,

	//from & to icache
	input wire icache_if_miss_in,
	input wire[`IDWidth - 1 : 0] icache_if_inst_inst_in,
	output reg[`AddressWidth - 1 : 0] if_icache_inst_addr_out,

	//from & to instruction queue
	output reg if_instqueue_en_out,
	output reg[`IDWidth - 1 : 0] if_instqueue_inst_out,
	output reg[`AddressWidth - 1 : 0] if_instqueue_pc_out,
	input wire instqueue_if_rdy_in,

	//from branch predictor
	input wire bp_if_en_in,
	input wire[`AddressWidth - 1 : 0] bp_if_pc_in,

	//from decoder
	input wire decoder_if_en_in,
	input wire[`AddressWidth - 1 : 0] decoder_if_addr_in,

	//from reorder buffer
	input wire rob_if_en_in,
	input wire[`AddressWidth - 1 : 0] rob_if_pc_in
);

	reg[`AddressWidth - 1 : 0] pc, pc_temp;
	reg state;

	localparam IDLE = 1'b0;
	localparam PENDING = 1'b1;

	always @(posedge clk_in) begin
		if (rst_in) begin
			pc <= `AddressWidth'b0;
			if_instqueue_en_out <= 1'b0;
			if_icache_inst_addr_out <= `AddressWidth'b0;
			state <=  IDLE;
		end else if (rdy_in) begin
			if (rob_if_en_in) begin
				pc <= rob_if_pc_in;
				if_instqueue_en_out <= 1'b0;
				if_icache_inst_addr_out <= rob_if_pc_in;
				state <= IDLE;
			end else if (decoder_if_en_in) begin
				if (state == IDLE) begin
					pc <= decoder_if_addr_in;
					if_instqueue_en_out <= 1'b0;
					if_icache_inst_addr_out <= decoder_if_addr_in;
				end else pc_temp <= decoder_if_addr_in;
			end else if (bp_if_en_in) begin
				if (state == IDLE) begin
					pc <= bp_if_pc_in;
					if_instqueue_en_out <= 1'b0;
					if_icache_inst_addr_out <= bp_if_pc_in;
				end else pc_temp <= bp_if_pc_in;
			end else if (!icache_if_miss_in) begin
				if (instqueue_if_rdy_in) begin
					if_instqueue_en_out <= 1'b1;
					if_instqueue_inst_out <= icache_if_inst_inst_in;
					if_instqueue_pc_out <= pc;
					pc <= state == IDLE ? pc + 4 : pc_temp;
					if_icache_inst_addr_out <= state == IDLE ? pc + 4 : pc_temp;
					state <= IDLE;
				end else begin
					if_instqueue_en_out <= 1'b0;
					state <= PENDING;
					pc_temp <= pc + 4;
				end
			end else if_instqueue_en_out <= 1'b0;
		end
	end

endmodule : IF