`include "constant.vh"

module RS(
	input wire clk_in,
	input wire rst_in,
	input wire rdy_in,
	input wire stall_in,

	output wire rs_rdy_out,

	//from dispatcher
	input wire dispatcher_rs_en_in,
	input wire[`IDWidth - 1 : 0] dispatcher_rs_a_in,
	input wire[`ROBWidth - 1 : 0] dispatcher_rs_qj_in,
	input wire[`IDWidth - 1 : 0] dispatcher_rs_vj_in,
	input wire[`ROBWidth - 1 : 0] dispatcher_rs_qk_in,
	input wire[`IDWidth - 1 : 0] dispatcher_rs_vk_in,
	input wire[`ROBWidth - 1 : 0] dispatcher_rs_dest_in,
	input wire[`AddressWidth - 1 : 0] dispatcher_rs_pc_in,
	input wire[`InstTypeWidth - 1 : 0] dispatcher_rs_opcode_in,

	//from load buffer
	input wire lbuffer_rs_rdy_in,

	//from & to reorder buffer
	output reg[`ROBWidth - 1 : 0] rs_rob_h_out,
	output reg[`IDWidth - 1 : 0] rs_rob_result_out,
	input wire rob_rs_rst_in,

	//to addresss unit
	output reg[`IDWidth - 1 : 0] rs_addrunit_a_out,
	output reg[`IDWidth - 1 : 0] rs_addrunit_vj_out,
	output reg[`ROBWidth - 1 : 0] rs_addrunit_qk_out,
	output reg[`IDWidth - 1 : 0] rs_addrunit_vk_out,
	output reg[`ROBWidth - 1 : 0] rs_addrunit_dest_out,
	output reg[`InstTypeWidth - 1 : 0] rs_addrunit_opcode_out,

	//to ALU
	output reg[`IDWidth - 1 : 0] rs_alu_a_out,
	output reg[`IDWidth - 1 : 0] rs_alu_vj_out,
	output reg[`IDWidth - 1 : 0] rs_alu_vk_out,
	output reg[`ROBWidth - 1 : 0] rs_alu_dest_out,
	output reg[`AddressWidth - 1 : 0] rs_alu_pc_out,
	output reg[`InstTypeWidth - 1 : 0] rs_alu_opcode_out,

	//from common data bus
	input wire[`ROBWidth - 1 : 0] cdb_alu_b_in,
	input wire[`IDWidth - 1 : 0] cdb_alu_result_in,
	input wire[`ROBWidth - 1 : 0] cdb_lbuffer_b_in,
	input wire[`IDWidth - 1 : 0] cdb_lbuffer_result_in
);
//from 1 to RSCount - 1

	reg busy[`RSCount - 1 : 0];
	reg[`IDWidth - 1 : 0] a[`RSCount - 1 : 0];
	reg[`ROBWidth - 1 : 0] qj[`RSCount - 1 : 0];
	reg[`IDWidth - 1 : 0] vj[`RSCount - 1 : 0];
	reg[`ROBWidth - 1 : 0] qk[`RSCount - 1 : 0];
	reg[`IDWidth - 1 : 0] vk[`RSCount - 1 : 0];
	reg[`ROBWidth - 1 : 0] dest[`RSCount - 1 : 0];
	reg[`AddressWidth - 1 : 0] pc[`RSCount - 1 : 0];
	reg[`InstTypeWidth - 1 : 0] opcode[`RSCount - 1 : 0];
	reg[`RSWidth - 1 : 0] ready_to_addrunit;
	reg[`RSWidth - 1 : 0] ready_to_alu;
	reg[`RSWidth - 1 : 0] ready_to_rob;
	reg in_LS_queue[`RSCount - 1 : 0];
	reg[`RSWidth - 1 : 0] LS_queue[`RSCount - 1 : 0];
	reg[`RSWidth - 1 : 0] head, tail;
	reg[`RSWidth - 1 : 0] idle_first, idle_second;
	integer i;

