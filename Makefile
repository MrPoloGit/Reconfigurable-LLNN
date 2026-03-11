# MODEL ?= model1
# PART  := xc7z020clg400-1
# TOP   := top

# VIVADO_VERSION := 2025.2

# BUILD_DIR   := build/$(MODEL)
# SV_DIR      := data/sv/$(MODEL)
# OVERLAY_DIR := hdl/overlay

# BOARD_REPO  := boards

# VIVADO_XILINX := C:\\Xilinx\\Vivado\\$(VIVADO_VERSION)\\bin\\vivado.bat
# VIVADO_AMD   := C:\\AMDDesignTools\\$(VIVADO_VERSION)\\Vivado\\bin\\vivado.bat

# VIVADO_BAT := $(shell cmd.exe /c "if exist $(VIVADO_AMD) (echo $(VIVADO_AMD)) else if exist $(VIVADO_XILINX) (echo $(VIVADO_XILINX))")
# VIVADO := cmd.exe /c "cd /d C:\ && C:\\AMDDesignTools\\$(VIVADO_VERSION)\\Vivado\\bin\\vivado.bat"

# REPO_ROOT_WIN := $(shell wslpath -w "$(CURDIR)")
# PROJECT_TCL_WIN := $(shell wslpath -w "$(CURDIR)/scripts/project.tcl")

# SV_FILES_UNIX := $(wildcard $(SV_DIR)/*.sv) $(wildcard $(OVERLAY_DIR)/*.sv)

# SV_FILES := $(shell for f in $(SV_FILES_UNIX); do wslpath -m "$$f"; done)

# BUILD_WIN := $(shell wslpath -w "$(BUILD_DIR)")
# BOARD_REPO_WIN := $(shell wslpath -w "$(BOARD_REPO)")

# # CONSTRAINTS := constraints/PYNQ-Z2\ v1.0.xdc
# # CONSTRAINTS_WIN := $(shell wslpath -m "$(CONSTRAINTS)")

# SV2V_DIR := data/verilog/$(MODEL)

# SV2V_FILES_UNIX := $(patsubst $(SV_DIR)/%.sv,$(SV2V_DIR)/%.v,$(wildcard $(SV_DIR)/*.sv))

# .PHONY: help sv2v project open build clean

# help:
# 	@echo ""
# 	@echo "Vivado FPGA Build System"
# 	@echo "========================"
# 	@echo ""
# 	@echo "Targets:"
# 	@echo ""
# 	@echo "  make sv2v [MODEL=modelX]"
# 	@echo "      Convert SystemVerilog to Verilog using sv2v."
# 	@echo ""
# 	@echo "  make project [MODEL=modelX]"
# 	@echo "      Create Vivado project."
# 	@echo ""
# 	@echo "  make open [MODEL=modelX]"
# 	@echo "      Open the Vivado GUI."
# 	@echo ""
# 	@echo "  make build [MODEL=modelX]"
# 	@echo "      Run synthesis + implementation."
# 	@echo ""
# 	@echo "  make clean [MODEL=modelX]"
# 	@echo "      Delete a specific model project, if nothing is specified delete the build folder."
# 	@echo ""
# 	@echo "Options:"
# 	@echo ""
# 	@echo "  MODEL=model1 (default)"
# 	@echo ""

# sv2v:
# 	@echo "Converting SystemVerilog -> Verilog for model: $(MODEL)"
# 	@mkdir -p "$(SV2V_DIR)"

# 	@for f in $(SV_DIR)/*.sv; do \
# 		base=$$(basename $$f .sv); \
# 		echo "  $$base.sv -> $$base.v"; \
# 		sv2v $$f > "$(SV2V_DIR)/$$base.v"; \
# 	done

# project:
# 	@echo "Creating project for model: $(MODEL)"
# 	@echo "Vivado version: $(VIVADO_VERSION)"
# 	mkdir -p "$(BUILD_DIR)"
# 	$(VIVADO) -mode batch -source "$(PROJECT_TCL_WIN)" \
# 		-tclargs "$(TOP)" "$(PART)" "$(BUILD_WIN)" "$(BOARD_REPO_WIN)" $(SV_FILES)

# open:
# 	@if [ ! -f "$(BUILD_DIR)/$(TOP).xpr" ]; then \
# 		echo "Error: Vivado project not found."; \
# 		echo "Expected: $(BUILD_DIR)/$(TOP).xpr"; \
# 		echo "Run 'make project MODEL=$(MODEL)' first."; \
# 		exit 1; \
# 	fi
# 	$(VIVADO) "$(BUILD_WIN)/$(TOP).xpr"

