`include "constant.vh"

module decoder(
	input wire clk_in,
	input wire rst_in,
	input wire rdy_in,

	//from & to instruction queue
	input wire instqueue_decoder_en_in,
	input wire[`IDWidth - 1 : 0] instqueue_decoder_inst_in,
	input wire[`AddressWidth - 1 : 0] instqueue_decoder_pc_in,
	output reg decoder_instqueue_rst_out,

	//to instruction fetch
	output wire decoder_if_en_out,
	output reg[`AddressWidth - 1 : 0] decoder_if_addr_out,

	//to branch predictor
	output reg decoder_bp_en_out,
	output reg[`AddressWidth - 1 : 0] decoder_bp_target_out,
	output reg[`AddressWidth - 1 : 0] decoder_bp_pc_out,

	//to dispatcher
	output wire decoder_dispatcher_en_out,
	output reg[`RegWidth - 1 : 0] decoder_dispatcher_rs_out, decoder_dispatcher_rt_out, decoder_dispatcher_rd_out,
	output reg[`IDWidth - 1 : 0] decoder_dispatcher_imm_out,
	output reg[`InstTypeWidth - 1 : 0] decoder_dispatcher_opcode_out,
	output reg[`AddressWidth - 1 : 0] decoder_dispatcher_pc_out
);

	always @(*) begin
		if (rst_in) begin
			decoder_bp_en_out = 1'b0;
			decoder_dispatcher_opcode_out = `NOP;
		end else if (rdy_in && instqueue_decoder_en_in) begin
			decoder_dispatcher_pc_out = instqueue_decoder_pc_in;
			decoder_bp_en_out = 1'b0;
			case (instqueue_decoder_inst_in & `IDWidth'd127)
				51: begin
					decoder_dispatcher_rs_out = instqueue_decoder_inst_in[19 : 15];
					decoder_dispatcher_rt_out = instqueue_decoder_inst_in[24 : 20];
					decoder_dispatcher_rd_out = instqueue_decoder_inst_in[11 : 7];
					case (instqueue_decoder_inst_in[14 : 12])
						3'b000: decoder_dispatcher_opcode_out = instqueue_decoder_inst_in[31 : 25] == 0 ? `ADD : `SUB;
						3'b001: decoder_dispatcher_opcode_out = `SLL;
						3'b010: decoder_dispatcher_opcode_out = `SLT;
						3'b011: decoder_dispatcher_opcode_out = `SLTU;
						3'b100: decoder_dispatcher_opcode_out = `XOR;
						3'b101: decoder_dispatcher_opcode_out = instqueue_decoder_inst_in[31 : 25] == 0 ? `SRL : `SRA;
						3'b110: decoder_dispatcher_opcode_out = `OR;
						3'b111: decoder_dispatcher_opcode_out = `AND;
					endcase
				end
				19: begin
					decoder_dispatcher_rs_out = instqueue_decoder_inst_in[19 : 15];
					decoder_dispatcher_rd_out = instqueue_decoder_inst_in[11 : 7];
					decoder_dispatcher_imm_out = $signed(instqueue_decoder_inst_in[31 : 20]);
					case (instqueue_decoder_inst_in[14 : 12])
						3'b000: decoder_dispatcher_opcode_out = `ADDI;
						3'b001: begin
							decoder_dispatcher_opcode_out = `SLLI;
							decoder_dispatcher_imm_out = $unsigned(instqueue_decoder_inst_in[24 : 20]);
						end
						3'b010: decoder_dispatcher_opcode_out = `SLTI;
						3'b011: decoder_dispatcher_opcode_out = `SLTIU;
						3'b100: decoder_dispatcher_opcode_out = `XORI;
						3'b101: begin
							decoder_dispatcher_opcode_out = instqueue_decoder_inst_in[31 : 25] == 0 ? `SRLI : `SRAI;
							decoder_dispatcher_imm_out = $unsigned(instqueue_decoder_inst_in[24 : 20]);
						end
						3'b110: decoder_dispatcher_opcode_out = `ORI;
						3'b111: decoder_dispatcher_opcode_out = `ANDI;
					endcase
				end
				3: begin
					decoder_dispatcher_rs_out = instqueue_decoder_inst_in[19 : 15];
					decoder_dispatcher_rd_out = instqueue_decoder_inst_in[11 : 7];
					decoder_dispatcher_imm_out = $signed(instqueue_decoder_inst_in[31 : 20]);
					case (instqueue_decoder_inst_in[14 : 12])
						3'b000: decoder_dispatcher_opcode_out = `LB;
						3'b001: decoder_dispatcher_opcode_out = `LH;
						3'b010: decoder_dispatcher_opcode_out = `LW;
						3'b100: decoder_dispatcher_opcode_out = `LBU;
						3'b101: decoder_dispatcher_opcode_out = `LHU;
					endcase
				end
				103: begin
					decoder_dispatcher_rs_out = instqueue_decoder_inst_in[19 : 15];
					decoder_dispatcher_rd_out = instqueue_decoder_inst_in[11 : 7];
					decoder_dispatcher_imm_out = $signed(instqueue_decoder_inst_in[31 : 20]);
					decoder_dispatcher_opcode_out = `JALR;
				end
				35: begin
					decoder_dispatcher_rs_out = instqueue_decoder_inst_in[19 : 15];
					decoder_dispatcher_rt_out = instqueue_decoder_inst_in[24 : 20];
					decoder_dispatcher_imm_out = $signed({instqueue_decoder_inst_in[31 : 25], instqueue_decoder_inst_in[11 : 7]});
					case (instqueue_decoder_inst_in[14 : 12])
						3'b000: decoder_dispatcher_opcode_out = `SB;
						3'b001: decoder_dispatcher_opcode_out = `SH;
						3'b010: decoder_dispatcher_opcode_out = `SW;
					endcase
				end
				99: begin
					decoder_dispatcher_rs_out = instqueue_decoder_inst_in[19 : 15];
					decoder_dispatcher_rt_out = instqueue_decoder_inst_in[24 : 20];
					decoder_dispatcher_imm_out = $signed({instqueue_decoder_inst_in[31], instqueue_decoder_inst_in[7], instqueue_decoder_inst_in[30 : 25], instqueue_decoder_inst_in[11 : 8], 1'b0});
					case (instqueue_decoder_inst_in[14 : 12])
						3'b000: decoder_dispatcher_opcode_out = `BEQ;
						3'b001: decoder_dispatcher_opcode_out = `BNE;
						3'b100: decoder_dispatcher_opcode_out = `BLT;
						3'b101: decoder_dispatcher_opcode_out = `BGE;
						3'b110: decoder_dispatcher_opcode_out = `BLTU;
						3'b111: decoder_dispatcher_opcode_out = `BGEU;
					endcase
					decoder_bp_target_out = instqueue_decoder_pc_in + decoder_dispatcher_imm_out;
					decoder_bp_en_out = 1'b1;
					decoder_bp_pc_out = instqueue_decoder_pc_in;
				end
				111: begin
					decoder_dispatcher_rd_out = instqueue_decoder_inst_in[11 : 7];
					decoder_dispatcher_opcode_out = `JAL;
					decoder_instqueue_rst_out = 1'b1;
					decoder_if_addr_out = $signed({instqueue_decoder_inst_in[31], instqueue_decoder_inst_in[19 : 12], instqueue_decoder_inst_in[20], instqueue_decoder_inst_in[30 : 25], instqueue_decoder_inst_in[24 : 21], 1'b0}) + instqueue_decoder_pc_in;
				end
				23: begin
					decoder_dispatcher_rd_out = instqueue_decoder_inst_in[11 : 7];
					decoder_dispatcher_imm_out = {instqueue_decoder_inst_in[31 : 12], 12'b0};
					decoder_dispatcher_opcode_out = `AUIPC;
				end
				55: begin
					decoder_dispatcher_rd_out = instqueue_decoder_inst_in[11 : 7];
					decoder_dispatcher_imm_out = {instqueue_decoder_inst_in[31 : 12], 12'b0};
					decoder_dispatcher_opcode_out = `LUI;
				end
			endcase
		end
	end

	assign decoder_if_en_out = !rst_in && instqueue_decoder_en_in && ((instqueue_decoder_inst_in & `IDWidth'd127) == 111);
	assign decoder_dispatcher_en_out = instqueue_decoder_en_in;

endmodule : decoder