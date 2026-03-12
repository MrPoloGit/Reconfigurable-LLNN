# # WINDOWS 11 (WSL calling Windows Vivado)
# # =============================================================================
# # Vivado FPGA Build System
# # =============================================================================

# MODEL ?= model1
# PART  := xc7z020clg400-1
# TOP   := top
# PROJECT_NAME := $(TOP)
# VIVADO_VERSION := 2025.2

# BUILD_DIR   := build/$(MODEL)
# SV_DIR      := data/sv/$(MODEL)
# OVERLAY_DIR := hdl/overlay
# BOARD_REPO  := boards

# # Vivado executable on Windows (supports AMDDesignTools and legacy Xilinx paths)
# VIVADO_XILINX := C:\\Xilinx\\Vivado\\$(VIVADO_VERSION)\\bin\\vivado.bat
# VIVADO_AMD    := C:\\AMDDesignTools\\$(VIVADO_VERSION)\\Vivado\\bin\\vivado.bat
# VIVADO_BAT    := $(shell cmd.exe /c "if exist $(VIVADO_AMD) (echo $(VIVADO_AMD)) else if exist $(VIVADO_XILINX) (echo $(VIVADO_XILINX))")
# VIVADO        := cmd.exe /c "$(VIVADO_BAT)"

# CLK_FREQ_MHZ ?= 10

# # -----------------------------------------------------------------------------
# # Source collection
# # -----------------------------------------------------------------------------
# MODEL_SV_SOURCES    := $(sort $(wildcard $(SV_DIR)/*.sv))
# OVERLAY_SV_SOURCES  := $(sort $(wildcard $(OVERLAY_DIR)/*.sv))
# OVERLAY_V_SOURCES   := $(sort $(wildcard $(OVERLAY_DIR)/*.v))

# # Complete source list passed into Tcl
# SOURCES := $(MODEL_SV_SOURCES) $(OVERLAY_SV_SOURCES) $(OVERLAY_V_SOURCES)
# SOURCES_WIN := $(shell for f in $(SOURCES); do wslpath -m "$$f"; done)
# BUILD_WIN := $(shell wslpath -m "$(BUILD_DIR)")
# BOARD_REPO_WIN := $(shell wslpath -m "$(BOARD_REPO)")

# JOBS ?= 12

# .PHONY: help print-sources project design open build build_overlay build_reconfig clean clean-data clean-model clean-vivado

# help: ## Show this help message
# 	@echo 'Usage: make [target]'
# 	@echo ''
# 	@echo 'Available targets:'
# 	@grep -E '^[a-zA-Z0-9_-]+:[^#]*## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":[^#]*## "}; {printf "  %-20s %s\n", $$1, $$2}'

# print-sources: ## Print resolved HDL source files used in the build
# 	@echo "MODEL               = $(MODEL)"
# 	@echo "TOP                 = $(TOP)"
# 	@echo "PROJECT_NAME        = $(PROJECT_NAME)"
# 	@echo "BUILD_DIR           = $(BUILD_DIR)"
# 	@echo "SV_DIR              = $(SV_DIR)"
# 	@echo "OVERLAY_DIR         = $(OVERLAY_DIR)"
# 	@echo ""
# 	@echo "Complete SOURCES:"
# 	@for f in $(SOURCES); do echo "  $$f"; done

# project: ## Create Vivado project and import HDL sources
# 	@echo "Creating Vivado project for model: $(MODEL)"
# 	@mkdir -p "$(BUILD_DIR)"
# 	@if [ -z "$(strip $(SOURCES))" ]; then \
# 		echo "Error: no sources found."; \
# 		exit 1; \
# 	fi
# 	$(VIVADO) -mode batch -source scripts/project.tcl \
# 		-tclargs "$(TOP)" "$(PART)" "$(BUILD_WIN)" "$(BOARD_REPO_WIN)" $(SOURCES_WIN)

# design: ## Generate block design (Zynq PS + accelerator integration)
# 	@echo "Creating Vivado project + block design for model: $(MODEL)"
# 	@mkdir -p "$(BUILD_DIR)"
# 	@if [ -z "$(strip $(SOURCES))" ]; then \
# 		echo "Error: no sources found."; \
# 		exit 1; \
# 	fi
# 	$(VIVADO) -mode batch -source scripts/create_design.tcl \
# 		-tclargs "$(TOP)" "$(PART)" "$(BUILD_WIN)" "$(BOARD_REPO_WIN)" "$(CLK_FREQ_MHZ)" $(SOURCES_WIN)

