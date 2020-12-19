`include "constant.vh"

module datactrl(
	input wire clk_in,
	input wire rst_in,
	input wire rdy_in,
	input wire rob_rst_in,

	//from & to reorder buffer
	input wire rob_datactrl_en_in,
	input wire[2 : 0] rob_datactrl_width_in,
	input wire[`AddressWidth - 1 : 0] rob_datactrl_addr_in,
	input wire[`IDWidth - 1 : 0] rob_datactrl_data_in,
	output reg datactrl_rob_en_out,

	//from & to load buffer
	input wire lbuffer_datactrl_en_in,
	input wire[`AddressWidth - 1 : 0] lbuffer_datactrl_addr_in,
	input wire[2 : 0] lbuffer_datactrl_width_in,
	input wire lbuffer_datactrl_sgn_in,
	output reg datactrl_lbuffer_en_out,
	output reg[`IDWidth - 1 : 0] datactrl_lbuffer_data_out,

	//from & to ramctrl
	output reg datactrl_ramctrl_data_en_out,
	output reg datactrl_ramctrl_data_rw_out,
	output reg datactrl_ramctrl_data_sgn_out,
	output reg [2 : 0] datactrl_ramctrl_data_width_out,
	input wire ramctrl_datactrl_data_rdy_in,
	output reg[`AddressWidth - 1 : 0] datactrl_ramctrl_data_addr_out,
	output reg[`IDWidth - 1 : 0] datactrl_ramctrl_data_data_out,
	input wire[`IDWidth - 1 : 0] ramctrl_datactrl_data_data_in
);
	localparam IDLE = 2'b00;
	localparam RDATA = 2'b01;
	localparam WDATA = 2'b10;
	localparam OK = 2'b11;

	reg[1 : 0] state;

	always @(posedge clk_in) begin
		if (rst_in) begin
			state <= IDLE;
			datactrl_ramctrl_data_en_out <= 1'b0;
			datactrl_rob_en_out <= 1'b0;
			datactrl_lbuffer_en_out <= 1'b0;
		end if (rdy_in) if (rob_rst_in) begin
			state <= IDLE;
			datactrl_ramctrl_data_en_out <= 1'b0;
			datactrl_rob_en_out <= 1'b0;
			datactrl_lbuffer_en_out <= 1'b0;
		end else begin
			if (state == IDLE) begin
				if (rob_datactrl_en_in) begin
					datactrl_ramctrl_data_en_out <= 1'b1;
					datactrl_ramctrl_data_rw_out <= 1'b1;
					datactrl_ramctrl_data_width_out <= rob_datactrl_width_in;
					datactrl_ramctrl_data_addr_out <= rob_datactrl_addr_in;
					datactrl_ramctrl_data_data_out <= rob_datactrl_data_in;
					datactrl_rob_en_out <= 1'b0;
					state <= WDATA;
				end else if (lbuffer_datactrl_en_in) begin
					datactrl_ramctrl_data_en_out <= 1'b1;
					datactrl_ramctrl_data_rw_out <= 1'b0;
					datactrl_ramctrl_data_width_out <= lbuffer_datactrl_width_in;
					datactrl_ramctrl_data_addr_out <= lbuffer_datactrl_addr_in;
					datactrl_ramctrl_data_sgn_out <= lbuffer_datactrl_sgn_in;
					datactrl_lbuffer_en_out <= 1'b0;
					state <= RDATA;
				end
			end else if (state != OK && ramctrl_datactrl_data_rdy_in) begin
				if (state == WDATA) datactrl_rob_en_out <= 1'b1;
				else begin
					datactrl_lbuffer_en_out <= 1'b1;
					datactrl_lbuffer_data_out <= ramctrl_datactrl_data_data_in;
				end
				datactrl_ramctrl_data_en_out <= 1'b0;
				state <= OK;
			end else if (state == OK) begin
				datactrl_rob_en_out <= 1'b0;
				datactrl_lbuffer_en_out <= 1'b0;
				state <= IDLE;
			end
		end
	end
endmodule : datactrl