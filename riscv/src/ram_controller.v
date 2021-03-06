`include "constant.vh"

module ram_controller(
	input wire clk_in,
	input wire rst_in,
	input wire rdy_in,

	input wire inst_en_in,
	output reg inst_rdy_out,
	input wire[`AddressWidth - 1 : 0] inst_addr_in,
	output reg[`IDWidth - 1 : 0] inst_inst_out,

	input wire data_en_in,
	input wire data_rw_in,
	input wire data_sgn_in,
	input wire [2 : 0] data_width_in,
	output reg data_rdy_out,
	input wire[`AddressWidth - 1 : 0] data_addr_in,
	input wire[`IDWidth - 1 : 0] data_data_in,
	output reg[`IDWidth - 1 : 0] data_data_out,

	input wire [7 : 0] ram_in,
	output reg ram_rw_out,
	output reg [`AddressWidth - 1 : 0] ram_addr_out,
	output reg [7 : 0] ram_data_out
);

//guarantee that input remains unchanged before the whole data has been read from/written to memory
//at posedge: 1. handle data read from RAM; 2. switch the stage
//during clock cycle: notify change of stage and set RAM ready for next rw

	localparam IDLE = 3'b000;
	localparam S0 = 3'b001;
	localparam S1 = 3'b010;
	localparam S2 = 3'b011;
	localparam S3 = 3'b100;
	localparam OK1 = 3'b101;
	localparam OK2 = 3'b110;

	localparam NONE = 2'b00;
	localparam RINST = 2'b01;
	localparam RDATA = 2'b10;
	localparam WDATA = 2'b11;

	reg [3 : 0] current_stage;
	reg [2 : 0] current_rw_state;
	reg [`IDWidth - 1 : 0] data;
	// integer counter;

	always @(posedge clk_in) begin
		if (rst_in) begin
			// counter <= 0;
			inst_rdy_out <= 1'b0;
			data_rdy_out <= 1'b0;
		end else if (rdy_in) begin
			// counter <= counter + 1;
			case (current_rw_state)
				NONE: begin
					inst_rdy_out <= 1'b0;
					data_rdy_out <= 1'b0;
				end
				RINST: begin
					data_rdy_out <= 1'b0;
					case (current_stage)
						S0: inst_rdy_out <= 1'b0;
						S1: begin
							data[7 : 0] <= ram_in;
							inst_rdy_out <= 1'b0;
						end
						S2: begin
							data[15 : 8] <= ram_in;
							inst_rdy_out <= 1'b0;
						end
						S3: begin
							data[23 : 16] <= ram_in;
							inst_rdy_out <= 1'b0;
						end
						OK1: begin
							inst_inst_out <= {ram_in, data[23 : 0]};
							inst_rdy_out <= 1'b1;
						end
						default: begin
							inst_rdy_out <= 1'b0;
						end
					endcase
				end
				RDATA: begin
					inst_rdy_out <= 1'b0;
					case (current_stage)
						S0: data_rdy_out <= 1'b0;
						S1: begin
							if (data_width_in == 3'b001) begin
								if (data_sgn_in) data_data_out <= $signed(ram_in);
								else data_data_out <= ram_in;
								data_rdy_out <= 1'b1;
							end else begin
								data[7 : 0] <= ram_in;
								data_rdy_out <= 1'b0;
							end
						end
						S2: begin
							if (data_width_in == 3'b010) begin
								if (data_sgn_in) data_data_out <= {ram_in, data[7 : 0]};
								else data_data_out <= $signed({ram_in, data[7 : 0]});
								data_rdy_out <= 1'b1;
							end else begin
								data[15 : 8] <= ram_in;
								data_rdy_out <= 1'b0;
							end
						end
						S3: begin
							data[23 : 16] <= ram_in;
							data_rdy_out <= 1'b0;
						end
						OK1: begin
							data_data_out <= {ram_in, data[23 : 0]};
							data_rdy_out <= 1'b1;
						end
						default: data_rdy_out <= 1'b0;
					endcase
				end
				WDATA: begin
					inst_rdy_out <= 1'b0;
					data_rdy_out <= current_stage == OK1 ? 1'b1 : 1'b0;
				end
			endcase
		end
	end

	always @(posedge clk_in) begin
		if (rst_in) begin
			current_stage <= IDLE;
			current_rw_state <= NONE;
		end else if (rdy_in) begin
			case (current_stage)
				IDLE: begin
					if (!inst_en_in && !data_en_in) begin
						current_stage <= IDLE;
						current_rw_state <= NONE;
					end else begin
						current_stage <= S0;
						if (data_en_in && !data_rw_in) current_rw_state <= RDATA;
						else if (data_en_in && data_rw_in) current_rw_state <= WDATA;
						else current_rw_state <= RINST;
					end
				end
				S0: current_stage <= current_rw_state == WDATA && data_width_in == 3'b001 ? OK1 : S1;
				S1: current_stage <= current_rw_state == WDATA && data_width_in == 3'b010 ? OK1 : (current_rw_state == RDATA && data_width_in == 3'b001 ? OK2 : S2);
				S2: current_stage <= current_rw_state == RDATA && data_width_in == 3'b010 ? OK2 : S3;
				S3: current_stage <= OK1;
				OK1: current_stage <= OK2;
				OK2: begin
					current_stage <= IDLE;
					current_rw_state <= NONE;
				end
			endcase
		end
	end

	always @(*) begin
		ram_rw_out = 1'b0;
		ram_addr_out = {`AddressWidth{1'b0}};
		ram_data_out = {`IDWidth{1'b0}};
		if (!rst_in) case (current_stage)
			S0: case (current_rw_state)
					RINST: begin
						ram_rw_out = 1'b0;
						ram_addr_out = inst_addr_in;
						ram_data_out = 8'b0;
					end
					RDATA: begin
						ram_rw_out = 1'b0;
						ram_addr_out = data_addr_in;
						ram_data_out = 8'b0;
					end
					WDATA: begin
						ram_rw_out = 1'b1;
						ram_addr_out = data_addr_in;
						ram_data_out = data_data_in[7 : 0];
						// $display("%x: write %x to %x\n", counter, data_data_in[7 : 0], data_addr_in);
					end
				endcase
			S1: case (current_rw_state)
					RINST: begin
						ram_rw_out = 1'b0;
						ram_addr_out = inst_addr_in + 32'h1;
						ram_data_out = 8'b0;
					end
					RDATA: begin
						ram_rw_out = 1'b0;
						ram_addr_out = data_addr_in + 32'h1;
						ram_data_out = 8'b0;
					end
					WDATA: begin
						ram_rw_out = 1'b1;
						ram_addr_out = data_addr_in + 32'h1;
						ram_data_out = data_data_in[15 : 8];
						// $display("%x: write %x to %x\n", counter, data_data_in[15 : 8], data_addr_in + 32'h1);
					end
				endcase
			S2: case (current_rw_state)
					RINST: begin
						ram_rw_out = 1'b0;
						ram_addr_out = inst_addr_in + 32'h2;
						ram_data_out = 8'b0;
					end
					RDATA: begin
						ram_rw_out = 1'b0;
						ram_addr_out = data_addr_in + 32'h2;
						ram_data_out = 8'b0;
					end
					WDATA: begin
						ram_rw_out = 1'b1;
						ram_addr_out = data_addr_in + 32'h2;
						ram_data_out = data_data_in[23 : 16];
						// $display("%x: write %x to %x\n", counter, data_data_in[23 : 16], data_addr_in + 32'h2);
					end
				endcase
			S3: case (current_rw_state)
					RINST: begin
						ram_rw_out = 1'b0;
						ram_addr_out = inst_addr_in + 32'h3;
						ram_data_out = 8'b0;
					end
					RDATA: begin
						ram_rw_out = 1'b0;
						ram_addr_out = data_addr_in + 32'h3;
						ram_data_out = 8'b0;
					end
					WDATA: begin
						ram_rw_out = 1'b1;
						ram_addr_out = data_addr_in + 32'h3;
						ram_data_out = data_data_in[31 : 24];
						// $display("%x: write %x to %x\n", counter, data_data_in[31 : 24], data_addr_in + 32'h3);
					end
				endcase
		endcase
	end

endmodule : ram_controller