# open: ## Open the Vivado GUI for the generated project
# 	@if [ ! -f "$(BUILD_DIR)/$(PROJECT_NAME).xpr" ]; then \
# 		echo "Error: Vivado project not found."; \
# 		echo "Expected: $(BUILD_DIR)/$(PROJECT_NAME).xpr"; \
# 		echo "Run 'make project MODEL=$(MODEL)' first."; \
# 		exit 1; \
# 	fi
# 	$(VIVADO) "$(BUILD_WIN)/$(PROJECT_NAME).xpr"

# build: ## Run synthesis and implementation to produce FPGA bitstream	@echo "Building model: $(MODEL)"
# 	@if [ ! -f "$(BUILD_DIR)/$(PROJECT_NAME).xpr" ]; then \
# 		echo "Error: Vivado project not found."; \
# 		echo "Expected: $(BUILD_DIR)/$(PROJECT_NAME).xpr"; \
# 		echo "Run 'make project MODEL=$(MODEL)' first."; \
# 		exit 1; \
# 	fi
# 	$(VIVADO) -mode batch -source scripts/build.tcl \
# 		-tclargs "$(TOP)" "$(BUILD_WIN)"

# build_overlay: ## Build static LLNN overlay bitstream for PYNQ-Z2
# 	@echo "Building LLNN overlay (PYNQ-Z2) — static"
# 	$(VIVADO) -mode batch -source scripts/build_overlay.tcl \
# 		-tclargs "$(OVERLAY_DIR)" "$(BUILD_DIR)/overlay" "llnn_bd" "$(JOBS)" "$(SV_DIR)"

# build_reconfig: ## Build reconfigurable LLNN overlay supporting runtime LUT loading
# 	@echo "Building reconfigurable LLNN overlay (PYNQ-Z2)"
# 	@test -d data/overlay/$(MODEL) || (echo "ERROR: data/overlay/$(MODEL) not found. Run: python hdl/generate_overlay.py --model $(MODEL)"; exit 1)
# 	$(VIVADO) -mode batch -source scripts/build_overlay.tcl \
# 		-tclargs "$(OVERLAY_DIR)" "$(BUILD_DIR)/reconfig" "llnn_bd" "$(JOBS)" "data/overlay/$(MODEL)"

# clean-data: ## Delete generated datasets and intermediate training data
# 	rm -rf data

# clean-model: ## Delete trained model artifacts
# ifdef MODEL
# 	rm -rf models/$(MODEL)
# else
# 	rm -rf models
# endif

# clean-vivado: ## Remove Vivado build outputs and logs
# ifdef MODEL
# 	rm -rf "$(BUILD_DIR)" 
# else
# 	rm -rf build vivado_*.backup.jou vivado_*.backup.log vivado_pid*.str vivado.jou vivado.log .Xil NA
# endif

# clean: ## Remove all generated artifacts (data, models, Vivado builds)
# 	rm -rf data models build








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

# Vivado executable (assumes settings64.sh already sourced)
VIVADO ?= vivado

CLK_FREQ_MHZ ?= 10

