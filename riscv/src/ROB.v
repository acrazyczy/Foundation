`include "constant.vh"

module ROB(
	input wire clk_in,
	input wire rst_in,
	input wire rdy_in,
	output reg rob_rst_out,

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

	//to instruction queue
	output wire rob_instqueue_rdy_out,

	//from & to load buffer
	input wire[`ROBWidth - 1 : 0] lbuffer_rob_h_in,
	input wire[`IDWidth - 1 : 0] lbuffer_rob_result_in,
	input wire lbuffer_rob_en_in,
	input wire[`ROBWidth - 1 : 0] lbuffer_rob_rob_index_in,
	input wire[`LBWidth - 1 : 0] lbuffer_rob_lbuffer_index_in,
	output wire[`LBWidth - 1 : 0] rob_lbuffer_index_out,

	//to regfile
	output reg rob_regfile_en_out,
	output reg[`RegWidth - 1 : 0] rob_regfile_d_out,
	output reg[`IDWidth - 1 : 0] rob_regfile_value_out,
	output reg[`ROBWidth - 1 : 0] rob_regfile_h_out,

	//from & to reservation station
	input wire[`ROBWidth - 1 : 0] rs_rob_h_in,
	input wire[`IDWidth - 1 : 0] rs_rob_result_in,

	//from & to datactrl
	output reg rob_datactrl_en_out,
	output reg[`AddressWidth - 1 : 0] rob_datactrl_addr_out,
	output reg[2 : 0] rob_datactrl_width_out,
	output reg[`IDWidth - 1 : 0] rob_datactrl_data_out,
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
	reg activated[`ROBCount - 1 : 0];
	reg[`LBWidth - 1 : 0] index[`ROBCount - 1 : 0];
	reg[`ROBWidth - 1 : 0] occupation[`ROBCount - 1 : 0];
	reg[`ROBWidth - 1 : 0] head, tail;
	reg[1 : 0] stage;
	reg[`ROBWidth - 1 : 0] deactivated_rob;
	integer i;

	localparam IDLE = 2'b00;
	localparam PENDING = 2'b01;
	localparam BUSY = 2'b10;

//at posedge:
//dispatcher sends an entry to tail
//reorder buffer pop its head (if IDLE && STORE, set stage to PENDING; if BUSY && datactrl_rob_en_in, set to IDLE, pop)
//ALU & addrunit & lbuffer send value to certain entry
//reorder buffer tell lbuffer whether each entry is ready (deactivated_rob)

