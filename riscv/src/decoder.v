`include "constant.vh"

module decoder
(
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    //from instqueue
    input wire[`IDWidth - 1 : 0] instqueue_decoder_inst_in,
    input wire[`AddressWidth - 1 : 0] instqueue_decoder_pc_in,

    //to instruction fetch
    output reg decoder_if_en_out,
    output reg[`AddressWidth - 1 : 0] decoder_if_addr_out,

    //to branch predictor
    output reg decoder_bp_en_out,
    output reg[`AddressWidth - 1 : 0] decoder_bp_pc_out,

    //to reservation station
    output reg[`RegWidth - 1 : 0] decoder_RS_rs_out, decoder_RS_rt_out, decoder_RS_rd_out,
    output reg[`IDWidth - 1 : 0] decoder_RS_imm_out,
    output reg[`InstTypeWidth - 1 : 0] decoder_RS_opcode_out,
    output reg[`AddressWidth - 1 : 0] decoder_RS_pc_out
);

    always @(posedge clk_in) begin
        if (rst_in) begin
            decoder_if_en_out <= 1'b0;
            decoder_bp_en_out <= 1'b0;
            decoder_RS_opcode_out <= NOP;
        end else if (rdy_in) begin
            decoder_RS_pc_out <= instqueue_decoder_pc_in;
            decoder_bp_en_out <= 1'b0;
            decoder_if_en_out <= 1'b0;
            case (instqueue_decoder_inst_in & `IDWidth'h127)
                51: begin
                    decoder_RS_rs_out <= instqueue_decoder_inst_in[19 : 15];
                    decoder_RS_rt_out <= instqueue_decoder_inst_in[24 : 20];
                    decoder_RS_rd_out <= instqueue_decoder_inst_in[11 : 7];
                    case (instqueue_decoder_inst_in[14 : 12])
                        3'b000: decoder_RS_opcode_out <= instqueue_decoder_inst_in[31 : 25] == 0 ? ADD : SUB;
                        3'b001: decoder_RS_opcode_out <= SLL;
                        3'b010: decoder_RS_opcode_out <= SLT;
                        3'b011: decoder_RS_opcode_out <= SLTU;
                        3'b100: decoder_RS_opcode_out <= XOR;
                        3'b101: decoder_RS_opcode_out <= instqueue_decoder_inst_in[31 : 25] == 0 ? SRL : SRA;
                        3'b110: decoder_RS_opcode_out <= OR;
                        3'b111: decoder_RS_opcode_out <= AND;
                    endcase
                end
                19: begin
                    decoder_RS_rs_out <= instqueue_decoder_inst_in[19 : 15];
                    decoder_RS_rd_out <= instqueue_decoder_inst_in[11 : 7];
                    decoder_RS_imm_out <= $signed(instqueue_decoder_inst_in[31 : 20]);
                    case (instqueue_decoder_inst_in[14 : 12])
                        3'b000: decoder_RS_opcode_out <= ADDI;
                        3'b001: begin
                            decoder_RS_opcode_out <= SLLI;
                            decoder_RS_imm_out <= $unsigned(instqueue_decoder_inst_in[24 : 20]);
                        end
                        3'b010: decoder_RS_opcode_out <= SLTI;
                        3'b011: decoder_RS_opcode_out <= SLTIU;
                        3'b100: decoder_RS_opcode_out <= XORI;
                        3'b101: begin
                            decoder_RS_opcode_out <= instqueue_decoder_inst_in[31 : 25] == 0 ? SRLI : SRAI;
                            decoder_RS_imm_out <= $unsigned(instqueue_decoder_inst_in[24 : 20]);
                        end
                        3'b110: decoder_RS_opcode_out <= ORI;
                        3'b111: decoder_RS_opcode_out <= ANDI;
                    endcase
                end
                3: begin
                    decoder_RS_rs_out <= instqueue_decoder_inst_in[19 : 15];
                    decoder_RS_rd_out <= instqueue_decoder_inst_in[11 : 7];
                    decoder_RS_imm_out <= $signed(instqueue_decoder_inst_in[31 : 20]);
                    case (instqueue_decoder_inst_in[14 : 12])
                        3'b000: decoder_RS_opcode_out <= LB;
                        3'b001: decoder_RS_opcode_out <= LH;
                        3'b010: decoder_RS_opcode_out <= LW;
                        3'b100: decoder_RS_opcode_out <= LBU;
                        3'b101: decoder_RS_opcode_out <= LHU;
                    endcase
                end
                103: begin
                    decoder_RS_rs_out <= instqueue_decoder_inst_in[19 : 15];
                    decoder_RS_rd_out <= instqueue_decoder_inst_in[11 : 7];
                    decoder_RS_imm_out <= $signed(instqueue_decoder_inst_in[31 : 20]);
                    decoder_RS_opcode_out <= JALR;
                end
                35: begin
                    decoder_RS_rs_out <= instqueue_decoder_inst_in[19 : 15];
                    decoder_RS_rt_out <= instqueue_decoder_inst_in[24 : 20];
                    decoder_RS_imm_out <= $signed({instqueue_decoder_inst_in[31 : 25], instqueue_decoder_inst_in[11 : 7]});
                    case (instqueue_decoder_inst_in[14 : 12])
                        3'b000: decoder_RS_opcode_out <= SB;
                        3'b001: decoder_RS_opcode_out <= SH;
                        3'b010: decoder_RS_opcode_out <= SW;
                    endcase
                end
                99: begin
                    decoder_RS_rs_out <= instqueue_decoder_inst_in[19 : 15];
                    decoder_RS_rt_out <= instqueue_decoder_inst_in[24 : 20];
                    decoder_RS_imm_out <= $signed({instqueue_decoder_inst_in[31], instqueue_decoder_inst_in[7], instqueue_decoder_inst_in[30 : 25], instqueue_decoder_inst_in[11 : 8], 1'b0})
                    case (instqueue_decoder_inst_in[14 : 12])
                        3'b000: decoder_RS_opcode_out <= BEQ;
                        3'b001: decoder_RS_opcode_out <= BNE;
                        3'b100: decoder_RS_opcode_out <= BLT;
                        3'b101: decoder_RS_opcode_out <= BGE;
                        3'b110: decoder_RS_opcode_out <= BLTU;
                        3'b111: decoder_RS_opcode_out <= BGEU;
                    endcase
                    decoder_bp_en_out <= 1'b1;
                    decoder_bp_pc_out <= instqueue_decoder_pc_in;
                end
                111: begin
                    decoder_RS_rd_out <= instqueue_decoder_inst_in[11 : 7];
                    decoder_RS_opcode_out <= JAL;
                    decoder_if_en_out <= 1'b1;
                    decoder_if_addr_out <= $signed({instqueue_decoder_inst_in[31], instqueue_decoder_inst_in[19 : 12], instqueue_decoder_inst_in[20], instqueue_decoder_inst_in[30 : 25], instqueue_decoder_inst_in[24 : 21], 1'b0}) + instqueue_decoder_pc_in;
                end
                23: begin
                    decoder_RS_rd_out <= instqueue_decoder_inst_in[11 : 7];
                    decoder_RS_imm_out <= {instqueue_decoder_inst_in[31 : 12], 12'b0};
                    decoder_RS_opcode_out <= AUIPC;
                end
                55: begin
                    decoder_RS_rd_out <= instqueue_decoder_inst_in[11 : 7];
                    decoder_RS_imm_out <= {instqueue_decoder_inst_in[31 : 12], 12'b0};
                    decoder_RS_opcode_out <= LUI;
                end
            endcase
        end
    end

endmodule : decoder