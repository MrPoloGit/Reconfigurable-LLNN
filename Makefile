MODEL ?= model1
PART  := xc7z020clg400-1
TOP   := top

VIVADO_VERSION := 2025.2

BUILD_DIR   := build/$(MODEL)
SV_DIR      := data/sv/$(MODEL)
OVERLAY_DIR := hdl/overlay

BOARD_REPO  := boards

VIVADO_XILINX := C:\\Xilinx\\Vivado\\$(VIVADO_VERSION)\\bin\\vivado.bat
VIVADO_AMD   := C:\\AMDDesignTools\\$(VIVADO_VERSION)\\Vivado\\bin\\vivado.bat

VIVADO_BAT := $(shell cmd.exe /c "if exist $(VIVADO_AMD) (echo $(VIVADO_AMD)) else if exist $(VIVADO_XILINX) (echo $(VIVADO_XILINX))")
VIVADO := cmd.exe /c "cd /d C:\ && C:\\AMDDesignTools\\$(VIVADO_VERSION)\\Vivado\\bin\\vivado.bat"

REPO_ROOT_WIN := $(shell wslpath -w "$(CURDIR)")
PROJECT_TCL_WIN := $(shell wslpath -w "$(CURDIR)/scripts/project.tcl")

SV_FILES_UNIX := $(wildcard $(SV_DIR)/*.sv) $(wildcard $(OVERLAY_DIR)/*.sv)

SV_FILES := $(shell for f in $(SV_FILES_UNIX); do wslpath -m "$$f"; done)

BUILD_WIN := $(shell wslpath -w "$(BUILD_DIR)")
BOARD_REPO_WIN := $(shell wslpath -w "$(BOARD_REPO)")

# CONSTRAINTS := constraints/PYNQ-Z2\ v1.0.xdc
# CONSTRAINTS_WIN := $(shell wslpath -m "$(CONSTRAINTS)")

SV2V_DIR := data/verilog/$(MODEL)

SV2V_FILES_UNIX := $(patsubst $(SV_DIR)/%.sv,$(SV2V_DIR)/%.v,$(wildcard $(SV_DIR)/*.sv))

.PHONY: help sv2v project open build clean

help:
	@echo ""
	@echo "Vivado FPGA Build System"
	@echo "========================"
	@echo ""
	@echo "Targets:"
	@echo ""
	@echo "  make sv2v [MODEL=modelX]"
	@echo "      Convert SystemVerilog to Verilog using sv2v."
	@echo ""
	@echo "  make project [MODEL=modelX]"
	@echo "      Create Vivado project."
	@echo ""
	@echo "  make open [MODEL=modelX]"
	@echo "      Open the Vivado GUI."
	@echo ""
	@echo "  make build [MODEL=modelX]"
	@echo "      Run synthesis + implementation."
	@echo ""
	@echo "  make clean [MODEL=modelX]"
	@echo "      Delete a specific model project, if nothing is specified delete the build folder."
	@echo ""
	@echo "Options:"
	@echo ""
	@echo "  MODEL=model1 (default)"
	@echo ""

sv2v:
	@echo "Converting SystemVerilog -> Verilog for model: $(MODEL)"
	@mkdir -p "$(SV2V_DIR)"

	@for f in $(SV_DIR)/*.sv; do \
		base=$$(basename $$f .sv); \
		echo "  $$base.sv -> $$base.v"; \
		sv2v $$f > "$(SV2V_DIR)/$$base.v"; \
	done

project:
	@echo "Creating project for model: $(MODEL)"
	@echo "Vivado version: $(VIVADO_VERSION)"
	mkdir -p "$(BUILD_DIR)"
	$(VIVADO) -mode batch -source "$(PROJECT_TCL_WIN)" \
		-tclargs "$(TOP)" "$(PART)" "$(BUILD_WIN)" "$(BOARD_REPO_WIN)" $(SV_FILES)

open:
	@if [ ! -f "$(BUILD_DIR)/$(TOP).xpr" ]; then \
		echo "Error: Vivado project not found."; \
		echo "Expected: $(BUILD_DIR)/$(TOP).xpr"; \
		echo "Run 'make project MODEL=$(MODEL)' first."; \
		exit 1; \
	fi
	$(VIVADO) "$(BUILD_WIN)/$(TOP).xpr"

build:
	@echo "Building model: $(MODEL)"
	@if [ ! -f "$(BUILD_DIR)/$(TOP).xpr" ]; then \
		echo "Error: Vivado project not found."; \
		echo "Expected: $(BUILD_DIR)/$(TOP).xpr"; \
		echo "Run 'make project MODEL=$(MODEL)' first."; \
		exit 1; \
	fi
	$(VIVADO) -mode batch -source scripts/build.tcl \
		-tclargs "$(TOP)" "$(BUILD_WIN)"

clean:
ifdef MODEL
	rm -rf "$(BUILD_DIR)"
else
	rm -rf build
endif




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






# # LINUX
# MODEL ?= model1
# PART  := xc7z020clg400-1
# TOP   := top

# VIVADO_VERSION := 2024.1

# BUILD_DIR   := build/$(MODEL)
# SV_DIR      := data/sv/$(MODEL)
# OVERLAY_DIR := hdl/overlay

# BOARD_REPO  := boards

# # Vivado executable (assumes environment already sourced)
# VIVADO ?= vivado

# SV_FILES := $(wildcard $(SV_DIR)/*.sv) $(wildcard $(OVERLAY_DIR)/*.sv)

# SV2V_DIR := data/verilog/$(MODEL)

# SV2V_FILES := $(patsubst $(SV_DIR)/%.sv,$(SV2V_DIR)/%.v,$(wildcard $(SV_DIR)/*.sv))

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
# 	@echo "      Delete a specific model project."
# 	@echo ""

# sv2v:
# 	@echo "Converting SystemVerilog -> Verilog for model: $(MODEL)"
# 	@mkdir -p "$(SV2V_DIR)"

# 	@for f in $(SV_DIR)/*.sv; do \
# 		base=$$(basename $$f .sv); \
# 		if [ "$$base" = "Globals" ]; then \
# 			continue; \
# 		fi; \
# 		echo "  $$base.sv -> $$base.v"; \
# 		sv2v $(SV_DIR)/Globals.sv $$f > "$(SV2V_DIR)/$$base.v"; \
# 	done

# project:
# 	@echo "Creating project for model: $(MODEL)"
# 	@echo "Vivado version: $(VIVADO_VERSION)"
# 	mkdir -p "$(BUILD_DIR)"

# 	$(VIVADO) -mode batch -source scripts/project.tcl \
# 		-tclargs "$(TOP)" "$(PART)" "$(BUILD_DIR)" "$(BOARD_REPO)" $(SV_FILES)

# open:
# 	@if [ ! -f "$(BUILD_DIR)/$(TOP).xpr" ]; then \
# 		echo "Error: Vivado project not found."; \
# 		echo "Expected: $(BUILD_DIR)/$(TOP).xpr"; \
# 		echo "Run 'make project MODEL=$(MODEL)' first."; \
# 		exit 1; \
# 	fi

# 	$(VIVADO) "$(BUILD_DIR)/$(TOP).xpr"

# build:
# 	@echo "Building model: $(MODEL)"

# 	@if [ ! -f "$(BUILD_DIR)/$(TOP).xpr" ]; then \
# 		echo "Error: Vivado project not found."; \
# 		echo "Expected: $(BUILD_DIR)/$(TOP).xpr"; \
# 		echo "Run 'make project MODEL=$(MODEL)' first."; \
# 		exit 1; \
# 	fi

# 	$(VIVADO) -mode batch -source scripts/build.tcl \
# 		-tclargs "$(TOP)" "$(BUILD_DIR)"

# clean:
# ifdef MODEL
# 	rm -rf "$(BUILD_DIR)"
# else
# 	rm -rf build
# endif