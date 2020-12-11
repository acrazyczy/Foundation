`include "constant.vh"

module regfile(
	input wire clk_in,
	input wire rst_in,
	input wire rdy_in,

	//from & to dispatcher
	input wire[`RegWidth - 1 : 0] dispatcher_regfile_rs_in,
	output wire regfile_dispatcher_rs_busy_out,
	output wire[`IDWidth - 1 : 0] regfile_dispatcher_rs_out,
	output wire[`ROBWidth - 1 : 0] regfile_dispatcher_rs_reorder_out,
	input wire[`RegWidth - 1 : 0] dispatcher_regfile_rt_in,
	output wire regfile_dispatcher_rt_busy_out,
	output wire[`IDWidth - 1 : 0] regfile_dispatcher_rt_out,
	output wire[`ROBWidth - 1 : 0] regfile_dispatcher_rt_reorder_out,
	input wire dispatcher_regfile_rd_en_in,
	input wire[`RegWidth - 1 : 0] dispatcher_regfile_rd_in,
	input wire[`ROBWidth - 1 : 0] dispatcher_regfile_reorder_in,

	//from reorder buffer
	input wire rob_regfile_en_in,
	input wire[`RegWidth - 1 : 0] rob_regfile_d_in,
	input wire[`IDWidth - 1 : 0] rob_regfile_value_in,
	input wire[`ROBWidth - 1 : 0] rob_regfile_h_in,
	input wire rob_regfile_rst_in
);
	reg[`IDWidth - 1 : 0] register[`RegCount - 1 : 0];
	reg busy[`RegCount - 1 : 0];
	reg[`ROBWidth - 1 : 0] reorder[`RegCount - 1 : 0];
	integer i;

	always @(posedge clk_in) begin
		if (rst_in) begin
			for (i = 0;i < `RegCount;i = i + 1) begin
				register[i] <= `IDWidth'b0;
				busy[i] <= 1'b0;
				reorder[i] <= `ROBWidth'b0;
			end
		end else if (rdy_in) if (rob_regfile_rst_in) begin
			for (i = 0;i < `RegCount;i = i + 1) begin
				busy[i] <= 1'b0;
				reorder[i] <= `ROBWidth'b0;
			end
		end else begin
			if (rob_regfile_en_in && rob_regfile_d_in != `RegWidth'b0) begin
				register[rob_regfile_d_in] <= rob_regfile_value_in;
				if (reorder[rob_regfile_d_in] == rob_regfile_h_in) begin
					busy[rob_regfile_d_in] <= 1'b0;
					reorder[rob_regfile_d_in] <= `ROBWidth'b0;
				end
			end
			if (dispatcher_regfile_rd_en_in && dispatcher_regfile_rd_in != `RegWidth'b0) begin
				busy[dispatcher_regfile_rd_in] <= 1'b1;
				reorder[dispatcher_regfile_rd_in] <= dispatcher_regfile_reorder_in;
			end
		end
	end

	assign regfile_dispatcher_rs_busy_out = dispatcher_regfile_rs_in == `RegWidth'b0 ? 0 : busy[dispatcher_regfile_rs_in];
	assign regfile_dispatcher_rs_out = dispatcher_regfile_rs_in == `RegWidth'b0 ? `IDWidth'b0 : register[dispatcher_regfile_rs_in];
	assign regfile_dispatcher_rs_reorder_out = dispatcher_regfile_rs_in == `RegWidth'b0 ? `ROBWidth'b0 : reorder[dispatcher_regfile_rs_in];
	assign regfile_dispatcher_rt_busy_out = dispatcher_regfile_rt_in == `RegWidth'b0 ? 0 : busy[dispatcher_regfile_rt_in];
	assign regfile_dispatcher_rt_out = dispatcher_regfile_rt_in == `RegWidth'b0 ? `IDWidth'b0 : register[dispatcher_regfile_rt_in];
	assign regfile_dispatcher_rt_reorder_out = dispatcher_regfile_rt_in == `RegWidth'b0 ? `ROBWidth'b0 : reorder[dispatcher_regfile_rt_in];

endmodule : regfile