# -----------------------------------------------------------------------------
# Source collection
# -----------------------------------------------------------------------------
MODEL_SV_SOURCES    := $(sort $(wildcard $(SV_DIR)/*.sv))
OVERLAY_SV_SOURCES  := $(sort $(wildcard $(OVERLAY_DIR)/*.sv))
OVERLAY_V_SOURCES   := $(sort $(wildcard $(OVERLAY_DIR)/*.v))

# Complete source list passed into Tcl
SOURCES := $(MODEL_SV_SOURCES) $(OVERLAY_SV_SOURCES) $(OVERLAY_V_SOURCES)

JOBS ?= $(shell nproc)

.PHONY: help print-sources project design open build build_overlay build_reconfig clean clean-data clean-model clean-vivado

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z0-9_-]+:[^#]*## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":[^#]*## "}; {printf "  %-20s %s\n", $$1, $$2}'

print-sources: ## Print resolved HDL source files used in the build
	@echo "MODEL               = $(MODEL)"
	@echo "TOP                 = $(TOP)"
	@echo "PROJECT_NAME        = $(PROJECT_NAME)"
	@echo "BUILD_DIR           = $(BUILD_DIR)"
	@echo "SV_DIR              = $(SV_DIR)"
	@echo "OVERLAY_DIR         = $(OVERLAY_DIR)"
	@echo ""
	@echo "Complete SOURCES:"
	@for f in $(SOURCES); do echo "  $$f"; done

project: ## Create Vivado project and import HDL sources
	@echo "Creating Vivado project for model: $(MODEL)"
	@mkdir -p "$(BUILD_DIR)"
	@if [ -z "$(strip $(SOURCES))" ]; then \
		echo "Error: no sources found."; \
		exit 1; \
	fi
	$(VIVADO) -mode batch -source scripts/project.tcl \
		-tclargs "$(TOP)" "$(PART)" "$(BUILD_DIR)" "$(BOARD_REPO)" $(SOURCES)

design: ## Generate block design (Zynq PS + accelerator integration)
	@echo "Creating Vivado project + block design for model: $(MODEL)"
	@mkdir -p "$(BUILD_DIR)"
	@if [ -z "$(strip $(SOURCES))" ]; then \
		echo "Error: no sources found."; \
		exit 1; \
	fi
	$(VIVADO) -mode batch -source scripts/create_design.tcl \
		-tclargs "$(TOP)" "$(PART)" "$(BUILD_DIR)" "$(BOARD_REPO)" "$(CLK_FREQ_MHZ)" $(SOURCES)

open: ## Open the Vivado GUI for the generated project
	@if [ ! -f "$(BUILD_DIR)/$(PROJECT_NAME).xpr" ]; then \
		echo "Error: Vivado project not found."; \
		echo "Expected: $(BUILD_DIR)/$(PROJECT_NAME).xpr"; \
		echo "Run 'make project MODEL=$(MODEL)' first."; \
		exit 1; \
	fi
	$(VIVADO) "$(BUILD_DIR)/$(PROJECT_NAME).xpr"

build: ## Run synthesis and implementation to produce FPGA bitstream
	@echo "Building model: $(MODEL)"
	@if [ ! -f "$(BUILD_DIR)/$(PROJECT_NAME).xpr" ]; then \
		echo "Error: Vivado project not found."; \
		echo "Expected: $(BUILD_DIR)/$(PROJECT_NAME).xpr"; \
		echo "Run 'make project MODEL=$(MODEL)' first."; \
		exit 1; \
	fi
	$(VIVADO) -mode batch -source scripts/build.tcl \
		-tclargs "$(TOP)" "$(BUILD_DIR)"

build_overlay: ## Build static LLNN overlay bitstream for PYNQ-Z2
	@echo "Building LLNN overlay (PYNQ-Z2) — static"
	$(VIVADO) -mode batch -source scripts/build_overlay.tcl \
		-tclargs "$(OVERLAY_DIR)" "$(BUILD_DIR)/overlay" "llnn_bd" "$(JOBS)" "$(SV_DIR)"

build_reconfig: ## Build reconfigurable LLNN overlay supporting runtime LUT loading
	@echo "Building reconfigurable LLNN overlay (PYNQ-Z2)"
	@test -d data/overlay/$(MODEL) || (echo "ERROR: data/overlay/$(MODEL) not found. Run: python hdl/generate_overlay.py --model $(MODEL)"; exit 1)
	$(VIVADO) -mode batch -source scripts/build_overlay.tcl \
		-tclargs "$(OVERLAY_DIR)" "$(BUILD_DIR)/reconfig" "llnn_bd" "$(JOBS)" "data/overlay/$(MODEL)"

clean-data: ## Delete generated datasets and intermediate training data
	rm -rf data

clean-model: ## Delete trained model artifacts
ifdef MODEL
	rm -rf models/$(MODEL)
else
	rm -rf models
endif

clean-vivado: ## Remove Vivado build outputs and logs
ifdef MODEL
	rm -rf "$(BUILD_DIR)" 
else
	rm -rf build vivado_*.backup.jou vivado_*.backup.log vivado_pid*.str vivado.jou vivado.log .Xil NA
endif

clean: ## Remove all generated artifacts (data, models, Vivado builds)
	rm -rf data models build