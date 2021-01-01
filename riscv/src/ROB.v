`include "constant.vh"

module ROB(
	input wire clk_in,
	input wire rst_in,
	input wire rdy_in,
	input wire stall_in,
	output reg rob_rst_out,

	output wire rob_rdy_out,

	//from & to address unit
	input wire[`ROBWidth - 1 : 0] addrunit_rob_h_in,
	input wire[`AddressWidth - 1 : 0] addrunit_rob_address_in,

	//from & to ALU
	input wire[`ROBWidth - 1 : 0] alu_rob_h_in,
	input wire[`IDWidth - 1 : 0] alu_rob_result_in,
	input wire[`AddressWidth - 1 : 0] alu_rob_addr_in,

	//to branch prediction
	output reg rob_bp_en_out,
	output reg rob_bp_correct_out,
	output reg[`AddressWidth - 1 : 0] rob_bp_pc_out,

	//from & to dispatcher
	input wire[`ROBWidth - 1 : 0] dispatcher_rob_rs_h_in,
	output wire rob_dispatcher_rs_ready_out,
	output wire[`IDWidth - 1 : 0] rob_dispatcher_rs_value_out,
	input wire[`ROBWidth - 1 : 0] dispatcher_rob_rt_h_in,
	output wire rob_dispatcher_rt_ready_out,
	output wire[`IDWidth - 1 : 0] rob_dispatcher_rt_value_out,
	output wire[`ROBWidth - 1 : 0] rob_dispatcher_b_out,
	input wire dispatcher_rob_en_in,
	input wire[`InstTypeWidth - 1 : 0] dispatcher_rob_opcode_in,
	input wire[`RegWidth - 1 : 0] dispatcher_rob_dest_in,
	input wire[`AddressWidth - 1 : 0] dispatcher_rob_target_in,
	input wire[`AddressWidth - 1 : 0] dispatcher_rob_pc_in,
	input wire dispatcher_rob_taken_in,

	//to instruction fetch
	output reg[`AddressWidth - 1 : 0] rob_if_pc_out,

	//from & to load buffer
	input wire[`ROBWidth - 1 : 0] lbuffer_rob_h_in,
	input wire[`IDWidth - 1 : 0] lbuffer_rob_result_in,
	input wire[`ROBWidth - 1 : 0] lbuffer_rob_index_in,
	output reg rob_lbuffer_disambiguation_out, // 1 if no aliasing
	output reg rob_lbuffer_forwarding_en_out,
	output reg[`IDWidth - 1 : 0] rob_lbuffer_forwarding_data_out,

	//to regfile
	output reg rob_regfile_en_out,
	output reg[`RegWidth - 1 : 0] rob_regfile_d_out,
	output reg[`IDWidth - 1 : 0] rob_regfile_value_out,
	output reg[`ROBWidth - 1 : 0] rob_regfile_h_out,

	//from & to reservation station
	input wire[`ROBWidth - 1 : 0] rs_rob_h_in,
	input wire[`IDWidth - 1 : 0] rs_rob_result_in,

	//from & to datactrl
	output wire rob_datactrl_en_out,
	output wire[`AddressWidth - 1 : 0] rob_datactrl_addr_out,
	output reg[2 : 0] rob_datactrl_width_out,
	output wire[`IDWidth - 1 : 0] rob_datactrl_data_out,
	input wire datactrl_rob_en_in
);
//from 1 to ROBCount - 1

	reg busy[`ROBCount - 1 : 0];
	reg[`InstTypeWidth - 1 : 0] opcode[`ROBCount - 1 : 0];
	reg[`RegWidth - 1 : 0] dest[`ROBCount - 1 : 0];
	reg[`AddressWidth - 1 : 0] pc[`ROBCount - 1 : 0];
	reg[`IDWidth - 1 : 0] value[`ROBCount - 1 : 0];
	reg[`AddressWidth - 1 : 0] address[`ROBCount - 1 : 0];
	reg[`AddressWidth - 1 : 0] target[`ROBCount - 1 : 0];
	reg bp_taken[`ROBCount - 1 : 0];
	reg ready[`ROBCount - 1 : 0];
	reg[`ROBWidth - 1 : 0] head, tail;
	reg[1 : 0] stage;
	integer i;

	localparam IDLE = 2'b00;
	localparam PENDING = 2'b01;
	localparam BUSY = 2'b10;

	always @(posedge clk_in) begin
		rob_rst_out <= 1'b0;
		rob_regfile_en_out <= 1'b0;
		rob_bp_en_out <= 1'b0;
		if (rst_in) begin
			head <= `ROBWidth'b1;
			tail <= `ROBWidth'b1;
			for (i = 0;i < `ROBCount;i = i + 1) begin
				busy[i] <= 1'b0;
				pc[i] <= `AddressWidth'b0;
			end
			stage <= IDLE;
		end else if (rdy_in) begin
			if (dispatcher_rob_en_in && !rob_rst_out) begin
				busy[tail] <= 1'b1;
				opcode[tail] <= dispatcher_rob_opcode_in;
				dest[tail] <= dispatcher_rob_dest_in;
				pc[tail] <= dispatcher_rob_pc_in;
				bp_taken[tail] <= dispatcher_rob_taken_in;
				target[tail] <= dispatcher_rob_target_in;
				ready[tail] <= 1'b0;
				tail <= tail % (`ROBCount - 1) + 1;
			end
			if (alu_rob_h_in != `ROBWidth'b0) begin
				value[alu_rob_h_in] <= alu_rob_result_in;
				ready[alu_rob_h_in] <= 1'b1;
				if (opcode[alu_rob_h_in] == `JALR) target[alu_rob_h_in] <= alu_rob_addr_in;
			end
			if (addrunit_rob_h_in != `ROBWidth'b0) address[addrunit_rob_h_in] <= addrunit_rob_address_in;
			if (lbuffer_rob_h_in != `ROBWidth'b0) begin
				value[lbuffer_rob_h_in] <= lbuffer_rob_result_in;
				ready[lbuffer_rob_h_in] <= 1'b1;
			end
			if (rs_rob_h_in != `ROBWidth'b0) begin
				value[rs_rob_h_in] <= rs_rob_result_in;
				ready[rs_rob_h_in] <= 1'b1;
			end
			if (stage == PENDING) stage <= BUSY;
			else if (stage == BUSY) begin
				if (datactrl_rob_en_in) begin
					stage <= IDLE;
					busy[head] <= 1'b0;
					pc[head] <= `AddressWidth'b0;
					head = head % (`ROBCount - 1) + 1;
				end
			end else if (head != tail && ready[head] == 1'b1)
				if (`BEQ <= opcode[head] && opcode[head] <= `BGEU) begin
					rob_bp_en_out <= 1'b1;
					rob_bp_pc_out <= pc[head];
					if (bp_taken[head] != value[head]) begin
						if (value[head]) rob_if_pc_out <= target[head];
						else rob_if_pc_out <= pc[head] + 4;
						rob_rst_out <= 1'b1;
						head <= `ROBWidth'b1;
						tail <= `ROBWidth'b1;
						for (i = 0;i < `ROBCount;i = i + 1) begin
							busy[i] <= 1'b0;
							pc[i] <= `AddressWidth'b0;
						end
						stage <= IDLE;
					end else begin
						rob_bp_correct_out <= 1'b1;
						busy[head] <= 1'b0;
						pc[head] <= `AddressWidth'b0;
						head <= head % (`ROBCount - 1) + 1;
					end
				end else if (`SB <= opcode[head] && opcode[head] <= `SW) stage <= PENDING;
				else begin
					rob_regfile_en_out <= 1'b1;
					rob_regfile_d_out <= dest[head];
					rob_regfile_value_out <= value[head];
					rob_regfile_h_out <= head;
					busy[head] <= 1'b0;
					pc[head] <= `AddressWidth'b0;
					head <= head % (`ROBCount - 1) + 1;
					if (opcode[head] == `JALR) begin
						rob_if_pc_out <= target[head];
						rob_rst_out <= 1'b1;
						head <= `ROBWidth'b1;
						tail <= `ROBWidth'b1;
						for (i = 0;i < `ROBCount;i = i + 1) begin
							busy[i] <= 1'b0;
							pc[i] <= `AddressWidth'b0;
						end
						stage <= IDLE;
					end
				end
		end
	end

	always @(*) begin
		case (opcode[head])
			`SB: rob_datactrl_width_out = 3'b001;
			`SH: rob_datactrl_width_out = 3'b010;
			`SW: rob_datactrl_width_out = 3'b100;
			default: rob_datactrl_width_out = 3'b000;
		endcase
		rob_lbuffer_disambiguation_out = 1'b1;
		rob_lbuffer_forwarding_en_out = 1'b0;
		rob_lbuffer_forwarding_data_out = `IDWidth'b0;
		for (i = 1;i < `ROBCount;i = i + 1)
			if (busy[i] && head <= i && (i < lbuffer_rob_index_in || lbuffer_rob_index_in < head) && `SB <= opcode[i] && opcode[i] <= `SW)
				if (address[i] == address[lbuffer_rob_index_in]) begin
					rob_lbuffer_disambiguation_out = 1'b0;
					if (ready[i]) begin
						rob_lbuffer_forwarding_en_out = 1'b1;
						rob_lbuffer_forwarding_data_out = value[i];
					end else rob_lbuffer_forwarding_en_out = 1'b0;
				end
		for (i = 1;i < `ROBCount;i = i + 1)
			if (busy[i] && i < lbuffer_rob_index_in && lbuffer_rob_index_in < head && `SB <= opcode[i] && opcode[i] <= `SW)
				if (address[i] == address[lbuffer_rob_index_in]) begin
					rob_lbuffer_disambiguation_out = 1'b0;
					if (ready[i]) begin
						rob_lbuffer_forwarding_en_out = 1'b1;
						rob_lbuffer_forwarding_data_out = value[i];
					end else rob_lbuffer_forwarding_en_out = 1'b0;
				end
		if (address[lbuffer_rob_index_in] == 18'h30004)
			if (lbuffer_rob_index_in == head) rob_lbuffer_disambiguation_out = 1'b1;
			else begin
				rob_lbuffer_disambiguation_out = 1'b0;
				rob_lbuffer_forwarding_en_out = 1'b0;
			end
	end

	assign rob_datactrl_addr_out = address[head];
	assign rob_datactrl_data_out = value[head];
	assign rob_datactrl_en_out = stage == PENDING || stage == BUSY && !datactrl_rob_en_in;
	assign rob_rdy_out = (head != tail % (`ROBCount - 1) + 1) && (head != (tail + 1) % (`ROBCount - 1) + 1);
	assign rob_dispatcher_rs_ready_out = ready[dispatcher_rob_rs_h_in] || alu_rob_h_in == dispatcher_rob_rs_h_in || lbuffer_rob_h_in == dispatcher_rob_rs_h_in;
	assign rob_dispatcher_rs_value_out = alu_rob_h_in == dispatcher_rob_rs_h_in ? alu_rob_result_in : (lbuffer_rob_h_in == dispatcher_rob_rs_h_in ? lbuffer_rob_result_in : value[dispatcher_rob_rs_h_in]);
	assign rob_dispatcher_rt_ready_out = ready[dispatcher_rob_rt_h_in] || alu_rob_h_in == dispatcher_rob_rt_h_in || lbuffer_rob_h_in == dispatcher_rob_rt_h_in;
	assign rob_dispatcher_rt_value_out = alu_rob_h_in == dispatcher_rob_rt_h_in ? alu_rob_result_in : (lbuffer_rob_h_in == dispatcher_rob_rt_h_in ? lbuffer_rob_result_in : value[dispatcher_rob_rt_h_in]);
	assign rob_dispatcher_b_out = tail;

endmodule : ROB