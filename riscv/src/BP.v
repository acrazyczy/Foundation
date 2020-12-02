`include "constant.vh"

module BP(
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    //from decoder
    input wire decoder_bp_en_in,
    input wire[`AddressWidth - 1 : 0] decoder_bp_pc_in,
    input wire[`AddressWidth - 1 : 0] decoder_bp_target_in,

    //to instruction queue
    output wire bp_instqueue_rst_out,

    //to instruction fetch
    output wire bp_if_en_out,
    output wire[`AddressWidth - 1 : 0] bp_if_pc_out,

    //to dispatcher
    output wire bp_dispatcher_taken_out,

    //from reorder buffer
    input wire rob_bp_en_in,
    input wire rob_bp_correct_in,
    input wire[`AddressWidth - 1 : 0] rob_bp_pc_in
);
    localparam mask = (1 << 7) - 1;

    reg[1 : 0] prediction[mask : 0];

    always @(*) begin
        if (rst_in) begin
            for (i = 0;i <= mask;i = i + 1) prediction[i] = 2'b01;
        end else if (rdy_in) begin
            if (decoder_bp_en_in) begin
                if (prediction[(decoder_bp_pc_in >> 2) & mask] > 2'b01) begin
                    bp_if_en_out = 1'b1;
                    bp_if_pc_out = decoder_bp_target_in;
                    bp_dispatcher_taken_out = 1'b1;
                    bp_instqueue_rst_out = 1'b1;
                end else begin
                    bp_if_en_out = 1'b0;
                    bp_dispatcher_taken_out = 1'b0;
                    bp_instqueue_rst_out = 1'b0;
                end
            end
            if (rob_bp_en_in)
                if (rob_bp_correct_in)
                    prediction[(rob_bp_pc_in >> 2) & mask] = prediction[(rob_bp_pc_in >> 2) & mask] ^ (^ prediction[(rob_bp_pc_in >> 2) & mask]);
                else
                    prediction[(rob_bp_pc_in >> 2) & mask] = prediction[(rob_bp_pc_in >> 2) & mask] ^ 1 ^ ((^ prediction[(rob_bp_pc_in >> 2) & mask]) << 1);
        end
    end
endmodule : BP