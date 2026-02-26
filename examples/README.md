# Simple LUTNN Example

This directory contains a complete example workflow for training a Look-Up Table Neural Network (LUTNN) and simulating the generated hardware. 

You can run this via the `Simple LUTNN.ipynb` notebook, or automatically using the extracted Python script and `Makefile` provided here.

## Conceptual Flow
1. **Model Training**: A simple 2-layer LUTNN is trained on the MNIST dataset using PyTorch (`simple_lutnn.py`). Command line arguments are available to control hyperparameters (e.g., `--epochs`, `--batch-size`, `--lr`).
2. **Hardware Generation**: Upon completion of training, the model's architecture and weights are exported as SystemVerilog configuration files into `data/sv/simple_lutnn/`.
3. **Simulation**: The generated Verilog modules are instantiated and simulated using a provided testbench (`../hdl/tb_NET.sv`), and run via `iverilog`.

## Quick Start (Automated with Makefile)

To execute the entire flow in one step (virtualenv setup, training, and simulation):

```bash
make all
```

Other available Make targets:
- `make env`: Sets up the Python virtual environment and installs `requirements.txt`.
- `make train`: Runs `simple_lutnn.py` to train the model and generate HDL.
- `make sim`: Compiles and executes the testbench using Icarus Verilog.
- `make clean`: Removes generated SV files, VHDL files, testbench binaries, and the local virtual environment.

## Manual Instructions

If you prefer to run the steps manually:

1. **Setup Python Environment**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r ../requirements.txt 
   pip install -e ..
   ```

2. **Train & Generate HDL**
   Run the generated Python configuration script.
   ```bash
   python simple_lutnn.py --epochs 4 --batch-size 128 --lr 0.01
   ```
   *SystemVerilog configurations will be output to `data/sv/simple_lutnn/*.sv`*

3. **Run Simulation**
   Compile and run the testbench with Icarus Verilog (*assuming commands are run from the `examples` directory*):
   ```bash
   iverilog -g2012 -I data/sv/simple_lutnn -o tb_NET ../hdl/tb_NET.sv data/sv/simple_lutnn/*.sv
   vvp tb_NET
   ```