//at posedge
//dispatcher sends an entry into RS
//notify broadcast on CDB
//send a LS instruction to addrunit (if LOAD, send only when lbuffer is ready)
//send an ALU instruction to ALU
//send an store instruction which has already been sent to addrunit to ROB

//during clock cycle
//if a new entry is sent, change idlelist_head
//if a load instruction is sent, change idlelist_head
//if a store instruction is sent to addrunit, change LS_queue
//if a store instruction is sent to rob, change idlelist_head
//if it's a load instruction and the LS_queue is not empty, push it
//if it's a store instruction, push it

	always @(posedge clk_in) begin
		ready_to_addrunit <= `RSWidth'b0;
		ready_to_alu <= `RSWidth'b0;
		ready_to_rob <= `RSWidth'b0;
		rs_rob_h_out <= `ROBWidth'b0;
		rs_alu_opcode_out <= `NOP;
		rs_addrunit_opcode_out <= `NOP;
		if (rst_in) begin
			idle_first <= `RSWidth'b1;
			idle_second <= `RSWidth'b10;
			head <= `RSWidth'b0;
			tail <= `RSWidth'b0;
			for (i = 0;i < `RSCount;i = i + 1) begin
				busy[i] <= 1'b0;
				pc[i] <= `AddressWidth'b0;
				in_LS_queue[i] <= 1'b0;
			end
		end else if (rdy_in) if (rob_rs_rst_in) begin
			idle_first <= `RSWidth'b1;
			idle_second <= `RSWidth'b10;
			head <= `RSWidth'b0;
			tail <= `RSWidth'b0;
			for (i = 0;i < `RSCount;i = i + 1) begin
				busy[i] <= 1'b0;
				pc[i] <= `AddressWidth'b0;
				in_LS_queue[i] <= 1'b0;
			end
		end else begin
			idle_first <= idle_second;
			idle_second <= `RSWidth'b0;
			if (ready_to_alu != `RSWidth'b0) begin
				busy[ready_to_alu] <= 1'b0;
				pc[ready_to_alu] <= `AddressWidth'b0;
			end
			if (ready_to_addrunit != `RSWidth'b0)
				if (opcode[ready_to_addrunit] < `SB || opcode[ready_to_addrunit] > `SW) begin
					busy[ready_to_addrunit] <= 1'b0;
					pc[ready_to_addrunit] <= `AddressWidth'b0;
				end else begin
					in_LS_queue[LS_queue[head]] <= 1'b0;
					head <= (head + 1) % `RSCount;
				end
			else if (head != tail && `LB <= opcode[LS_queue[head]] && opcode[LS_queue[head]] <= `LHU) begin
				in_LS_queue[LS_queue[head]] <= 1'b0;
				head <= (head + 1) % `RSCount;
			end
			if (ready_to_rob != `RSWidth'b0) begin
				busy[ready_to_rob] <= 1'b0;
				pc[ready_to_rob] <= `AddressWidth'b0;
			end
			if (dispatcher_rs_en_in) begin
				busy[idle_first] <= 1'b1;
				a[idle_first] <= dispatcher_rs_a_in;
				qj[idle_first] <= dispatcher_rs_qj_in;
				vj[idle_first] <= dispatcher_rs_vj_in;
				qk[idle_first] <= dispatcher_rs_qk_in;
				vk[idle_first] <= dispatcher_rs_vk_in;
				dest[idle_first] <= dispatcher_rs_dest_in;
				pc[idle_first] <= dispatcher_rs_pc_in;
				opcode[idle_first] <= dispatcher_rs_opcode_in;
				if (`SB <= dispatcher_rs_opcode_in && dispatcher_rs_opcode_in <= `SW) begin
					LS_queue[tail] <= idle_first;
					in_LS_queue[idle_first] <= 1'b1;
					tail <= (tail + 1) % `RSCount;
				end else if (`LB <= dispatcher_rs_opcode_in && dispatcher_rs_opcode_in <= `LHU && head != tail) begin
					LS_queue[tail] <= idle_first;
					in_LS_queue[idle_first] <= 1'b1;
					tail <= (tail + 1) % `RSCount;
				end
			end
			for (i = 1;i < `RSCount;i = i + 1)
				if (busy[i]) begin
					if (cdb_alu_b_in != `ROBWidth'b0) begin
						if (qj[i] == cdb_alu_b_in) begin
							vj[i] <= cdb_alu_result_in;
							qj[i] <= `ROBWidth'b0;
						end
						if (qk[i] == cdb_alu_b_in) begin
							vk[i] <= cdb_alu_result_in;
							qk[i] <= `ROBWidth'b0;
						end
					end
					if (cdb_lbuffer_b_in != `ROBWidth'b0) begin
						if (qj[i] == cdb_lbuffer_b_in) begin
							vj[i] <= cdb_lbuffer_result_in;
							qj[i] <= `ROBWidth'b0;
						end
						if (qk[i] == cdb_lbuffer_b_in) begin
							vk[i] <= cdb_lbuffer_result_in;
							qk[i] <= `ROBWidth'b0;
						end
					end
					if (`LB <= opcode[i] && opcode[i] <= `LHU) begin
						if (i != ready_to_addrunit && lbuffer_rs_rdy_in && qj[i] == `ROBWidth'b0 && !in_LS_queue[i]) begin
							ready_to_addrunit <= i;
							rs_addrunit_a_out <= a[i];
							rs_addrunit_vj_out <= vj[i];
							rs_addrunit_dest_out <= dest[i];
							rs_addrunit_opcode_out <= opcode[i];
						end
					end else if (`SB <= opcode[i] && opcode[i] <= `SW) begin
						if (i != ready_to_rob && qk[i] == `ROBWidth'b0 && !in_LS_queue[i]) begin
							ready_to_rob <= i;
							rs_rob_h_out <= dest[i];
							case (opcode[i])
								`SB: rs_rob_result_out <= vk[i][7 : 0];
								`SH: rs_rob_result_out <= vk[i][15 : 0];
								`SW: rs_rob_result_out <= vk[i];
							endcase
						end else if (i != ready_to_addrunit && qj[i] == `ROBWidth'b0 && LS_queue[head] == i && head != tail) begin
							ready_to_addrunit <= i;
							rs_addrunit_a_out <= a[i];
							rs_addrunit_vj_out <= vj[i];
							rs_addrunit_dest_out <= dest[i];
							rs_addrunit_opcode_out <= opcode[i];
						end
					end else if (`BEQ <= opcode[i] && opcode[i] <= `BGEU || `ADD <= opcode[i] && opcode[i] <= `AND) begin
						if (i != ready_to_alu && qj[i] == `ROBWidth'b0 && qk[i] == `ROBWidth'b0) begin
							ready_to_alu <= i;
							rs_alu_a_out <= a[i];
							rs_alu_vj_out <= vj[i];
							rs_alu_vk_out <= vk[i];
							rs_alu_dest_out <= dest[i];
							rs_alu_pc_out <= pc[i];
							rs_alu_opcode_out <= opcode[i];
						end
					end else if (opcode[i] == `JALR || `ADDI <= opcode[i] && opcode[i] <= `SRAI) begin
						if (i != ready_to_alu && qj[i] == `ROBWidth'b0) begin
							ready_to_alu <= i;
							rs_alu_a_out <= a[i];
							rs_alu_vj_out <= vj[i];
							rs_alu_dest_out <= dest[i];
							rs_alu_pc_out <= pc[i];
							rs_alu_opcode_out <= opcode[i];
						end
					end else if (i != ready_to_alu && `LUI <= opcode[i] && opcode[i] <= `JAL) begin
						ready_to_alu <= i;
						rs_alu_a_out <= a[i];
						rs_alu_vj_out <= vj[i];
						rs_alu_dest_out <= dest[i];
						rs_alu_pc_out <= pc[i];
						rs_alu_opcode_out <= opcode[i];
					end
				end else if (i != idle_first && i != idle_second) idle_second <= i;
		end
	end

	assign rs_rdy_out = idle_first != `RSWidth'b0 && idle_second != `RSWidth'b0;
endmodule : RS