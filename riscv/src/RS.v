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
    input wire[`InstTypeWidth - 1 : 0] dispatcher_rs_opcode_in,

    //from & to reorder buffer
    input wire rob_rs_rst_in,
    output wire[`ROBWidth - 1 : 0] rs_rob_h_out, //if h is zero, no rob is selected
    output wire[`IDWidth - 1 : 0] rs_rob_value_out,

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
    input wire cdb_rs_en,
    input wire[`ROBWidth - 1 : 0] cdb_rs_b_in,
    input wire[`IDWidth - 1 : 0] cdb_rs_result_in,
);
    reg busy[`RSCount - 1 : 0];
    reg[`IDWidth - 1 : 0] a[`RSCount - 1 : 0];
    reg[`ROBWidth - 1 : 0] qj[`RSCount - 1 : 0];
    reg[`IDWidth - 1 : 0] vj[`RSCount - 1 : 0];
    reg[`ROBWidth - 1 : 0] qk[`RSCount - 1 : 0];
    reg[`IDWidth - 1 : 0] vk[`RSCount - 1 : 0];
    reg[`ROBWidth - 1 : 0] dest[`RSCount - 1 : 0];
    reg[`AddressWidth - 1 : 0] pc[`RSCount - 1 : 0];
    reg[`InstTypeWidth - 1 : 0] opcode[`RSCount - 1 : 0];
    reg[`RSWidth - 1 : 0] id;
    reg[`RSWidth - 1 : 0] ready_to_AddressUnit;
    reg[`RSWidth - 1 : 0] ready_to_ALU;
    reg in_LS_queue[`RSCount - 1 : 0];
    reg[`RSWidth - 1 : 0] LS_queue[`RSCount - 1 : 0];
    reg[`RSWidth - 1 : 0] head, tail;
    reg switch_flag;

    localparam NRS = `RSWidth'b0;

    always @(posedge clk_in) begin
        switch_flag <= switch_flag ^ 1;
        ready_to_AddressUnit <= NRS;
        rs_addrunit_opcode_out <= `NOP;
        ready_to_ALU <= NRS;
        rs_alu_opcode_out <= `NOP;
        rs_rob_h_out <= `ROBWidth'b0;
        if (rst_in) begin
            id <= `RSWidth'b1;
            for (i = 1;i < `RSCount;i = i + 1) begin
                busy[i] <= 1'b0;
                in_LS_queue[i] <= 1'b0;
            end
            head <= `RSWidth'b0;
            tail <= `RSWidth'b0;
        end else if (rdy_in) if (rob_rs_rst_in) begin
            id <= `RSWidth'b1;
            for (i = 1;i < `RSCount;i = i + 1) begin
                busy[i] <= 1'b0;
                in_LS_queue[i] <= 1'b0;
            end
            head <= `RSWidth'b0;
            tail <= `RSWidth'b0;
        end else begin
            if (dispatcher_rs_en_in) begin
                busy[id] <= 1'b1;
                a[id] <= dispatcher_rs_a_in;
                qj[id] <= dispatcher_rs_qj_in;
                vj[id] <= dispatcher_rs_vj_in;
                qk[id] <= dispatcher_rs_qk_in;
                vk[id] <= dispatcher_rs_vk_in;
                dest[id] <= dispatcher_rs_dest_in;
                pc[id] <= dispatcher_rs_pc_in;
                opcode[id] <= dispatcher_rs_opcode_in;
                if (`LB <= dispatcher_rs_opcode_in && dispatcher_rs_opcode_in <= `SW) begin
                    in_LS_queue[id] = 1'b1;
                    LS_queue[tail] <= id;
                    tail <= tail % (`RSCount - 1) + 1;
                end
                id <= NRS;
            end
            for (i = 1;i < `RSCount;i = i + 1)
                if (busy[i])
                    if (`LB <= opcode[i] && opcode[i] <= `LHU) begin
                        if (qj[i] == `ROBWidth'b0 && !in_LS_queue[i]) begin
                            ready_to_AddressUnit <= i;
                            rs_addrunit_a_out <= a[i];
                            rs_addrunit_vj_out <= vj[i];
                            rs_addrunit_dest_out <= dest[i];
                            rs_addrunit_opcode_out <= opcode[i];
                        end
                    end else if (`SB <= opcode[i] && opcode[i] <= `SW) begin
                        if (qj[i] == `ROBWidth'b0 && LS_queue[head] == i) begin
                            ready_to_AddressUnit <= i;
                            rs_addrunit_a_out <= a[i];
                            rs_addrunit_vj_out <= vj[i];
                            rs_addrunit_qk_out <= qk[i];
                            rs_addrunit_vk_out <= vk[i];
                            rs_addrunit_dest_out <= dest[i];
                            rs_addrunit_opcode_out <= opcode[i];
                        end
                    end else if (`BEQ <= opcode[i] && opcode[i] <= `BGEU || `ADD <= opcode[i] && opcode[i] <= `AND) begin
                        if (qj[i] == `ROBWidth'b0 && qk[i] == `ROBWidth'b0) begin
                            ready_to_ALU <= i;
                            rs_alu_vj_out <= vj[i];
                            rs_alu_vk_out <= vk[i];
                            rs_alu_dest_out <= dest[i];
                            rs_alu_pc_out <= pc[i];
                            rs_alu_opcode_out <= opcode[i];
                        end
                    end else if (opcode[i] == `JALR || `ADDI <= opcdoe[i] && opcode[i] <= `SRAI) begin
                        if (qj[i] == `ROBWidth'b0) begin
                            ready_to_ALU <= i;
                            rs_alu_a_out <= a[i];
                            rs_alu_vj_out <= vj[i];
                            rs_alu_dest_out <= dest[i];
                            rs_alu_pc_out <= pc[i];
                            rs_alu_opcode_out <= opcode[i];
                        end
                    end else if (`LUI <= opcode[i] && opcode[i] <= `JAL) begin
                        ready_to_ALU <= i;
                        rs_alu_a_out <= a[i];
                        rs_alu_vj_out <= vj[i];
                        rs_alu_dest_out <= dest[i];
                        rs_alu_pc_out <= pc[i];
                        rs_alu_opcode_out <= opcode[i];
                    end
                else if (i != id || !dispatcher_rs_en_in) id <= i;
        end
    end

    always @(posedge clk_in) begin
        if (!rst_in && rdy_in) begin
            if (ready_to_AddressUnit != NRS)
                if (`LB <= opcode[ready_to_AddressUnit] && opcode[ready_to_AddressUnit] <= `LHU) begin
                    busy[ready_to_AddressUnit] <= 1'b0;
                    id <= ready_to_AddressUnit;
                end else begin
                    in_LS_queue[ready_to_AddresssUnit] <= 1'b0;
                    head <= head % (`RSCount - 1) + 1;
                end
            if (ready_to_ALU != NRS) busy[ready_to_ALU] = 1'b0;
        end
    end

    always @(*) begin
        if (rst_in) begin
            id = `RSWidth'b1;
            for (i = 1;i < `RSCount;i = i + 1) begin
                busy[i] = 1'b0;
                in_LS_queue[i] = 1'b0;
            end
            head = `RSWidth'b0;
            tail = `RSWidth'b0;
        end else if (rdy_in) if (rob_rs_rst_in) begin
            id = `RSWidth'b1;
            for (i = 1;i < `RSCount;i = i + 1) begin
                busy[i] = 1'b0;
                in_LS_queue[i] = 1'b0;
            end
            head = `RSWidth'b0;
            tail = `RSWidth'b0;
        end else begin
            if (cdb_rs_en) begin
                for (i = 1;i < `RSCount;i = i + 1) begin
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
            for (i = 1;i < `RSCount;i = i + 1)
                if (`SB <= opcode[i] && opcode[i] <= `SW && qk[i] == `ROBWidth'b0 && !in_LS_queue[i]) begin
                    rs_rob_h_out = dest[i];
                    rs_rob_value_out = vk[i];
                    busy[i] = 1'b0;
                    id = i;
                end
            while (head != tail && `LB <= opcode[LS_queue[head]] && opcode[LS_queue[head]] <= `LHU) begin
                in_LS_queue[LS_queue[head]] = 1'b0;
                head = head % (`RSCount - 1) + 1;
            end
        end
    end

    assign rs_instqueue_rdy_out = id != NRS;
endmodule : RS