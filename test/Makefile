# Tiny Tapeout / cocotb simulation makefile
TOPLEVEL_LANG = verilog
VERILOG_SOURCES = $(foreach f,$(PROJECT_SOURCES),$(PWD)/../src/$(f))
PROJECT_SOURCES = project.v top.v PicoPresent.v uart_rx.v uart_tx.v
TOPLEVEL = tt_um_zoomwag_picopresent
MODULE = test

COMPILE_ARGS += -g2012
SIM ?= icarus

include $(shell cocotb-config --makefiles)/Makefile.sim
