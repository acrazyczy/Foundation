`include "constant.vh"

module ram_controller
(
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    input wire inst_en_i,
    output reg inst_rdy_o,
    input wire[`AddressWidth - 1 : 0] inst_addr_i,
    output reg[`IDWidth - 1 : 0] inst_inst_o,

    input wire data_en_i,
    input wire data_rw_i,
    input wire [2 : 0] data_width_i,
    output reg data_rdy_o,
    input wire[`AddressWidth - 1 : 0] data_addr_i,
    input wire[`AddressWidth - 1 : 0] data_data_i,
    output reg[`IDWidth - 1 : 0] data_data_o,

    input wire [7 : 0] ram_i,
    output reg ram_rw_o,
    output reg [`AddressWidth - 1 : 0] ram_addr_o,
    output reg [7 : 0] ram_data_o
);

//guarantee that input remains unchanged before the whole data has been read from/written to memory
//at posedge: 1. handle data read from RAM; 2. switch the stage
//during clock cycle: notify change of stage and set RAM ready for next rw

    localparam IDLE = 3'b000;
    localparam S0 = 3'b001;
    localparam S1 = 3'b010;
    localparam S2 = 3'b011;
    localparam S3 = 3'b100;

    localparam NONE = 2'b00;
    localparam RINST = 2'b01;
    localparam RDATA = 2'b10;
    localparam WDATA = 2'b11;

    reg [3 : 0] current_stage;
    reg [2 : 0] current_rw_state;
    reg [`IDWidth - 1 : 0] data;

    always @(posedge clk) begin
        if (rst_in) begin
            inst_rdy_o <= 1'b0;
            data_rdy_o <= 1'b0;
        end else if (rdy_in) begin
            case (current_rw_state)
                NONE: begin
                    inst_rdy_o <= 1'b0;
                    data_rdy_o <= 1'b0;
                end
                RINST: begin
                    data_rdy_o <= 1'b0;
                    case (current_stage)
                        S0: begin
                            data[7 : 0] <= ram_i;
                            inst_rdy_o <= 1'b0;
                        end
                        S1: begin
                            data[15 : 8] <= ram_i;
                            inst_rdy_o <= 1'b0;
                        end
                        S2: begin
                            data[23 : 16] <= ram_i;
                            inst_rdy_o <= 1'b0;
                        end
                        S3: begin
                            inst_inst_o <= {ram_i, data[23 : 0]};
                            inst_rdy_o <= 1'b1;
                        end
                        default: begin
                            inst_rdy_o <= 1'b0;
                        end
                    endcase
                end
                RDATA: begin
                    inst_rdy_o <= 1'b0;
                    case (current_stage)
                        S0: begin
                            if (data_width_i == 3'b001) begin
                                data_data_o <= ram_i;
                                data_rdy_o <= 1'b1;
                            end else begin
                                data[7 : 0] <= ram_i;
                                data_rdy_o <= 1'b0;
                            end
                        end
                        S1: begin
                            if (data_width_i == 3'b010) begin
                                data_data_o <= {ram_i, data[7 : 0]};
                                data_rdy_o <= 1'b1;
                            end else begin
                                data[15 : 8] <= ram_i;
                                data_rdy_o <= 1'b0;
                            end
                        end
                        S2: begin
                            data[23 : 16] <= ram_i;
                            data_rdy_o <= 1'b0;
                        end
                        S3: begin
                            data_data_o <= {ram_i, data[23 : 0]};
                            data_rdy_o <= 1'b1;
                        end
                        default: data_rdy_o <= 1'b0;
                    endcase
                end
                WDATA: begin
                    inst_rdy_o <= 1'b0;
                    case (current_stage)
                        S0: if (data_width_i == 3'b001) data_rdy_o <= 1'b1;
                        S1: if (data_width_i == 3'b010) data_rdy_o <= 1'b1;
                        S3: data_rdy_o <= 1'b1;
                        default: data_rdy_o <= 1'b0;
                    endcase
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst_in) begin
            current_stage <= IDLE;
            current_rw_state <= NONE;
        end else if (rdy_in) begin
            case (current_stage)
                IDLE: begin
                    if (!inst_en_i && !data_en_i) begin
                        current_stage <= IDLE;
                        current_rw_state <= NONE;
                    end begin
                        current_stage <= S0;
                        if (inst_en_i) current_rw_state <= RINST;
                        else if (data_en_i && data_rw_i) current_rw_state <= RDATA;
                        else if (data_en_i && !data_rw_i) current_rw_stage <= WDATA;
                    end
                end
                S0: current_stage <= (current_rw_state == RDATA || current_rw_state == WDATA) && data_width_i == 3'b001 ? OK : S1;
                S1: current_stage <= (current_rw_state == RDATA || current_rw_state == WDATA) && data_width_i == 3'b010 ? OK : S2;
                S2: current_stage <= S3;
                S3: begin
                    current_stage <= IDLE;
                    current_rw_state <= NONE;
                end
            endcase
        end
    end

    always @(*) begin
        if (rst_in) begin
            ram_rw_o = 1'b0;
            ram_addr_o = {`AddressWidth{1'b0}};
            ram_data_o = {`IDWidth{1'b0}};
        end else if (rdy_in) case (current_stage)
            S0: case (current_rw_state)
                    RINST: begin
                        ram_rw_o = 1'b0;
                        ram_addr_o = inst_addr_i;
                        ram_data_o = 8'b0;
                    end
                    RDATA: begin
                        ram_rw_o = 1'b0;
                        ram_addr_o = data_addr_i;
                        ram_data_o = 8'b0;
                    end
                    WDATA: begin
                        ram_rw_o = 1'b1;
                        ram_addr_o = data_addr_i;
                        ram_data_o = data_data_i[7 : 0];
                    end
                endcase
            S1: case (current_rw_state)
                    RINST: begin
                        ram_rw_o = 1'b0;
                        ram_addr_o = inst_addr_i + 32'h1;
                        ram_data_o = 8'b0;
                    end
                    RDATA: begin
                        ram_rw_o = 1'b0;
                        ram_addr_o = data_addr_i + 32'h1;
                        ram_data_o = 8'b0;
                    end
                    WDATA: begin
                        ram_rw_o = 1'b1;
                        ram_addr_o = data_addr_i + 32'h1;
                        ram_data_o = data_data_i[15 : 8];
                    end
                endcase
            S2: case (current_rw_state)
                    RINST: begin
                        ram_rw_o = 1'b0;
                        ram_addr_o = inst_addr_i + 32'h2;
                        ram_data_o = 8'b0;
                    end
                    RDATA: begin
                        ram_rw_o = 1'b0;
                        ram_addr_o = data_addr_i + 32'h2;
                        ram_data_o = 8'b0;
                    end
                    WDATA: begin
                        ram_rw_o = 1'b1;
                        ram_addr_o = data_addr_i + 32'h2;
                        ram_data_o = data_data_i[23 : 16]
                    end
                endcase
            S3: case (current_rw_state)
                    RINST: begin
                        ram_rw_o = 1'b0;
                        ram_addr_o = inst_addr_i + 32'h3;
                        ram_data_o = 8'b0;
                    end
                    RDATA: begin
                        ram_rw_o = 1'b0;
                        ram_addr_o = data_addr_i + 32'h3;
                        ram_data_o = 8'b0;
                    end
                    WDATA: begin
                        ram_rw_o = 1'b0;
                        ram_addr_o = data_width_i + 32'h3;
                        ram_data_o = data_data_i[31 : 24];
                    end
                endcase
            IDLE: begin
                ram_rw_o = 1'b0;
                ram_addr_o = {`AddressWidth{1'b0}};
                ram_data_o = {`IDWidth{1'b0}};
            end
        endcase
    end

endmodule : ram_controller