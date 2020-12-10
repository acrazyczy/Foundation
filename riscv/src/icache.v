`include "constant.vh"

module icache(
	input wire clk_in,
	input wire rst_in,
	input wire rdy_in,

	//from & to instruction fetch
	input wire[`AddressWidth - 1 : 0] if_icache_inst_addr_in,
	output wire icache_if_miss_out,
	output wire[`IDWidth - 1 : 0] icache_if_inst_inst_out,

	//from & to ramctrl
	output reg icache_ramctrl_en_out,
	input wire ramctrl_icache_inst_rdy_in,
	output reg[`AddressWidth - 1 : 0] icache_ramctrl_addr_out,
	input wire[`IDWidth - 1 : 0] ramctrl_icache_inst_inst_in
);
//1 KiB i-cache

	localparam IndexWidth = 8;
	localparam IndexCount = 256;
	localparam TagWidth = 22;
	localparam ByteSelectWidth = 2;
	localparam ByteSelectCount = 4;
	localparam BlockWidth = 32;
	localparam IDLE = 1'b0;
	localparam BUSY = 1'b1;

	reg[TagWidth - 1 : 0] tag[IndexCount - 1 : 0];
	reg[BlockWidth - 1 : 0] value[IndexCount - 1 : 0];
	reg valid[IndexCount - 1 : 0];
	reg state;
	wire miss;
	reg[`AddressWidth - 1 : 0] current_load;
	integer i;

	always @(posedge clk_in) begin
		if (rst_in) begin
			state <= IDLE;
			icache_ramctrl_en_out <= 1'b0;
			for (i = 0;i < IndexCount;i = i + 1) valid[i] <= 1'b0;
		end else if (rdy_in) begin
			if (state == BUSY && ramctrl_icache_inst_rdy_in) begin
				state <= IDLE;
				tag[(icache_ramctrl_addr_out >> ByteSelectWidth) & (1 << IndexWidth) - 1] <= if_icache_inst_addr_in >> IndexWidth + ByteSelectWidth;
				valid[(if_icache_inst_addr_in >> ByteSelectWidth) & (1 << IndexWidth) - 1] <= 1'b1;
				value[(if_icache_inst_addr_in >> ByteSelectWidth) & (1 << IndexWidth) - 1] <= ramctrl_icache_inst_inst_in;
				icache_ramctrl_en_out <= 1'b0;
			end
			if (miss && (state == IDLE || state == BUSY && ramctrl_icache_inst_rdy_in)) begin
				state <= BUSY;
				icache_ramctrl_en_out <= 1'b1;
				icache_ramctrl_addr_out <= if_icache_inst_addr_in;
			end
		end
	end

	assign miss = !valid[(if_icache_inst_addr_in >> ByteSelectWidth) & (1 << IndexWidth) - 1] || tag[(if_icache_inst_addr_in >> ByteSelectWidth) & (1 << IndexWidth) - 1] != (if_icache_inst_addr_in >> IndexWidth + ByteSelectWidth);
	assign icache_if_miss_out = state == BUSY || miss;
	assign icache_if_inst_inst_out = value[(if_icache_inst_addr_in >> ByteSelectWidth) & (1 << IndexWidth) - 1];

endmodule : icache