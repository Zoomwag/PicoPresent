// Tiny Tapeout wrapper for PicoPresent.
// Original cipher, UART receiver, UART transmitter and controller are
// instantiated without modifying their source files.

module tt_um_zoomwag_picopresent (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ena,
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe
);

    wire uart_tx;
    wire reset;

    // Tiny Tapeout reset is active-low; the original design uses active-high.
    assign reset = ~rst_n;

    // ui_in[0] is UART RX; uo_out[0] is UART TX.
    // At the Tiny Tapeout 50 MHz clock, 25 cycles per UART bit = 2 Mbps.
    top #(
        .BIT_PERIOD(25)
    ) picopresent_top (
        .clk(clk),
        .reset(reset),
        .uart_rx_i(ui_in[0]),
        .uart_tx_o(uart_tx)
    );

    assign uo_out = {7'b0000000, uart_tx};

    // No bidirectional pins are used.
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    // ena and uio_in are intentionally unused by this UART-only interface.
    wire unused_signals = ena ^ ^uio_in;

endmodule
