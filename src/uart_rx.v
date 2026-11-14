
module uart_rx(
    input wire clk,
    input wire reset,
    input wire rx,

    output reg [7:0] data,
    output reg data_valid
);

    parameter BIT_PERIOD = 868;

    reg [9:0] counter;
    reg [2:0] bit_index;
    reg [7:0] shift_reg;

    reg [1:0] state;

    parameter IDLE  = 2'd0;
    parameter START = 2'd1;
    parameter DATA  = 2'd2;
    parameter STOP  = 2'd3;

    reg rx_sync1;
    reg rx_sync2;

    // Synchronise incoming serial data
    always @(posedge clk) begin
        if (reset) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end
        else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    // UART receiver state machine
    always @(posedge clk) begin

        if (reset) begin
            state <= IDLE;
            counter <= 0;
            bit_index <= 0;
            shift_reg <= 0;
            data <= 0;
            data_valid <= 0;
        end

        else begin

            data_valid <= 0;

            case (state)

                IDLE: begin
                    if (rx_sync2 == 1'b0) begin
                        state <= START;
                        counter <= 0;
                    end
                end

                START: begin
                    if (counter == (BIT_PERIOD / 2) - 1) begin
                        counter <= 0;

                        if (rx_sync2 == 1'b0) begin
                            state <= DATA;
                            bit_index <= 0;
                        end
                        else begin
                            state <= IDLE;
                        end
                    end
                    else begin
                        counter <= counter + 1'b1;
                    end
                end

                DATA: begin
                    if (counter == BIT_PERIOD - 1) begin
                        counter <= 0;
                        shift_reg[bit_index] <= rx_sync2;

                        if (bit_index == 7)
                            state <= STOP;
                        else
                            bit_index <= bit_index + 1'b1;
                    end
                    else begin
                        counter <= counter + 1'b1;
                    end
                end

                STOP: begin
                    if (counter == BIT_PERIOD - 1) begin
                        counter <= 0;

                        if (rx_sync2 == 1'b1) begin
                            data <= shift_reg;
                            data_valid <= 1'b1;
                        end

                        state <= IDLE;
                    end
                    else begin
                        counter <= counter + 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                    counter <= 0;
                end

            endcase
        end
    end

endmodule
