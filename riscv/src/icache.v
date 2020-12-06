`include "contant.vh"

module icache(
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    //from & to instruction fetch
    input wire if_icache_en_in,
    input wire if_icache_inst_addr_in,
    output wire icache_if_miss_out,
    output wire[`IDWidth - 1 : 0] icache_if_inst_inst_out,

    //from & to ramctrl
    output wire icache_ramctrl_en_out,
    input wire ramctrl_icache_inst_rdy_in,
    output wire[`AddressWidth - 1 : 0] icache_ramctrl_addr_out,
    input wire[`IDWidth - 1 : 0] ramctrl_icache_inst_inst_in
);
//1 KiB i-cache

    localparam IndexWidth = 8;
    localparam IndexCount = 256;
    localparam TagWidth = 22;
    localparam TagCount = 
    localparam ByteSelectWidth = 2;
    localparam ByteSelectCount = 4;
    localparam BlockWidth = ;
    localparam IDLE = 1'b0;
    localparam BUSY = 1'b1;

    reg[TagWidth - 1 : 0] tag[IndexCount - 1 : 0];
    reg[BlockWidth - 1 : 0] value[IndexCount - 1 : 0];
    reg valid[IndexCount - 1 : 0];
    reg state;
    wire real_miss;

    always @(posedge clk_in) begin
        if (rst_in) begin
            state = IDLE;
            for (i = 0;i < IndexCount;i = i + 1) valid[i] = 
        end else if (rdy_in) begin
            if (state == IDLE && icache_ramctrl_en_in) state = BUSY;
            else if (state == BUSY && ramctrl_icache_inst_rdy_in) begin
                state = IDLE;
                tag[(icache_ramctrl_addr_in >> ByteSelectWidth) & (1 << IndexWidth) - 1] <= if_icache_inst_addr_in >> IndexWidth + ByteSelectWidth;
                valid[(if_icache_inst_addr_in >> ByteSelectWidth) & (1 << IndexWidth) - 1] <= 1'b1;
                value[(if_icache_inst_addr_in >> ByteSelectWidth) & (1 << IndexWidth) - 1] <= ramctrl_icache_inst_inst_in;
            end
        end
    end

    assign real_miss = !valid[(if_icache_inst_addr_in >> ByteSelectWidth) & (1 << IndexWidth) - 1] || tag[(if_icache_inst_addr_in >> ByteSelectWidth) & (1 << IndexWidth) - 1] != if_icache_inst_addr_in >> IndexWidth + ByteSelectWidth;
    assign icache_if_miss_out = state == BUSY || real_miss;
    assign icache_if_inst_inst_out = value[(if_icache_inst_addr_in >> ByteSelectWidth) & (1 << IndexWidth) - 1];
    assign icache_ramctrl_en_in = state == BUSY || real_miss;
    assign icache_ramctrl_addr_in = state == BUSY ? icache_ramctrl_en_in: if_icache_inst_addr_in;

endmodule : icache