module IF(
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    //from reorder buffer
    input rob_if_rst_in,
    input rob_if_pc_in,

    //from & to instqueue
    input instqueue_if_rdy_in,
    output if_instqueue_en_out,
    output wire[`IDWidth - 1 : 0] if_instqueue_inst_out,
    output wire [`AddressWidth - 1 : 0] if_instqueue_pc_out
);
//instruction fetch
//include an i-cache with

    localparam LineCount = 16;

    always @(posedge clk_in) begin
    end
endmodule : IF