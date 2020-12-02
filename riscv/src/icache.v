`include "constant.vh"

module icache(
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    //from & to instruction fetch
    input wire if_icache_en_in,
    input wire if_icache_inst_addr_in,
    output wire icache_if_rdy_out,
    output wire icache_if_miss_out,
    output wire[`IDWidth - 1 : 0] icache_if_inst_inst_out,

    //from & to ramctrl
    output wire icache_ramctrl_en_i,
    input wire ramctrl_icache_inst_rdy_o,
    output wire[`AddressWidth - 1 : 0] icache_ramctrl_addr_i,
    input wire[`IDWidth - 1 : 0] ramctrl_icache_inst_inst_o
);
//1 KiB i-cache

    localparam IndexWidth = 8;
    localparam IndexCount = 256;
    localparam ByteSelectWidth = 2;
    localparam ByteSelectCount = 4;
    localparam TagWidth = `IDWidth - IndexWidth - ByteSelectWidth;
    localparam EntryWidth = TagWidth + 8 * ByteSelectCount;

    reg[EntryWidth - 1 : 0] cache[IndexCount - 1 : 0];
    reg valid[IndexCount - 1 : 0];
    reg state;

    always @(*) begin
        if (rst_in) begin
            icache_if_rdy_out = 1'b1;
            icache_ramctrl_en_i = 1'b0;
            for (i = 0;i < IndexCount;i = i + 1) begin
                cache[i] = 0;
                valid[i] = 1'b0;
            end
            state = 1'b0;
        end else if (rdy_in) begin
            if (state) begin
                if (ramctrl_icache_inst_rdy_o) begin
                    state = 1'b0;
                    icache_if_rdy_out = 1'b1;
                    valid[(if_icache_inst_addr_in >> ByteSelectWidth) & (IndexCount - 1)] = 1'b1;
                    cache[(if_icache_inst_addr_in >> ByteSelectWidth) & (IndexCount - 1)] = {if_icache_inst_addr_in >> (`IDWidth - TagWidth), ramctrl_icache_inst_inst_o};
                end
            end
            if (if_icache_en_in) begin
                if (valid[(if_icache_inst_addr_in >> ByteSelectWidth) & (IndexCount - 1)] && (cache[(if_icache_inst_addr_in >> ByteSelectWidth) & (IndexCount - 1)] >> (EntryWidth - TagWidth)) == (if_icache_inst_addr_in >> (`IDWidth - TagWidth))) begin
                    icache_if_miss_out = 1'b0;
                    icache_if_inst_inst_out = cache[(if_icache_inst_addr_in >> ByteSelectWidth) & (IndexCount - 1)] & ((1 << (EntryWidth - TagWidth)) - 1);
                end else begin
                    icache_if_miss_out = 1'b1;
                    if (!state) begin
                        state = 1'b1;
                        icache_if_rdy_out = 1'b0;
                        icache_ramctrl_en_i = 1'b1;
                        icache_ramctrl_addr_i = if_icache_inst_addr_in;
                    end
                end
            end
        end
    end
endmodule : icache