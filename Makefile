MODEL      ?= model1
PART       := xc7z020clg400-1
TOP        := top

BUILD_DIR   := build/$(MODEL)
SV_DIR      := data/sv/$(MODEL)
OVERLAY_DIR := hdl/overlay

# Maybe change to add tul before pynq-z2
BOARD_REPO  := boards
CONSTRAINTS := constraints/PYNQ-Z2.xdc

VIVADO := cmd.exe /c C:\\Xilinx\\Vivado\\2024.1\\bin\\vivado.bat

SV_FILES_UNIX := $(wildcard $(SV_DIR)/*.sv) $(wildcard $(OVERLAY_DIR)/*.sv)

SV_FILES := $(shell for f in $(SV_FILES_UNIX); do wslpath -m $$f; done)

BUILD_WIN := $(shell wslpath -m $(BUILD_DIR))
BOARD_REPO_WIN := $(shell wslpath -m $(BOARD_REPO))
CONSTRAINTS_WIN := $(shell wslpath -m $(CONSTRAINTS))

.PHONY: help project open build clean

help:
	@echo ""
	@echo "Vivado FPGA Build System"
	@echo "========================"
	@echo ""
	@echo "Targets:"
	@echo ""
	@echo "  make project"
	@echo "      Create Vivado project using board files inside the repo."
	@echo ""
	@echo "  make open"
	@echo "      Open the Vivado GUI."
	@echo ""
	@echo "  make build"
	@echo "      Run synthesis + implementation + bitstream generation."
	@echo ""
	@echo "  make clean"
	@echo "      Delete build directory."
	@echo ""
	@echo "Repository Board Files:"
	@echo ""
	@echo "  boards/pynq-z2/A.0/"
	@echo "      board.xml"
	@echo "      part0_pins.xml"
	@echo "      preset.xml"
	@echo ""
	@echo "Example workflow:"
	@echo ""
	@echo "  make project"
	@echo "  make open"
	@echo "  make build"
	@echo ""

project:
	mkdir -p $(BUILD_DIR)
	$(VIVADO) -mode batch -source scripts/project.tcl \
		-tclargs $(TOP) $(PART) "$(BUILD_WIN)" $(SV_FILES) "$(CONSTRAINTS_WIN)" "$(BOARD_REPO_WIN)"

open:
	@if [ ! -f "$(BUILD_DIR)/$(TOP).xpr" ]; then \
		echo "Error: Vivado project not found."; \
		echo "Expected: $(BUILD_DIR)/$(TOP).xpr"; \
		echo "Run 'make project' first."; \
		exit 1; \
	fi
	$(VIVADO) "$(BUILD_WIN)/$(TOP).xpr"

build:
	mkdir -p $(BUILD_DIR)
	$(VIVADO) -mode batch -source scripts/build.tcl \
		-tclargs $(TOP) "$(BUILD_WIN)"

clean:
	rm -rf build