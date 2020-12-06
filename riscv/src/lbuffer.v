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
    output wire[`ROBWidth - 1 : 0] lbuffer_rob_h_out,
    output wire[`IDWidth - 1 : 0] lbuffer_rob_value_out,
    output wire lbuffer_rob_en_out,
    output wire[`ROBWidth - 1 : 0] lbuffer_rob_rob_index_out,
    output wire[`LBWidth - 1 : 0] lbuffer_rob_lbuffer_index_out,
    input wire[`LBWidth - 1 : 0] rob_lbuffer_index_in,

    //to reservation station
    output wire lbuffer_rs_rdy_out,

    //from & to datactrl
    output wire lbuffer_datactrl_en_out,
    output wire[`AddressWidth - 1 : 0] lbuffer_datactrl_addr_out,
    output wire[2 : 0] lbuffer_datactrl_width_out,
    output wire lbuffer_datactrl_sgn_out,
    input wire datactrl_lbuffer_en_in,
    input wire[`IDWidth - 1 : 0] datactrl_lbuffer_data_in
);
//from 1 to LBCount - 1

    reg busy[`LBCount - 1 : 0];
    reg[`AddressWidth - 1 : 0] a[`LBCount - 1 : 0];
    reg[`ROBWidth - 1 : 0] dest[`LBCount - 1 : 0];
    reg[`InstTypeWidth - 1 : 0] opcode[`LBCount - 1 : 0];
    reg[`LBWidth - 1 : 0] idlelist_head;
    reg[`LBWidth - 1 : 0] idlelist_next[`LBCount - 1 : 0];
    reg[1 : 0] stage;
    reg[`LBWidth - 1 : 0] current_load_id, next_load_id;

    localparam IDLE = 2'b00;
    localparam PENDING = 2'b01;
    localparam BUSY = 2'b10;

//at posedge:
//activate the corresponding entry in ROB
//search for a ready-to-load entry and record to next_load_id
//execute loading (if IDLE && current_load_id != 0, set stage to PENDING; if BUSY && datactrl_lbuffer_en_in, set to IDLE, pop)
//receive ready entry from ROB
//addrunit sends an entry

//during clock cycle
//if stage is PENDING, link datactrl
//if stage is BUSY and datactrl_lbuffer_en_in, change idlelist_head
//if a new entry is sent, change idlelist_head

    always @(posedge clk_in) begin
        if (rst_in) begin
            for (i = 1;i < `LBCount;i = i + 1) busy[i] <= 1'b0;
            stage <= IDLE;
            current_load_id <= `LBWidth'b0;
        end else if (rdy_in) if (rob_lbuffer_rst_in) begin
            for (i = 1;i < `LBCount;i = i + 1) busy[i] <= 1'b0;
            stage <= IDLE;
            current_load_id <= `LBWidth'b0;
        end else begin
            next_load_id <= `LBWidth'b0;
            for (i = 1;i < `LBCount;i = i + 1)
                if (busy[i] && ready[i])
                    next_load_id <= i;
            if (stage == PENDING) stage <= BUSY;
            else if (stage == BUSY) begin
                if (datactrl_lbuffer_en_in) begin
                    stage <= IDLE;
                    current_load_id <= next_load_id;
                end
            end else if (current_load_id != `LBWidth'b0) begin
                busy[current_load_id] <= 1'b0;
                stage <= PENDING;
            end
            else current_load_id <= next_load_id;
            ready[rob_lbuffer_index_in] <= 1'b1;
            if (addrunit_lbuffer_en_in) begin
                busy[idlelist_head] <= 1'b1;
                a[idlelist_head] <= addrunit_lbuffer_a_in;
                dest[idlelist_head] <= addrunit_lbuffer_dest_in;
                opcode[idlelist_head] <= addrunit_lbuffer_opcode_in;
                ready[idlelist_head] <= 1'b0;
                lbuffer_rob_en_out <= 1'b1;
                lbuffer_rob_rob_index_out <= addrunit_lbuffer_dest_in;
                lbuffer_rob_lbuffer_index_out <= idlelist_head;
            end else lbuffer_rob_en_out <= 1'b0;
        end
    end

    always @(*) begin
        if (rst_in) begin
            lbuffer_datactrl_en_out = 1'b0;
            idlelist_head = `LBWidth'b0;
        end else if (rdy_in) if (rob_lbuffer_rst_in) begin
            lbuffer_datactrl_en_out = 1'b0;
            idlelist_head = `LBWidth'b0;
        end else begin
            if (busy[idlelist_head]) idlelist_head = idlelist_next[idlelist_head];
            if (stage == PENDING) begin
                    lbuffer_datactrl_en_out = 1'b1;
                    lbuffer_datactrl_addr_out = a[current_load_id];
                    case (opcode[current_load_id])
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
            end else if (stage == BUSY && datactrl_lbuffer_en_in) begin
                lbuffer_rob_dest_out = dest[current_load_id];
                lbuffer_rob_value_out = datactrl_lbuffer_data_in;
                lbuffer_datactrl_en_out = 1'b0;
                idlelist_next[current_load_id] = idlelist_head;
                idlelist_head = current_load_id;
            end
        end
    end

    assign lbuffer_rs_rdy_out = idlelist_head != `LBCount'b0;
endmodule : lbuffer