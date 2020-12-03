`include "constant.vh"

module lbuffer(
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    //from address unit
    input wire addrunit_lbuffer_en_in,
    input wire[`AddressWidth - 1 : 0] addrunit_lbuffer_a_in,
    input wire[`ROBWidth - 1 : 0] addrunit_lbuffer_dest_in,
    input wire[`InstTypeWidth - 1 : 0] addrunit_lbuffer_opcode_in,

    //from & to reorder buffer
    input wire rob_lbuffer_rst_in,
    output wire[`ROBWidth - 1 : 0] lbuffer_rob_dest_out,
    output wire[`IDWidth - 1 : 0] lbuffer_rob_value_out,
    output wire lbuffer_rob_en_out,
    output wire[`ROBWidth - 1 : 0] lbuffer_rob_rob_index_out,
    output wire[`LBWidth - 1 : 0] lbuffer_rob_lbuffer_index_out,
    input wire[`LBCount - 1 : 0] rob_lbuffer_state_in,

    //from & to datactrl
    output wire lbuffer_datactrl_en_out,
    output wire[`AddressWidth - 1 : 0] lbuffer_datactrl_addr_out,
    output wire[2 : 0] lbuffer_datactrl_width_out,
    output wire lbuffer_datactrl_sgn_out,
    input wire datactrl_lbuffer_en_in,
    input wire[`IDWidth - 1 : 0] datactrl_lbuffer_data_in
);
    localparam IDLE = 1'b0;
    localparam BUSY = 1'b1;

    reg busy[`LBCount - 1 : 0];
    reg[`AddressWidth - 1 : 0] a[`LBCount - 1 : 0];
    reg[`ROBWidth - 1 : 0] dest[`LBCount - 1 : 0];
    reg[`InstTypeWidth - 1 : 0] opcode[`LBCount - 1 : 0];
    reg[`LBWidth - 1 : 0] id;
    reg switch_flag, state;
    reg[`LBWidth - 1 : 0] load_id;

    always @(posedge clk_in) begin
        switch_flag <= switch_flag ^ 1'b1;
        lbuffer_rob_en_out <= 1'b0;
        if (rst_in) begin
            id <= `LBWidth'b0;
            for (i = 0;i < `LBCount;i = i + 1) busy[i] <= 1'b0;
        end else if (rdy_in) if (rob_rst_in) begin
            id <= `LBWidth'b0;
            for (i = 0;i < `LBCount;i = i + 1) busy[i] <= 1'b0;
        end else begin
            if (addrunit_lbuffer_en_in) begin
                busy[id] <= 1'b1;
                a[id] <= addrunit_lbuffer_a_in;
                dest[id] <= addrunit_lbuffer_dest_in;
                opcode[id] <= addrunit_lbuffer_opcode_in;
                ready[id] <= 1'b0;
                lbuffer_rob_en_out <= 1'b1;
                lbuffer_rob_rob_index_out <= addrunit_lbuffer_dest_in;
                lbuffer_rob_lbuffer_index_out <= id;
            end
            if (state == IDLE) begin
                for (i = 0;i < `LBCount;++ i)
                    if (busy[i] && ready[i]) begin
                        state = BUSY;
                        load_id = i;
                    end
            end
            for (i = 0;i < `LBCount;i = i + 1)
                if (((rob_lbuffer_state_in >> i) & 1) != `LBCount'b0)
                    ready[i] <= 1'b1;
        end
    end

    always @(*) begin
        if (rst_in) begin
            for (i = 0;i < `LBCount;i = i + 1) busy[i] = 1'b0;
            state = IDLE;
        end if (rdy_in) if (rob_lbuffer_rst_in) begin
            for (i = 0;i < `LBCount;i = i + 1) busy[i] = 1'b0;
            state = IDLE;
        end else begin
            if (state == BUSY)
                if (datactrl_lbuffer_en_in) begin
                    lbuffer_rob_dest_out = dest[load_id];
                    lbuffer_rob_value_out = datactrl_lbuffer_data_in;
                    lbuffer_datactrl_en_out = 1'b0;
                    busy[load_id] = 1'b0;
                    state = IDLE;
                end else begin
                    lbuffer_datactrl_en_out = 1'b1;
                    lbuffer_datactrl_addr_out = a[load_id];
                    case (opcode[load_id])
                        `LB: begin
                            lbuffer_datactrl_sgn_out = 1'b1;
                            lbuffer_datactrl_width_out = 3'b001;
                        end
                        `LH: begin
                            lbuffer_datactrl_sgn_out = 1'b1;
                            lbuffer_datactrl_width_out = 3'b010;
                        end
                        `LW: begin
                            lbuffer_datactrl_sgn_out = 1'b0;
                            lbuffer_datactrl_width_out = 3'b100;
                        end
                        `LBU: begin
                            lbuffer_datactrl_sgn_out = 1'b0;
                            lbuffer_datactrl_width_out = 3'b001;
                        end
                        `LHU: begin
                            lbuffer_datactrl_sgn_out = 1'b0;
                            lbuffer_datactrl_width_out = 3'b010;
                        end
                    endcase
                end
        end
    end
endmodule : lbuffer