# build:
# 	@echo "Building model: $(MODEL)"
# 	@if [ ! -f "$(BUILD_DIR)/$(TOP).xpr" ]; then \
# 		echo "Error: Vivado project not found."; \
# 		echo "Expected: $(BUILD_DIR)/$(TOP).xpr"; \
# 		echo "Run 'make project MODEL=$(MODEL)' first."; \
# 		exit 1; \
# 	fi
# 	$(VIVADO) -mode batch -source scripts/build.tcl \
# 		-tclargs "$(TOP)" "$(BUILD_WIN)"

# clean:
# ifdef MODEL
# 	rm -rf "$(BUILD_DIR)"
# else
# 	rm -rf build
# endif




# Windows 10
# MODEL ?= model1
# PART  := xc7z020clg400-1
# TOP   := top

# VIVADO_VERSION := 2024.1

# BUILD_DIR   := build/$(MODEL)
# SV_DIR      := data/sv/$(MODEL)
# OVERLAY_DIR := hdl/overlay

# BOARD_REPO  := boards

# # Detect major Vivado version
# VIVADO_MAJOR := $(firstword $(subst ., ,$(VIVADO_VERSION)))

# # Use AMD path for Vivado 2025+, Xilinx path otherwise
# ifeq ($(shell [ $(VIVADO_MAJOR) -ge 2025 ] && echo yes),yes)
# VIVADO := cmd.exe /c C:\\AMDDesignTools\\$(VIVADO_VERSION)\\Vivado\\bin\\vivado.bat
# else
# VIVADO := cmd.exe /c C:\\Xilinx\\Vivado\\$(VIVADO_VERSION)\\bin\\vivado.bat
# endif

# SV_FILES_UNIX := $(wildcard $(SV_DIR)/*.sv) $(wildcard $(OVERLAY_DIR)/*.sv)

# SV_FILES := $(shell for f in $(SV_FILES_UNIX); do wslpath -m "$$f"; done)

# BUILD_WIN       := $(shell wslpath -m "$(BUILD_DIR)")
# BOARD_REPO_WIN  := $(shell wslpath -m "$(BOARD_REPO)")

# # CONSTRAINTS := constraints/PYNQ-Z2\ v1.0.xdc
# # CONSTRAINTS_WIN := $(shell wslpath -m "$(CONSTRAINTS)")

# SV2V_DIR := data/verilog/$(MODEL)

# SV2V_FILES_UNIX := $(patsubst $(SV_DIR)/%.sv,$(SV2V_DIR)/%.v,$(wildcard $(SV_DIR)/*.sv))

# .PHONY: help sv2v project open build clean

# help:
# 	@echo ""
# 	@echo "Vivado FPGA Build System"
# 	@echo "========================"
# 	@echo ""
# 	@echo "Targets:"
# 	@echo ""
# 	@echo "  make sv2v [MODEL=modelX]"
# 	@echo "      Convert SystemVerilog to Verilog using sv2v."
# 	@echo ""
# 	@echo "  make project [MODEL=modelX]"
# 	@echo "      Create Vivado project."
# 	@echo ""
# 	@echo "  make open [MODEL=modelX]"
# 	@echo "      Open the Vivado GUI."
# 	@echo ""
# 	@echo "  make build [MODEL=modelX]"
# 	@echo "      Run synthesis + implementation."
# 	@echo ""
# 	@echo "  make clean [MODEL=modelX]"
# 	@echo "      Delete a specific model project, if nothing is specified delete the build folder."
# 	@echo ""
# 	@echo "Options:"
# 	@echo ""
# 	@echo "  MODEL=model1 (default)"
# 	@echo ""

# sv2v:
# 	@echo "Converting SystemVerilog -> Verilog for model: $(MODEL)"
# 	@mkdir -p "$(SV2V_DIR)"

# 	@for f in $(SV_DIR)/*.sv; do \
# 		base=$$(basename $$f .sv); \
# 		echo "  $$base.sv -> $$base.v"; \
# 		sv2v $$f > "$(SV2V_DIR)/$$base.v"; \
# 	done

# project:
# 	@echo "Creating project for model: $(MODEL)"
# 	@echo "Vivado version: $(VIVADO_VERSION)"
# 	mkdir -p "$(BUILD_DIR)"
# 	$(VIVADO) -mode batch -source scripts/project.tcl \
# 		-tclargs "$(TOP)" "$(PART)" "$(BUILD_WIN)" "$(BOARD_REPO_WIN)" $(SV_FILES)

