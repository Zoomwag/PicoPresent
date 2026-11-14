import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ReadOnly

# These values must match src/project.v:
# 50 MHz clock / 25 clocks per UART bit = 2,000,000 baud.
CLOCK_PERIOD_NS = 20
UART_BIT_CYCLES = 25
UART_TIMEOUT_CYCLES = 20_000

# PRESENT S-box, as defined by the PRESENT specification.
SBOX = (
    0xC, 0x5, 0x6, 0xB,
    0x9, 0x0, 0xA, 0xD,
    0x3, 0xE, 0xF, 0x8,
    0x4, 0x7, 0x1, 0x2,
)

MASK_64 = (1 << 64) - 1
MASK_80 = (1 << 80) - 1


def present80_encrypt(key: int, plaintext: int) -> int:
    """
    Independent, bit-accurate PRESENT-80 reference model.

    This is deliberately written in Python rather than copied from the RTL,
    so the testbench can compare the chip against a separate implementation.
    """
    state = plaintext & MASK_64
    key_reg = key & MASK_80

    # 31 full rounds. The 32nd round key is used for the final XOR.
    for round_number in range(1, 32):
        # AddRoundKey: use the upper 64 bits of the 80-bit key.
        state ^= (key_reg >> 16) & MASK_64

        # Substitute all 16 nibbles.
        substituted = 0
        for nibble_index in range(16):
            nibble = (state >> (4 * nibble_index)) & 0xF
            substituted |= SBOX[nibble] << (4 * nibble_index)
        state = substituted

        # PRESENT pLayer: bit i moves to bit (16*i) mod 63.
        permuted = 0
        for bit_index in range(63):
            bit = (state >> bit_index) & 1
            permuted |= bit << ((16 * bit_index) % 63)
        permuted |= ((state >> 63) & 1) << 63
        state = permuted

        # PRESENT-80 key schedule:
        # rotate left by 61, S-box the most-significant nibble,
        # then XOR the round number into key bits 19..15.
        key_reg = ((key_reg << 61) | (key_reg >> 19)) & MASK_80
        top_nibble = (key_reg >> 76) & 0xF
        key_reg = (key_reg & ((1 << 76) - 1)) | (SBOX[top_nibble] << 76)
        key_reg ^= round_number << 15

    # Final whitening with round key K32.
    state ^= (key_reg >> 16) & MASK_64
    return state & MASK_64


async def wait_clocks(dut, count: int):
    for _ in range(count):
        await RisingEdge(dut.clk)


async def reset_chip(dut):
    """Apply the active-low Tiny Tapeout reset."""
    dut.ui_in.value = 0x01  # UART RX idle high
    dut.uio_in.value = 0
    dut.ena.value = 1
    dut.rst_n.value = 0

    await wait_clocks(dut, 6)
    dut.rst_n.value = 1
    await wait_clocks(dut, 6)


async def uart_send_byte(dut, value: int):
    """Send one 8-N-1 UART byte, LSB first, at the configured baud rate."""
    frame = [0]  # start bit
    frame.extend((value >> bit) & 1 for bit in range(8))
    frame.append(1)  # stop bit

    for bit_value in frame:
        # Change the serial input away from the active sampling edge.
        await FallingEdge(dut.clk)
        dut.ui_in.value = bit_value
        await wait_clocks(dut, UART_BIT_CYCLES)


async def uart_send_bytes(dut, data: bytes):
    for value in data:
        await uart_send_byte(dut, value)


async def uart_receive_byte(dut, timeout_cycles=UART_TIMEOUT_CYCLES) -> int:
    """Wait for a TX start bit and sample one UART byte, LSB first."""
    # Wait for the falling edge of the TX line. Polling also gives us a
    # bounded timeout and avoids relying on simulator-specific edge handles.
    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if (int(dut.uo_out.value) & 1) == 0:
            break
    else:
        raise AssertionError("Timed out waiting for UART TX start bit")

    # We detected the start bit close to its beginning. Sample near the
    # centre of data bit 0 (1.5 bit periods after the start edge).
    await wait_clocks(dut, UART_BIT_CYCLES + UART_BIT_CYCLES // 2)
    await ReadOnly()

    value = 0
    for bit_index in range(8):
        value |= (int(dut.uo_out.value) & 1) << bit_index
        if bit_index != 7:
            await wait_clocks(dut, UART_BIT_CYCLES)
            await ReadOnly()

    return value


async def send_present_transaction(dut, key: int, plaintext: int) -> int:
    """
    Send 10 key bytes followed by 8 plaintext bytes.
    Receive and return the 8-byte ciphertext.
    All multi-byte values are sent most-significant byte first.
    """
    frame = key.to_bytes(10, byteorder="big")
    frame += plaintext.to_bytes(8, byteorder="big")

    await uart_send_bytes(dut, frame)

    ciphertext = bytearray()
    for _ in range(8):
        ciphertext.append(await uart_receive_byte(dut))

    return int.from_bytes(ciphertext, byteorder="big")


@cocotb.test()
async def full_present80_uart_stress_test(dut):
    """
    End-to-end test of the Tiny Tapeout chip interface.

    Covers:
      * reset and UART idle behaviour
      * the published PRESENT-80 zero vector
      * walking-bit and alternating-bit patterns
      * all-zero/all-one and mixed key/plaintext patterns
      * deterministic pseudo-random key/plaintext pairs
      * consecutive encryptions without resetting the chip
      * exact UART byte order and ciphertext comparison
    """
    cocotb.start_soon(
        Clock(dut.clk, CLOCK_PERIOD_NS, unit="ns").start()
    )
    await reset_chip(dut)

    # The TX line must idle high after reset.
    await wait_clocks(dut, 5)
    assert (int(dut.uo_out.value) & 1) == 1, "UART TX is not idle-high"

    vectors = [
        # Published PRESENT-80 known-answer vector.
        (0x00000000000000000000, 0x0000000000000000),

        # Extremes and alternating patterns.
        (0x00000000000000000000, 0xFFFFFFFFFFFFFFFF),
        (0xFFFFFFFFFFFFFFFFFFFF, 0x0000000000000000),
        (0xFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF),
        (0xAAAAAAAAAAAAAAAAAAAA, 0xAAAAAAAAAAAAAAAA),
        (0x55555555555555555555, 0x5555555555555555),
        (0x0123456789ABCDEFFEDC, 0x0123456789ABCDEF),
        (0xFEDCBA98765432100123, 0xFEDCBA9876543210),

        # Walking one-bit patterns across key and plaintext boundaries.
        (1 << 79, 1 << 63),
        (1 << 40, 1 << 31),
        (1, 1),
        (1 << 78, 1 << 62),
        (1 << 32, 1 << 16),
        (1 << 16, 1 << 32),
    ]

