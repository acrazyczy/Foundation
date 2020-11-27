`include "constant.vh"

module IF(
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    //from & to icache
    input wire icache_if_rdy_in,
    input wire icache_if_miss_in,
    input wire[`IDWidth - 1 : 0] icache_if_inst_inst_in,
    output reg if_icache_en_out,
    output reg if_icache_inst_addr_out,

    //from & to instruction queue
    output reg if_instqueue_en_out,
    output reg[`IDWidth - 1 : 0] if_instqueue_inst_out,
    output reg[`AddressWidth - 1 : 0] if_instqueue_pc_out,

    //from branch predictor
    input wire bp_if_en_in,
    input wire[`AddressWidth - 1 : 0] bp_if_pc_in,

    //from decoder
    input wire decoder_if_en_in,
    input wire[`AddressWidth - 1 : 0] decoder_if_pc_in,

    //from reorder buffer
    input wire rob_if_en_in,
    input wire[`AddressWidth - 1 : 0] rob_if_pc_in
);

    reg[`AddressWidth - 1 : 0] pc;

    always @(posedge clk_in) begin
        if (rst_in) begin
            if_icache_en_in <= 1'b0;
            if_instqueue_en_in <= 1'b0;
            pc <= `AddressWidth'b0;
        end else if (rdy_in) begin
            if_instqueue_en_out <= 1'b0;
            if (rob_if_en_in) begin
                if (icache_if_rdy_in) begin
                    if_icache_en_out <= 1'b1;
                    if_icache_inst_addr_out <= rob_if_pc_in;
                end
                pc <= rob_if_pc_in;
            end else if (decoder_if_en_in) begin
                if (icache_if_rdy_in) begin
                    if_icache_en_out <= 1'b1;
                    if_icache_inst_addr_out <= decoder_if_pc_in;
                end
                pc <= decoder_if_pc_in;
            end else if (bp_if_en_in) begin
                if (bp_if_rdy_in) begin
                    if_icache_en_out <= 1'b1;
                    if_icache_inst_addr_out <= bp_if_pc_in;
                end
                pc <= bp_if_pc_in;
            end else if (!icache_if_miss_in) begin
                if_instqueue_en_out <= 1'b1;
                if_instqueue_inst_out <= icache_if_inst_inst_in;
                if_instqueue_pc_out <= pc;
                pc <= pc + 4;
                if_icache_en_out <= 1'b1;
                if_icache_inst_addr_out <= pc + 4;
            end
        end
    end

endmodule : IF