# open:
# 	@if [ ! -f "$(BUILD_DIR)/$(TOP).xpr" ]; then \
# 		echo "Error: Vivado project not found."; \
# 		echo "Expected: $(BUILD_DIR)/$(TOP).xpr"; \
# 		echo "Run 'make project MODEL=$(MODEL)' first."; \
# 		exit 1; \
# 	fi
# 	$(VIVADO) "$(BUILD_WIN)/$(TOP).xpr"

# build:
# 	@echo "Building model: $(MODEL)"
# 	@if [ ! -f "$(BUILD_DIR)/$(TOP).xpr" ]; then \
# 		echo "Error: Vivado project not found."; \
# 		echo "Expected: $(BUILD_DIR)/$(TOP).xpr"; \
# 		echo "Run 'make project MODEL=$(MODEL)' first."; \
# 		exit 1; \
# 	fi
# 	$(VIVADO) -mode batch -source scripts/build.tcl \
# 		-tclargs "$(TOP)" "$(BUILD_WIN)"

# clean:
# ifdef MODEL
# 	rm -rf "$(BUILD_DIR)"
# else
# 	rm -rf build
# endif



# LINUX
# =============================================================================
# Vivado FPGA Build System
# =============================================================================

MODEL ?= model1
PART  := xc7z020clg400-1
TOP   := top
PROJECT_NAME := $(TOP)

BUILD_DIR   := build/$(MODEL)
SV_DIR      := data/sv/$(MODEL)
OVERLAY_DIR := hdl/overlay
BOARD_REPO  := boards

# Vivado executable (assumes environment already sourced)
VIVADO ?= vivado
CLK_FREQ_MHZ ?= 25

