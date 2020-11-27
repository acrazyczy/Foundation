`include "constant.vh"

module dispatcher(
    input clk_in,
    input rst_in,
    input rdy_in,

    //from decoder
    input wire[`RegWidth - 1 : 0] decoder_dispatcher_rs_in, decoder_dispatcher_rt_in, decoder_dispatcher_rd_in,
    input wire[`IDWidth - 1 : 0] decoder_dispatcher_imm_in,
    input wire[`InstTypeWidth - 1 : 0] decoder_dispatcher_opcode_in,
    input wire[`AddressWidth - 1 : 0] decoder_dispatcher_pc_in,

    //from & to regfile
    output wire[`RegWidth - 1 : 0] dispatcher_regfile_rs_out,
    input wire regfile_dispatcher_rs_busy_in,
    input wire[`IDWidth - 1 : 0] regfile_dispatcher_rs_in,
    input wire[`ROBWidth - 1 : 0] regfile_dispatcher_rs_reorder_in,
    output wire[`RegWidth - 1 : 0] dispatcher_regfile_rt_out,
    input wire regfile_dispatcher_rt_busy_in,
    input wire[`IDWidth - 1 : 0] regfile_dispatcher_rt_in,
    input wire[`ROBWidth - 1 : 0] regfile_dispatcher_rt_reorder_in,
    output wire dispatcher_regfile_rd_en_out,
    output wire[`RegWidth - 1 : 0] dispatcher_regfile_rd_out,
    output wire dispatcher_regfile_reorder_out,

    //from & to reservation station
    input wire[`RSWidth - 1 : 0] rs_dispatcher_r_in,
    output wire dispatcher_rs_en_out,
    output wire[`IDWidth - 1 : 0] dispatcher_rs_a_out,
    output wire[`ROBWidth - 1 : 0] dispatcher_rs_qj_out,
    output wire[`IDWidth - 1 : 0] dispatcher_rs_vj_out,
    output wire[`ROBWidth - 1 : 0] dispatcher_rs_qk_out,
    output wire[`IDWidth - 1 : 0] dispatcher_rs_vk_out,
    output wire[`ROBWidth - 1 : 0] dispatcher_rs_dest_out,
    output wire[`AddressWidth - 1 : 0] dispatcher_rs_pc_out,

    //from & to reorder buffer
    output wire[`ROBWidth - 1 : 0] dispatcher_rob_rs_h_out,
    input wire rob_dispatcher_rs_ready_in,
    input wire[`IDWidth - 1 : 0] rob_dispatcher_rs_value_in,
    output wire[`ROBWidth - 1 : 0] dispatcher_rob_rt_h_out,
    input wire rob_dispatcher_rt_ready_in,
    input wire[`IDWidth - 1 : 0] rob_dispatcher_rt_value_in,
    input wire[`ROBWidth - 1 : 0] rob_dispatcher_b_in,
    output wire dispatcher_rob_en_out,
    output wire[`InstTypeWidth - 1 : 0] dispatcher_rob_opcode_out,
    output wire[`RegWidth - 1 : 0] dispatcher_rob_dest_out,
    output wire[`AddressWidth - 1 : 0] dispatcher_rob_pc_out
);

    always @(*) begin
        if (rst_in) begin
            dispatcher_regfile_rd_en_out = 1'b0;
            dispatcher_rs_en_out = 1'b0;
            dispatcher_rob_en_out = 1'b0;
        end else if (rdy_in && decoder_dispatcher_opcode_in != `NOP) begin
            dispatcher_rs_pc_out = decoder_dispatcher_pc_in;

            dispatcher_regfile_rs_out = decoder_dispatcher_rs_in;
            if (regfile_dispatcher_rs_busy_in) begin
                dispatcher_rob_rs_h_out = regfile_dispatcher_rs_reorder_in;
                if (rob_dispatcher_rs_ready_in) begin
                    dispatcher_rs_vj_out = rob_dispatcher_rs_value_in;
                    dispatcher_rs_qj_out = `ROBWidth'b0;
                end else dispatcher_rs_qj = regfile_dispatcher_rs_reorder_in;
            end else begin
                dispatcher_rs_vj_out = regfile_dispatcher_rs_in;
                dispatcher_rs_qj_out = `ROBWidth'b0;
            end
            dispatcher_rs_dest_out = rob_dispatcher_b_in;
            dispatcher_rob_opcode_out = decoder_dispatcher_opcode_in;
            dispatcher_rob_dest_out = decoder_dispatcher_rd_in;

            dispatcher_regfile_rt_out = decoder_dispatcher_rt_in;
            if (regfile_dispatcher_rt_busy_in) begin
                dispatcher_rob_rt_h_out = regfile_dispatcher_rt_reorder_in;
                if (rob_dispatcher_rt_ready_in) begin
                    dispatcher_rs_vk_out = rob_dispatcher_rt_value_in;
                    dispatcher_rs_qk_out = `ROBWidth'b0;
                end else dispatcher_rt_qj = regfile_dispatcher_rt_reorder_in;
            end else begin
                dispatcher_rs_vk_out = regfile_dispatcher_rt_in;
                dispatcher_rs_qk_out = `ROBWidth'b0;
            end

            dispatcher_rs_a_out = decoder_dispatcher_imm_in;
            dispatcher_regfile_reorder_out = rob_dispatcher_b_in;
            dispatcher_rob_dest_out = decoder_dispatcher_rd_in;
        end
    end

endmodule : dispatcher