import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge

CLOCK_PERIOD_NS = 20       # 50 MHz
UART_BIT_CYCLES = 25       # 2 Mbps at 50 MHz


async def uart_send_byte(dut, value):
    # UART 8-N-1, least-significant bit first.
    dut.ui_in.value = 0x00
    for _ in range(UART_BIT_CYCLES):
        await RisingEdge(dut.clk)
    for bit in range(8):
        dut.ui_in.value = (value >> bit) & 1
        for _ in range(UART_BIT_CYCLES):
            await RisingEdge(dut.clk)
    dut.ui_in.value = 1
    for _ in range(UART_BIT_CYCLES):
        await RisingEdge(dut.clk)


async def uart_receive_byte(dut, timeout_cycles=10000):
    # Wait for the falling edge of the UART start bit.
    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if int(dut.uo_out.value) & 1 == 0:
            break
    else:
        raise AssertionError("Timed out waiting for UART TX start bit")

    # Move to the centre of data bit 0: 1.5 bit periods from start edge.
    for _ in range(UART_BIT_CYCLES + UART_BIT_CYCLES // 2):
        await RisingEdge(dut.clk)

    value = 0
    for bit in range(8):
        value |= (int(dut.uo_out.value) & 1) << bit
        for _ in range(UART_BIT_CYCLES):
            await RisingEdge(dut.clk)
    return value


@cocotb.test()
async def present_zero_vector_over_uart(dut):
    dut.ui_in.value = 1
    dut.ena.value = 1
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    cocotb.start_soon(Clock(dut.clk, CLOCK_PERIOD_NS, unit="ns").start())
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for _ in range(5):
        await RisingEdge(dut.clk)

    # PRESENT-80 zero key (10 bytes) followed by zero plaintext (8 bytes).
    for byte in bytes(18):
        await uart_send_byte(dut, byte)

    result = bytearray()
    for _ in range(8):
        result.append(await uart_receive_byte(dut))

    expected = bytes.fromhex("5579C1387B228445")
    assert bytes(result) == expected, (
        f"Wrong ciphertext: got {bytes(result).hex().upper()}, "
        f"expected {expected.hex().upper()}"
    )
