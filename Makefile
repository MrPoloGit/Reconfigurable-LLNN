MODEL      ?= model1
PART       := xc7z020clg400-1
TOP        := top
BUILD_DIR  := build/$(MODEL)
SV_DIR     := data/sv/$(MODEL)

VIVADO     := cmd.exe /c C:\\Xilinx\\Vivado\\2024.1\\bin\\vivado.bat

SV_FILES_UNIX := $(wildcard $(SV_DIR)/*.sv)

# Convert all paths to Windows format
SV_FILES := $(shell for f in $(SV_FILES_UNIX); do wslpath -w $$f; done)

BUILD_WIN := $(shell wslpath -w $(BUILD_DIR))

.PHONY: bitstream clean

bitstream:
	mkdir -p $(BUILD_DIR)
	$(VIVADO) -mode batch -source build.tcl \
		-tclargs $(TOP) $(PART) "$(BUILD_WIN)" "$(SV_FILES)"

clean:
	rm -rf build