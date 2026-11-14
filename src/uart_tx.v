
module uart_tx(
    input wire clk,
    input wire reset,
    input wire tx_start,
    input wire [7:0] data,

    output reg tx,
    output reg busy,
    output reg done
);

    parameter BIT_PERIOD = 868;

    reg [9:0] counter;
    reg [2:0] bit_index;
    reg [7:0] data_reg;

    reg [1:0] state;

    parameter IDLE  = 2'd0;
    parameter START = 2'd1;
    parameter DATA  = 2'd2;
    parameter STOP  = 2'd3;

    always @(posedge clk) begin

        if (reset) begin
            state <= IDLE;
            counter <= 0;
            bit_index <= 0;
            data_reg <= 0;

            tx <= 1'b1;
            busy <= 0;
            done <= 0;
        end

        else begin

            done <= 0;

            case (state)

                IDLE: begin
                    tx <= 1'b1;
                    busy <= 0;
                    counter <= 0;

                    if (tx_start) begin
                        data_reg <= data;
                        bit_index <= 0;

                        tx <= 1'b0;
                        busy <= 1'b1;
                        state <= START;
                    end
                end

                START: begin
                    if (counter == BIT_PERIOD - 1) begin
                        counter <= 0;
                        tx <= data_reg[0];
                        state <= DATA;
                    end
                    else begin
                        counter <= counter + 1'b1;
                    end
                end

                DATA: begin
                    if (counter == BIT_PERIOD - 1) begin
                        counter <= 0;

                        if (bit_index == 7) begin
                            tx <= 1'b1;
                            state <= STOP;
                        end
                        else begin
                            bit_index <= bit_index + 1'b1;
                            tx <= data_reg[bit_index + 1'b1];
                        end
                    end
                    else begin
                        counter <= counter + 1'b1;
                    end
                end

                STOP: begin
                    if (counter == BIT_PERIOD - 1) begin
                        counter <= 0;
                        busy <= 0;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                    else begin
                        counter <= counter + 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                    counter <= 0;
                    tx <= 1'b1;
                    busy <= 0;
                end

            endcase
        end
    end

endmodule
