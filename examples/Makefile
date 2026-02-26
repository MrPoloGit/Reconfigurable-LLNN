.PHONY: all env train sim clean

VENV_DIR = venv
PYTHON = $(VENV_DIR)/bin/python
PIP = $(VENV_DIR)/bin/pip

all: env train sim

# Create a virtual environment and install dependencies
env: $(VENV_DIR)/bin/activate

$(VENV_DIR)/bin/activate: ../requirements.txt ../setup.py
	python3 -m venv $(VENV_DIR)
	$(PIP) install --upgrade pip
	$(PIP) install -r ../requirements.txt
	$(PIP) install -e ..
	touch $(VENV_DIR)/bin/activate

# Train the simple LUTNN model and generate SV code
train: env simple_lutnn.py
	$(PYTHON) simple_lutnn.py --epochs 4 --batch-size 128 --lr 0.01

# Compile and run the testbench using Icarus Verilog
sim: data/sv/simple_lutnn/top.sv ../hdl/tb_NET.sv
	iverilog -g2012 -I data/sv/simple_lutnn -o tb_NET ../hdl/tb_NET.sv data/sv/simple_lutnn/*.sv
	vvp tb_NET

# Clean generated files and environment
clean:
	rm -rf $(VENV_DIR)
	rm -rf data
	rm -f tb_NET
