# Shared build system for Tang Nano 9K projects.
# Define project overrides BEFORE including this file.
# SRC must list files in compilation order, packages first.
# Create a local Makefile with 'include tangnano9k.mk' at the bottom
# then overwrite defaults, TOP, SRC etc.
#
# After that the commands here are available. 

.DEFAULT_GOAL := all
.DELETE_ON_ERROR:

# Project defaults
TOP      ?= top
SRC      ?= $(TOP).vhdl
CST      ?= constraint.cst
STD      ?= 19
BUILD    ?= build

# Simulation defaults
TB       ?= tb_$(TOP)
TB_SRC   ?= $(TB).vhdl
SIM_TIME ?= 10us

# Board defaults
DEVICE   ?= GW1NR-LV9QN88PC6/I5
FAMILY   ?= GW1N-9C
BOARD    ?= tangnano9k
FREQ     ?= 27

# Keep outputs and simulation separate.
OUT       := $(BUILD)/$(TOP)
SYNTH_DIR := $(OUT)/synth
SIM_DIR   := $(OUT)/sim

VERILOG   := $(OUT)/$(TOP).v
NETLIST   := $(OUT)/$(TOP).json
ROUTED    := $(OUT)/routed.json
BITSTREAM := $(OUT)/$(TOP).fs
REPORT    := $(OUT)/timing.json

# Rebuild when project or shared Makefiles change.
BUILD_MAKEFILES := $(MAKEFILE_LIST)

all: $(BITSTREAM)

$(OUT) $(SYNTH_DIR) $(SIM_DIR):
	mkdir -p "$@"

# VHDL to Verilog first
$(VERILOG): $(SRC) $(BUILD_MAKEFILES) | $(SYNTH_DIR)
	ghdl --synth --std=$(STD) --workdir=$(SYNTH_DIR) \
		--out=verilog $(SRC) -e $(TOP) > "$@"

# Verilog to Gowin netlist
$(NETLIST): $(VERILOG) $(BUILD_MAKEFILES) 
	yosys -p "read_verilog $(VERILOG); synth_gowin -top $(TOP) -json $@"

# Place and route
$(ROUTED): $(NETLIST) $(CST) $(BUILD_MAKEFILES)
	nextpnr-himbaechel --device $(DEVICE) \
		--top $(TOP) \
		--json $(NETLIST) --write "$@" --freq $(FREQ) \
		--vopt family=$(FAMILY) --vopt cst=$(CST) \
		--report $(REPORT) \
		--detailed-timing-report \
		--log $(OUT)/nextpnr.log

# Bitstream
$(BITSTREAM): $(ROUTED) $(BUILD_MAKEFILES) 
	gowin_pack -d $(FAMILY) -o "$@" "$(ROUTED)"

# Program FPGA
program: $(BITSTREAM)
	openFPGALoader -b $(BOARD) "$(BITSTREAM)"

# Program persistent flash.
flash: $(BITSTREAM)
	openFPGALoader -b $(BOARD) -f "$(BITSTREAM)"

timing: $(ROUTED)
	@echo "=== Maximum Frequencies ==="
	@jq '.fmax' "$(REPORT)"
	@echo "=== FPGA Utilization ==="
	@jq '.utilization' "$(REPORT)"

# Always analyze and run when explicitly requested.
# Running inside SIM_DIR keeps GHDL's generated files there.
sim: $(SRC) $(TB_SRC) | $(SIM_DIR)
	cd "$(SIM_DIR)" && \
		ghdl -a --std=$(STD) $(abspath $(SRC) $(TB_SRC))
	cd "$(SIM_DIR)" && \
		ghdl --elab-run --std=$(STD) -o $(TB) $(TB) \
		--wave=$(TB).ghw \
		--stop-time=$(SIM_TIME) \
		--assert-level=error
	surfer "$(SIM_DIR)/$(TB).ghw"

# Remove generated files for the current top only.
clean:
	rm -rf -- "$(OUT)"

clean_all: 
	rm -rf -- $(BUILD)

.PHONY: all program flash timing sim clean clean_all