# -----------------------------------------------------------------------------
# Source collection
# -----------------------------------------------------------------------------
MODEL_SV_SOURCES    := $(sort $(wildcard $(SV_DIR)/*.sv))
OVERLAY_SV_SOURCES  := $(sort $(wildcard $(OVERLAY_DIR)/*.sv))
OVERLAY_V_SOURCES   := $(sort $(wildcard $(OVERLAY_DIR)/*.v))

# Complete source list passed into Tcl
SOURCES := $(MODEL_SV_SOURCES) $(OVERLAY_SV_SOURCES) $(OVERLAY_V_SOURCES)

# -----------------------------------------------------------------------------
# sv2v conversion
# -----------------------------------------------------------------------------
SV2V_DIR   := data/verilog/$(MODEL)
SV2V_INPUT := $(filter-out $(SV_DIR)/Globals.sv,$(MODEL_SV_SOURCES) $(OVERLAY_SV_SOURCES))
SV2V_FILES := $(patsubst $(SV_DIR)/%.sv,$(SV2V_DIR)/%.v,$(SV2V_INPUT))

# -----------------------------------------------------------------------------
# Verilog sources produced by sv2v
# -----------------------------------------------------------------------------
# VERILOG_DIR     := data/verilog/$(MODEL)
# VERILOG_SOURCES := $(sort $(wildcard $(VERILOG_DIR)/*.v))
# VERILOG_SOURCES := \
# 	data/verilog/model1/SoftLUT5.v \
# 	data/verilog/model1/softlut5_test_wrapper.v \
# 	data/verilog/model1/axi_lut_ctrl.v \
# 	data/verilog/model1/CFGLUT5.v

VERILOG_SOURCES := \
	data/verilog/$(MODEL)/SoftLUT5.v \
	data/verilog/$(MODEL)/softlut5_test_wrapper.v \
	data/verilog/$(MODEL)/axi_lut_ctrl.v

JOBS ?= 4

.PHONY: help print-sources sv2v project design open build build_overlay clean

help:
	@echo ""
	@echo "Vivado FPGA Build System"
	@echo "========================"
	@echo ""
	@echo "Targets:"
	@echo ""
	@echo "  make print-sources [MODEL=modelX]"
	@echo "      Print the complete resolved source list."
	@echo ""
	@echo "  make sv2v [MODEL=modelX]"
	@echo "      Convert SystemVerilog to Verilog using sv2v."
	@echo ""
	@echo "  make project [MODEL=modelX]"
	@echo "      Create Vivado project and add all sources."
	@echo ""
	@echo "  make design [MODEL=modelX]"
	@echo "      Create Vivado project + block design flow."
	@echo ""
	@echo "  make open [MODEL=modelX]"
	@echo "      Open the Vivado GUI."
	@echo ""
	@echo "  make build [MODEL=modelX]"
	@echo "      Run synthesis + implementation."
	@echo ""
	@echo "  make build_overlay [MODEL=modelX]"
	@echo "      Run overlay build flow."
	@echo ""
	@echo "  make clean [MODEL=modelX]"
	@echo "      Delete a specific model project, or all build outputs."
	@echo ""

print-sources:
	@echo "MODEL               = $(MODEL)"
	@echo "TOP                 = $(TOP)"
	@echo "PROJECT_NAME        = $(PROJECT_NAME)"
	@echo "BUILD_DIR           = $(BUILD_DIR)"
	@echo "SV_DIR              = $(SV_DIR)"
	@echo "OVERLAY_DIR         = $(OVERLAY_DIR)"
	@echo ""
	@echo "Complete SOURCES:"
	@for f in $(SOURCES); do echo "  $$f"; done

sv2v:
	@echo "Converting SystemVerilog -> Verilog for model: $(MODEL)"
	@mkdir -p "$(SV2V_DIR)"
	@for f in $(SV2V_INPUT); do \
		base=$$(basename $$f .sv); \
		echo "  $$base.sv -> $$base.v"; \
		sv2v "$(SV_DIR)/Globals.sv" "$$f" > "$(SV2V_DIR)/$$base.v"; \
	done

yosys:
	@echo "Running Yosys synthesis for model: $(MODEL)"
	yosys -p 'read_verilog $(VERILOG_SOURCES); read_verilog -lib +/xilinx/cells_sim.v; hierarchy -check -top softlut5_test_wrapper; proc; opt; write_verilog yosys_netlist.v; stat'

# yosys:
# 	@echo "Running Yosys synthesis"
# 	yosys -p 'read_verilog $(shell cat rtl.f); read_verilog -lib +/xilinx/cells_sim.v; hierarchy -check -top softlut5_test_wrapper; proc; opt; write_verilog yosys_netlist.v; stat'

project:
	@echo "Creating Vivado project for model: $(MODEL)"
	@mkdir -p "$(BUILD_DIR)"
	@if [ -z "$(strip $(SOURCES))" ]; then \
		echo "Error: no sources found."; \
		exit 1; \
	fi
	$(VIVADO) -mode batch -source scripts/project.tcl \
		-tclargs "$(TOP)" "$(PART)" "$(BUILD_DIR)" "$(BOARD_REPO)" $(SOURCES)

design:
	@echo "Creating Vivado project + block design for model: $(MODEL)"
	@mkdir -p "$(BUILD_DIR)"
	@if [ -z "$(strip $(SOURCES))" ]; then \
		echo "Error: no sources found."; \
		exit 1; \
	fi
	$(VIVADO) -mode batch -source scripts/create_design.tcl \
		-tclargs "$(TOP)" "$(PART)" "$(BUILD_DIR)" "$(BOARD_REPO)" "$(CLK_FREQ_MHZ)" $(SOURCES)

open:
	@if [ ! -f "$(BUILD_DIR)/$(PROJECT_NAME).xpr" ]; then \
		echo "Error: Vivado project not found."; \
		echo "Expected: $(BUILD_DIR)/$(PROJECT_NAME).xpr"; \
		echo "Run 'make project MODEL=$(MODEL)' first."; \
		exit 1; \
	fi
	$(VIVADO) "$(BUILD_DIR)/$(PROJECT_NAME).xpr"

build:
	@echo "Building model: $(MODEL)"
	@if [ ! -f "$(BUILD_DIR)/$(PROJECT_NAME).xpr" ]; then \
		echo "Error: Vivado project not found."; \
		echo "Expected: $(BUILD_DIR)/$(PROJECT_NAME).xpr"; \
		echo "Run 'make project MODEL=$(MODEL)' first."; \
		exit 1; \
	fi
	$(VIVADO) -mode batch -source scripts/build.tcl \
		-tclargs "$(TOP)" "$(BUILD_DIR)"

build_overlay:
	@echo "Building LLNN overlay (PYNQ-Z2)"
	$(VIVADO) -mode batch -source scripts/build_overlay.tcl \
		-tclargs "$(OVERLAY_DIR)" "$(BUILD_DIR)/overlay" "llnn_bd" "$(JOBS)" "$(SV_DIR)"

clean:
ifdef MODEL
	rm -rf "$(BUILD_DIR)"
else
	rm -rf build
endif