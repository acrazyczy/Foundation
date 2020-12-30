`include "constant.vh"

module lbuffer(
	input wire clk_in,
	input wire rst_in,
	input wire rdy_in,

	//from address unit
	input wire addrunit_lbuffer_en_in,
	input wire[`AddressWidth - 1 : 0] addrunit_lbuffer_a_in,
	input wire[`ROBWidth - 1 : 0] addrunit_lbuffer_dest_in,
	input wire[`InstTypeWidth - 1 : 0] addrunit_lbuffer_opcode_in,

	//from & to reorder buffer
	input wire rob_lbuffer_rst_in,
	output reg[`ROBWidth - 1 : 0] lbuffer_rob_h_out,
	output reg[`IDWidth - 1 : 0] lbuffer_rob_result_out,
	output wire[`ROBWidth - 1 : 0] lbuffer_rob_index_out,
	input wire rob_lbuffer_disambiguation_in, // 1 if no aliasing
	input wire rob_lbuffer_forwarding_en_in,
	input wire [`IDWidth - 1 : 0] rob_lbuffer_forwarding_data_in,

	//to reservation station
	output wire lbuffer_rs_rdy_out,

	//from & to datactrl
	output reg lbuffer_datactrl_en_out,
	output reg[`AddressWidth - 1 : 0] lbuffer_datactrl_addr_out,
	output reg[2 : 0] lbuffer_datactrl_width_out,
	output reg lbuffer_datactrl_sgn_out,
	input wire datactrl_lbuffer_en_in,
	input wire[`IDWidth - 1 : 0] datactrl_lbuffer_data_in
);
//from 1 to LBCount - 1

	reg busy[`LBCount - 1 : 0];
	reg[`AddressWidth - 1 : 0] a[`LBCount - 1 : 0];
	reg[`ROBWidth - 1 : 0] dest[`LBCount - 1 : 0];
	reg[`InstTypeWidth - 1 : 0] opcode[`LBCount - 1 : 0];
	reg[`LBWidth - 1 : 0] head, tail;
	reg[1 : 0] stage;
	integer i;

	localparam IDLE = 2'b00;
	localparam PENDING = 2'b01;
	localparam BUSY = 2'b10;
	localparam OK = 2'b11;

	always @(posedge clk_in) begin
		lbuffer_rob_h_out <= `ROBWidth'b0;
		if (rst_in) begin
			head <= `LBWidth'b1;
			tail <= `LBWidth'b1;
			for (i = 1;i < `LBCount;i = i + 1) busy[i] <= 1'b0;
			stage <= IDLE;
		end else if (rdy_in) if (rob_lbuffer_rst_in) begin
			head <= `LBWidth'b1;
			tail <= `LBWidth'b1;
			for (i = 1;i < `LBCount;i = i + 1) busy[i] <= 1'b0;
			stage <= IDLE;
		end else begin
			if (head != tail)
				if (stage == IDLE) begin
					if (rob_lbuffer_disambiguation_in) stage <= PENDING;
					else if (rob_lbuffer_forwarding_en_in) begin
						lbuffer_rob_h_out <= dest[head];
						case (opcode[head])
							`LB: lbuffer_rob_result_out <= $signed(rob_lbuffer_forwarding_data_in[7 : 0]);
							`LH: lbuffer_rob_result_out <= $signed(rob_lbuffer_forwarding_data_in[15 : 0]);
							`LW: lbuffer_rob_result_out <= rob_lbuffer_forwarding_data_in;
							`LBU: lbuffer_rob_result_out <= rob_lbuffer_forwarding_data_in[7 : 0];
							`LHU: lbuffer_rob_result_out <= rob_lbuffer_forwarding_data_in[15 : 0];
						endcase
						busy[head] <= 1'b0;
						head <= head % (`LBCount - 1) + 1;
						stage <= OK;
					end
				end else if (stage == PENDING) stage <= BUSY;
				else if (stage == BUSY) begin
					if (datactrl_lbuffer_en_in) begin
						lbuffer_rob_h_out <= dest[head];
						lbuffer_rob_result_out <= datactrl_lbuffer_data_in;
						busy[head] <= 1'b0;
						head <= head % (`LBCount - 1) + 1;
						stage <= OK;
					end
				end else begin
					lbuffer_rob_h_out <= `ROBWidth'b0;
					stage <= IDLE;
				end
			if (addrunit_lbuffer_en_in && lbuffer_rs_rdy_out) begin
				busy[tail] <= 1'b1;
				a[tail] <= addrunit_lbuffer_a_in;
				dest[tail] <= addrunit_lbuffer_dest_in;
				opcode[tail] <= addrunit_lbuffer_opcode_in;
				tail <= tail % (`LBCount - 1) + 1;
			end
		end
	end

	always @(*) begin
		if (rst_in) begin
			lbuffer_datactrl_en_out = 1'b0;
		end else if (rdy_in) if (rob_lbuffer_rst_in) begin
			lbuffer_datactrl_en_out = 1'b0;
		end else begin
			if (stage == PENDING) begin
				lbuffer_datactrl_en_out = 1'b1;
				lbuffer_datactrl_addr_out = a[head];
				case (opcode[head])
					`LB: begin
						lbuffer_datactrl_sgn_out = 1'b1;
						lbuffer_datactrl_width_out = 3'b001;
					end
					`LH: begin
						lbuffer_datactrl_sgn_out = 1'b1;
						lbuffer_datactrl_width_out = 3'b010;
					end
					`LW: begin
						lbuffer_datactrl_sgn_out = 1'b0;
						lbuffer_datactrl_width_out = 3'b100;
					end
					`LBU: begin
						lbuffer_datactrl_sgn_out = 1'b0;
						lbuffer_datactrl_width_out = 3'b001;
					end
					`LHU: begin
						lbuffer_datactrl_sgn_out = 1'b0;
						lbuffer_datactrl_width_out = 3'b010;
					end
				endcase
			end else if (stage == BUSY && datactrl_lbuffer_en_in) lbuffer_datactrl_en_out = 1'b0;
		end
	end

	assign lbuffer_rs_rdy_out = (head != tail % (`LBCount - 1) + 1) && (head != (tail + 1) % (`LBCount - 1) + 1);
	assign lbuffer_rob_index_out = dest[head];
endmodule : lbuffer