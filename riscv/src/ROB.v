`include "constant.vh"

module rob(
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
    input wire[`AddressWidth - 1 : 0] dispatcher_rob_pc_in,
    input wire dispatcher_rob_taken_in,

    //to instruction fetch
    output reg[`AddressWidth - 1 : 0] rob_if_pc_out,

    //to instruction queue
    output wire rob_instqueue_rdy_out,

    //from & to load buffer
    input wire[`ROBWidth - 1 : 0] lbuffer_rob_dest_in,
    input wire[`IDWidth - 1 : 0] lbuffer_rob_value_in,
    input wire lbuffer_rob_en_in,
    input wire[`ROBWidth - 1 : 0] lbuffer_rob_rob_index_in,
    input wire[`LBWidth - 1 : 0] lbuffer_rob_lbuffer_index_in,
    output wire[`LBCount - 1 : 0] rob_lbuffer_state_out,

    //to regfile
    output wire rob_regfile_en_out,
    output wire[`RegWidth - 1 : 0] rob_regfile_d_out,
    output wire[`IDWidth - 1 : 0] rob_regfile_value_out,
    output wire[`ROBWidth - 1 : 0] rob_regfile_h_out,

    //from & to reservation station
    input wire[`ROBWidth - 1 : 0] rs_rob_h_in,
    input wire[`IDWidth - 1 : 0] rs_rob_value_in,

    //from & to datactrl
    output wire rob_datactrl_en_out,
    output wire[`AddressWidth - 1 : 0] rob_datactrl_addr_out,
    output wire[2 : 0] rob_datactrl_width_out,
    output wire[`IDWidth - 1 : 0] rob_datactrl_data_out,
    input wire datactrl_rob_en_in,
);
    localparam IDLE = 1'b0;
    localparam BUSY = 1'b1;

    reg busy[`ROBCount - 1 : 0];
    reg[`InstTypeWidth - 1 : 0] opcode[`ROBCount - 1 : 0];
    reg[`RegWidth - 1 : 0] dest[`ROBCount - 1 : 0];
    reg[`AddressWidth - 1 : 0] pc[`ROBCount - 1 : 0];
    reg[`IDWidth - 1 : 0] value[`ROBCount - 1 : 0];
    reg[`AddressWidth - 1 : 0] address[`ROBCount - 1 : 0];
    reg bp_taken[`ROBCount - 1 : 0];
    reg ready[`ROBCount - 1 : 0];
    reg activated[`ROBCount - 1 : 0];
    reg[`LBWidth - 1 : 0] index[`ROBCount - 1 : 0];
    reg[`ROBWidth - 1 : 0] occupation[`ROBCount - 1 : 0];
    reg[`ROBWidth - 1 : 0] head, tail;
    reg state;

    always @(posedge clk_in) begin
        if (rst_in) begin
            head <= `ROBCount'b1;
            tail <= `ROBCount'b1;
            for (i = 1;i < `ROBCount;i = i + 1) busy[i] <= 1'b0;
            rob_instqueue_rdy_out <= 1'b1;
        end if (rdy_in) if (dispatcher_rob_en_in) begin
            busy[tail] <= 1'b1;
            opcode[tail] <= dispatcher_rob_opcode_in;
            dest[tail] <= dispatcher_rob_dest_in;
            pc[tail] <= dispatcher_rob_pc_in;
            bp_taken[tail] <= dispatcher_rob_taken_in;
            activated[tail] <= 1'b0;
            ready[tail] <= 1'b0;
            tail <= tail % `ROBCount + 1;
        end
    end

    always @(posedge clk_in) begin
        rob_bp_en_out <= 1'b0;
        rob_regfile_en_out <= 1'b0;
        rob_lbuffer_state_out <= `LBCount'b0;
        if (!rst_in && rdy_in)
            if (state == IDLE && head != tail && ready[head] == 1'b1) begin
                if (`BEQ <= opcode[head] && opcode[head] <= `BGEU) begin
                    rob_bp_en_out <= 1'b1;
                    if (bp_taken[head] != alu_taken[head]) begin
                        if (result[head]) rob_if_pc_out <= $signed({opcode[head][31], opcode[head][7], opcode[head][30 : 25], opcode[head][11 : 8], 1'b0}) + pc[head];
                        else rob_if_pc_out <= $signed(3'b100) + pc[head];
                        rob_rst_out <= 1'b1;
                    end else rob_bp_correct_out <= 1'b1;
                    rob_bp_pc_out <= pc[head];
                    busy[head] <= 1'b0;
                    head <= head % `ROBCount + 1;
                end else if (`SB <= opcode[head] && opcode[head] <= `SW) state <= BUSY;
                else begin
                    rob_regfile_en_out <= 1'b1;
                    rob_regfile_d_out <= dest[head];
                    rob_regfile_value_out <= value[head];
                    rob_regfile_h_out <= head;
                    busy[head] <= 1'b0;
                    head <= head % `ROBCount + 1;
                end
            end
    end

    always @(*) begin
        if (!rst_in && rdy_in) if (lbuffer_rob_en_in) begin
            activate[lbuffer_rob_rob_index_in] = 1'b1;
            occupation[lbuffer_rob_rob_index_in] = `ROBWidth'b0;
            index[lbuffer_rob_rob_index_in] = lbuffer_rob_lbuffer_index_in;
            for (i = head;i != lbuffer_rob_index_in;i = i % `ROBCount + 1)
                if (`SB <= opcode[i] && opcode[i] <= `SW && address[i] == address[lbuffer_rob_rob_index_in])
                    occupation[lbuffer_rob_rob_index_in] = occupation[lbuffer_rob_rob_index_in] + 1;
        end
    end

    always @(*) begin
        rob_lbuffer_state_out = `LBCount'b0;
        if (!rst_in && rdy_in) begin
            for (i = 1;i < `ROBCount;i = i + 1)
                if (busy[i] && activate[i] && occupation[i] == `ROBWidth'b0)
                    rob_lbuffer_state_out = rob_lbuffer_state_out | (1 << index[i]);
        end
    end

    always @(*) begin
        if (rst_in) state = IDLE;
        else if (rdy_in) if (state == BUSY) begin
            if (datactrl_rob_en_in) begin
                rob_datactrl_en_in = 1'b0;
                for (i = head;i != tail;i = i % `ROBCount + 1)
                    if (activated[i] && address[i] == address[head])
                        occupation[i] = occupation[i] - 1;
                busy[head] = 1'b0;
                head = head % `ROBCount + 1;
                state = IDLE;
            end else begin
                rob_datactrl_en_in = 1'b1;
                rob_datactrl_addr_out = address[head];
                rob_datactrl_data_out = value[head];
                case (opcode[head])
                    `SB: rob_datactrl_width_out = 3'b001;
                    `SH: rob_datactrl_width_out = 3'b010;
                    `SW: rob_datactrl_width_out = 3'b100;
                endcase
            end
        end
    end

    assign rob_instqueue_rdy_out = head != tail;
    assign rob_dispatcher_rs_ready_out = ready[dispatcher_rob_rs_h_in];
    assign rob_dispatcher_rs_value_out = value[dispatcher_rob_rs_h_in];
    assign rob_dispatcher_rt_ready_out = ready[dispatcher_rob_rt_h_in];
    assign rob_dispatcher_rt_value_out = value[dispatcher_rob_rt_h_in];
    assign rob_dispatcher_b_out = tail;

endmodule : rob