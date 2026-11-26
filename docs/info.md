<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

PicoPresent uses the PRESENT-80 encryption algorithm directly baked into the  hardware. It takes a 64-bit plaintext and an 80-bit encryption key, processes them through 31 rounds of substitution, permutation and key mixing, and produces a 64-bit ciphertext.

## How to test

A Python script running on a computer sends plaintext and encryption keys to the chip over UART. It then receives the ciphertext and compares it against the expected result to verify that the hardware is working correctly.

## External hardware
A UART interface is needed to let the asic talk to the computer, using a USB-to-UART adapter or microcontroller.
