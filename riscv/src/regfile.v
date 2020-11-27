`include "constant.vh"

module regfile(
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    //from & to dispatcher
    input wire[`RegWidth - 1 : 0] dispatcher_regfile_rs_in,
    output wire regfile_dispatcher_rs_busy_out,
    output wire[`IDWidth - 1 : 0] regfile_dispatcher_rs_out,
    output wire[`ROBWidth - 1 : 0] regfile_dispatcher_rs_reorder_out,
    input wire[`RegWidth - 1 : 0] dispatcher_regfile_rt_in,
    output wire regfile_dispatcher_rt_busy_out,
    output wire[`IDWidth - 1 : 0] regfile_dispatcher_rt_out,
    output wire[`ROBWidth - 1 : 0] regfile_dispatcher_rt_reorder_out,
    input wire dispatcher_regfile_rd_en_in,
    input wire[`RegWidth - 1 : 0] dispatcher_regfile_rd_in,
    input wire dispatcher_regfile_reorder_in,
);
    reg[`IDWidth - 1 : 0] register[`RegCount - 1 : 0];
    reg busy[`RegCount - 1 : 0];
    reg[`ROBWidth - 1 : 0] reorder[`RegCount - 1 : 0];

    always @(posedge clk_in) begin
        if (rst_in) begin
            for (i = 0;i < RegCount;++ i) begin
                register[i] <= `IDWidth'b0;
                busy[i] <= 1'b0;
            end
        end else if (rdy_in) begin
            if (dispatcher_regfile_rd_en_in) begin
                busy[dispatcher_regfile_rd_in] <= 1'b1;
                reorder[dispatcher_regfile_rd_in] <= dispatcher_regfile_reorder_in;
            end
        end
    end

    always @(*) begin
        if (rst_in) begin
            for (i = 0;i < RegCount;++ i) begin
                register[i] = `IDWidth'b0;
                busy[i] = 1'b0;
            end
        end else if (rdy_in) begin
            regfile_dispatcher_rs_busy_out = busy[dispatcher_regfile_rs_in];
            regfile_dispatcher_rs_out = register[dispatcher_regfile_rs_in];
            regfile_dispatcher_rs_reorder_out = reorder[dispatcher_regfile_rs_in];
            regfile_dispatcher_rt_busy_out = busy[dispathcer_regfile_rt_in];
            regfile_dispathcer_rt_out = regsiter[dispather_regfile_rt_in];
            regfile_dispathcer_rt_reorder_out = reorder[dispatcher_regfile_rt_in];
        end
    end

endmodule : regfile