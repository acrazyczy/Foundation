`include "constant.vh"

module RS(
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    //to instruction queue
    output reg rs_instqueue_rdy_out,

    //from dispatcher
    input wire dispatcher_rs_en_in,
    input wire[`IDWidth - 1 : 0] dispatcher_rs_a_in,
    input wire[`ROBWidth - 1 : 0] dispatcher_rs_qj_in,
    input wire[`IDWidth - 1 : 0] dispatcher_rs_vj_in,
    input wire[`ROBWidth - 1 : 0] dispatcher_rs_qk_in,
    input wire[`IDWidth - 1 : 0] dispatcher_rs_vk_in,
    input wire[`ROBWidth - 1 : 0] dispatcher_rs_dest_in,
    input wire[`AddressWidth - 1 : 0] dispatcher_rs_pc_in,

    //from reorder buffer
    input wire rob_rs_rst_in,

    //to load buffer
    output wire rs_lbuffer_en_out,
    output wire[`IDWidth - 1 : 0] rs_lbuffer_a_in,
    output wire[`ROBWidth - 1 : 0] rs_lbuffer_dest_in,

    //from & to common data bus
    input wire cdb_rs_en,
    input wire[`ROBWidth - 1 : 0] cdb_rs_b_in,
    input wire[`IDWidth - 1 : 0] cdb_rs_result_in,
    output wire rs_cdb_en,
    output wire[`ROBWidth - 1 : 0] rs_cdb_b_out,
    output wire[`ROBWidth - 1 : 0] rs_cdb_result_out
);
    reg busy[`RSCount - 1 : 0];
    reg[`IDWidth - 1 : 0] a[`RSCount - 1 : 0];
    reg[`ROBWidth - 1 : 0] qj[`RSCount - 1 : 0];
    reg[`IDWidth - 1 : 0] vj[`RSCount - 1 : 0];
    reg[`ROBWidth - 1 : 0] qk[`RSCount - 1 : 0];
    reg[`IDWidth - 1 : 0] vk[`RSCount - 1 : 0];
    reg[`ROBWidth - 1 : 0] dest[`RSCount - 1 : 0];
    reg[`AddressWidth - 1 : 0] pc[`RSCount - 1 : 0];
    reg[`RSWidth - 1 : 0] id;

    always @(posedge clk_in) begin
        if (rst_in) begin
            id <= `RSWidth'b0;
            for (i = 0;i < `RSCount;++ i) busy[i] <= 1'b0;
        end else if (rdy_in) if (rob_rs_rst_in) begin
            id <= `RSWidth'b0;
            for (i = 0;i < `RSCount;++ i) busy[i] <= 1'b0;
        end else if (dispatcher_rs_en_in) begin
            busy[id] <= 1'b1;
            a[id] <= dispatcher_rs_a_in;
            qj[id] <= dispatcher_rs_qj_in;
            vj[id] <= dispatcher_rs_vj_in;
            qk[id] <= dispatcher_rs_qk_in;
            vk[id] <= dispatcher_rs_vk_in;
            dest[id] <= dispatcher_rs_dest_in;
            pc[id] <= dispatcher_rs_pc_in;
        end
    end

    always @(*) begin
        if (rst_in) begin
            id = `RSWidth'b0;
            for (i = 0;i < `RSCount;++ i) busy[i] = 1'b0;
        end else if (rdy_in) if (rob_rs_rst_in) begin
            id = `RSWidth'b0;
            for (i = 0;i < `RSCount;++ i) busy[i] = 1'b0;
        end else begin
            if (cdb_rs_en) begin
                for (i = 0;i < `RSCount;++ i) begin
                    if (qj[i] == cdb_rs_b_in) begin
                        vj[i] = cdb_rs_result_in;
                        qj[i] = `ROBWidth'b0;
                    end
                    if (qk[i] == cdb_rs_b_in) begin
                        vk[i] = cdb_rs_result_in;
                        qk[i] = `ROBWidth'b0;
                    end
                end
            end
            for (i = 0;i < `RSCount;++ i) begin

            end
        end
    end
endmodule : RS