//during clock cycle
//if stage is PENDING, link datactrl
//if stage is BUSY and datactrl_rob_en_in, clear occupation
//if an entry is activated by lbuffer, calculate its occupation
//deactivate

	always @(posedge clk_in) begin
		rob_rst_out <= 1'b0;
		rob_regfile_en_out <= 1'b0;
		rob_bp_en_out <= 1'b0;
		if (rst_in) begin
			head <= `ROBWidth'b1;
			tail <= `ROBWidth'b1;
			deactivated_rob <= `LBWidth'b0;
			for (i = 0;i < `ROBCount;i = i + 1) begin
				busy[i] <= 1'b0;
				index[i] <= `LBWidth'b0;
			end
			stage <= IDLE;
		end else if (rdy_in) begin
			if (dispatcher_rob_en_in) begin
				busy[tail] <= 1'b1;
				opcode[tail] <= dispatcher_rob_opcode_in;
				dest[tail] <= dispatcher_rob_dest_in;
				pc[tail] <= dispatcher_rob_pc_in;
				bp_taken[tail] <= dispatcher_rob_taken_in;
				target[tail] <= dispatcher_rob_target_in;
				activated[tail] <= 1'b0;
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
			deactivated_rob <= `ROBWidth'b0;
			for (i = 1;i < `ROBCount;i = i + 1)
				if (busy[i] && activated[i] && occupation[i] == `ROBWidth'b0)
					deactivated_rob <= i;
			if (stage == PENDING) stage <= BUSY;
			else if (stage == BUSY) begin
				if (datactrl_rob_en_in) begin
					stage = IDLE;
					busy[head] <= 1'b0;
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
						deactivated_rob <= `LBWidth'b0;
						for (i = 0;i < `ROBCount;i = i + 1) begin
							busy[i] <= 1'b0;
							index[i] <= `LBWidth'b0;
						end
						stage <= IDLE;
					end else begin
						rob_bp_correct_out <= 1'b1;
						busy[head] <= 1'b0;
						head <= head % (`ROBCount - 1) + 1;
					end
				end else if (`SB <= opcode[head] && opcode[head] <= `SW) stage <= PENDING;
				else begin
					rob_regfile_en_out <= 1'b1;
					rob_regfile_d_out <= dest[head];
					rob_regfile_value_out <= value[head];
					rob_regfile_h_out <= head;
					busy[head] <= 1'b0;
					head <= head % (`ROBCount - 1) + 1;
					if (opcode[head] == `JALR) begin
						rob_if_pc_out <= target[head];
						rob_rst_out <= 1'b1;
						head <= `ROBWidth'b1;
						tail <= `ROBWidth'b1;
						deactivated_rob <= `LBWidth'b0;
						for (i = 0;i < `ROBCount;i = i + 1) begin
							busy[i] <= 1'b0;
							index[i] <= `LBWidth'b0;
						end
						stage <= IDLE;
					end
				end
		end
	end

	always @(*) begin
		if (rst_in) begin
			for (i = 1;i < `ROBCount;i = i + 1) activated[i] = 1'b0;
			rob_datactrl_en_out = 1'b0;
		end else if (rdy_in) begin
			if (stage == PENDING) begin
				rob_datactrl_en_out = 1'b1;
				rob_datactrl_addr_out = address[head];
				rob_datactrl_data_out = value[head];
				case (opcode[head])
					`SB: rob_datactrl_width_out = 3'b001;
					`SH: rob_datactrl_width_out = 3'b010;
					`SW: rob_datactrl_width_out = 3'b100;
				endcase
			end else if (stage == BUSY && datactrl_rob_en_in) begin
				rob_datactrl_en_out = 1'b0;
				for (i = 1;i < `ROBCount;i = i + 1)
					if (busy[i] && activated[i] && address[i] == address[head])
						occupation[i] = occupation[i] - 1;
			end
			if (lbuffer_rob_en_in) begin
				activated[lbuffer_rob_rob_index_in] = 1'b1;
				occupation[lbuffer_rob_rob_index_in] = `ROBWidth'b0;
				index[lbuffer_rob_rob_index_in] = lbuffer_rob_lbuffer_index_in;
				occupation[lbuffer_rob_rob_index_in] = `ROBWidth'b0;
				for (i = 1;i < `ROBCount;i = i + 1)
					if ((head <= i && i < lbuffer_rob_rob_index_in) || (i >= head && head > lbuffer_rob_rob_index_in) || (i < lbuffer_rob_rob_index_in && lbuffer_rob_rob_index_in < head))
						if (`SB <= opcode[i] && opcode[i] <= `SW && address[i] == address[lbuffer_rob_rob_index_in])
							occupation[lbuffer_rob_rob_index_in] = occupation[lbuffer_rob_rob_index_in] + 1;
			end
			activated[deactivated_rob] = 1'b0;
		end
	end

	assign rob_instqueue_rdy_out = head != tail % (`ROBCount - 1) + 1;
	assign rob_dispatcher_rs_ready_out = ready[dispatcher_rob_rs_h_in];
	assign rob_dispatcher_rs_value_out = value[dispatcher_rob_rs_h_in];
	assign rob_dispatcher_rt_ready_out = ready[dispatcher_rob_rt_h_in];
	assign rob_dispatcher_rt_value_out = value[dispatcher_rob_rt_h_in];
	assign rob_dispatcher_b_out = tail;
	assign rob_lbuffer_index_out = index[deactivated_rob];

endmodule : ROB