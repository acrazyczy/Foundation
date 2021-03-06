`include "constant.vh"

module instqueue(
	input wire clk_in,
	input wire rst_in,
	input wire rdy_in,
	input wire stall_in,

	//from & to instruction fetch
	input wire if_instqueue_en_in,
	input wire[`IDWidth - 1 : 0] if_instqueue_inst_in,
	input wire [`AddressWidth - 1 : 0] if_instqueue_pc_in,
	output wire instqueue_if_rdy_out,

	//from reorder buffer
	input wire rob_instqueue_rst_in,

	//from & to decoder
	input wire decoder_instqueue_rst_in,
	output reg instqueue_decoder_en_out,
	output reg[`IDWidth - 1 : 0] instqueue_decoder_inst_out,
	output reg[`AddressWidth - 1 : 0] instqueue_decoder_pc_out,

	//from branch predictor
	input wire bp_instqueue_rst_in
);
	localparam QueueCount = 8;
	localparam QueueWidth = 3;

	reg[`IDWidth - 1 : 0] inst[QueueCount - 1 : 0];
	reg[`AddressWidth - 1 : 0] pc[QueueCount - 1 : 0];
	reg[QueueWidth - 1 : 0] head, tail;
	integer i;

	always @(posedge clk_in) begin
		if (rst_in) begin
			head <= 3'b000;
			tail <= 3'b000;
			for (i = 0;i < QueueCount;i = i + 1) begin
				inst[i] <= `NOP;
				pc[i] <= `AddressWidth'b0;
			end
			instqueue_decoder_en_out <= 1'b0;
		end if (rdy_in) begin
			if (rob_instqueue_rst_in || decoder_instqueue_rst_in || bp_instqueue_rst_in) begin
				head <= 3'b000;
				tail <= 3'b000;
				for (i = 0;i < QueueCount;i = i + 1) begin
					inst[i] <= `NOP;
					pc[i] <= `AddressWidth'b0;
				end
				instqueue_decoder_en_out <= 1'b0;
			end else begin
				if (if_instqueue_en_in) begin
					inst[tail] <= if_instqueue_inst_in;
					pc[tail] <= if_instqueue_pc_in;
					tail <= (tail + 1) % QueueCount;
				end
				if (!stall_in && head != tail) begin
					instqueue_decoder_en_out <= 1'b1;
					instqueue_decoder_inst_out <= inst[head];
					instqueue_decoder_pc_out <= pc[head];
					head <= (head + 1) % QueueCount;
				end else instqueue_decoder_en_out <= 1'b0;
			end
		end
	end

	assign instqueue_if_rdy_out = (head != (tail + 1) % QueueCount) && (head != (tail + 2) % QueueCount);

endmodule : instqueue