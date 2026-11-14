
module top(
    input wire clk,
    input wire reset,

    input wire uart_rx_i,
    output wire uart_tx_o
);

    // UART timing: 100 MHz clock, 115200 baud
    parameter BIT_PERIOD = 868;

    // UART receiver
    wire [7:0] received_data;
    wire data_valid;

    // UART transmitter
    reg [7:0] tx_data;
    reg tx_start;
    wire tx_busy;
    wire tx_done;

    // PRESENT inputs and outputs
    reg [79:0] key_register;
    reg [63:0] plaintext_register;

    wire [63:0] cipher_result;
    wire [5:0] cipher_round;
    wire cipher_done;

    reg cipher_start;

    // Controller registers
    reg [4:0] rx_count;
    reg [3:0] tx_count;

    reg [63:0] cipher_shift;

    reg [2:0] state;

    parameter RX_INPUT     = 3'd0;
    parameter START_CIPHER = 3'd1;
    parameter WAIT_CIPHER  = 3'd2;
    parameter START_TX     = 3'd3;
    parameter WAIT_TX      = 3'd4;


    // ==========================================
    // UART RECEIVER
    // ==========================================

    uart_rx #(
        .BIT_PERIOD(BIT_PERIOD)
    ) receiver (
        .clk(clk),
        .reset(reset),
        .rx(uart_rx_i),
        .data(received_data),
        .data_valid(data_valid)
    );


    // ==========================================
    // UART TRANSMITTER
    // ==========================================

    uart_tx #(
        .BIT_PERIOD(BIT_PERIOD)
    ) transmitter (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .data(tx_data),
        .tx(uart_tx_o),
        .busy(tx_busy),
        .done(tx_done)
    );


    // ==========================================
    // PRESENT-80 ENCRYPTION CORE
    // ==========================================

    cypher cipher_core (
        .clk(clk),
        .reset(reset),
        .start(cipher_start),
        .current_key(key_register),
        .current_text(plaintext_register),
        .cypher_text(cipher_result),
        .current_round(cipher_round),
        .done(cipher_done)
    );


    // ==========================================
    // MAIN CONTROLLER
    // ==========================================

    always @(posedge clk) begin

        if (reset) begin

            state <= RX_INPUT;

            rx_count <= 0;
            tx_count <= 0;

            key_register <= 0;
            plaintext_register <= 0;
            cipher_shift <= 0;

            tx_data <= 0;
            tx_start <= 0;
            cipher_start <= 0;

        end

        else begin

            // Default: clear start pulses
            tx_start <= 0;
            cipher_start <= 0;

            case (state)


                // ----------------------------------
                // RECEIVE 10 KEY BYTES + 8 TEXT BYTES
                // ----------------------------------

                RX_INPUT: begin

                    if (data_valid) begin

                        // First 10 bytes form the key
                        if (rx_count < 10) begin

                            key_register <= {
                                key_register[71:0],
                                received_data
                            };

                        end

                        // Remaining 8 bytes form plaintext
                        else begin

                            plaintext_register <= {
                                plaintext_register[55:0],
                                received_data
                            };

                        end

                        if (rx_count == 17) begin

                            rx_count <= 0;
                            state <= START_CIPHER;

                        end

                        else begin

                            rx_count <= rx_count + 1'b1;

                        end

                    end

                end


                // ----------------------------------
                // START ENCRYPTION
                // ----------------------------------

                START_CIPHER: begin

                    cipher_start <= 1'b1;
                    state <= WAIT_CIPHER;

                end


                // ----------------------------------
                // WAIT FOR ENCRYPTION
                // ----------------------------------

                WAIT_CIPHER: begin

                    if (cipher_done) begin

                        cipher_shift <= cipher_result;
                        tx_count <= 0;

                        state <= START_TX;

                    end

                end


                // ----------------------------------
                // SEND NEXT CIPHERTEXT BYTE
                // ----------------------------------

                START_TX: begin

                    tx_data <= cipher_shift[63:56];
                    tx_start <= 1'b1;

                    state <= WAIT_TX;

                end


                // ----------------------------------
                // WAIT FOR UART TRANSMISSION
                // ----------------------------------

                WAIT_TX: begin

                    if (tx_done && !tx_busy) begin

                        // Shift to the next ciphertext byte
                        cipher_shift <= {
                            cipher_shift[55:0],
                            8'h00
                        };

                        if (tx_count == 7) begin

                            tx_count <= 0;
                            state <= RX_INPUT;

                        end

                        else begin

                            tx_count <= tx_count + 1'b1;
                            state <= START_TX;

                        end

                    end

                end


                // ----------------------------------
                // INVALID STATE RECOVERY
                // ----------------------------------

                default: begin

                    state <= RX_INPUT;
                    rx_count <= 0;
                    tx_count <= 0;

                end

            endcase

        end

    end

endmodule
