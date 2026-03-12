# LiveLLNN: Heterogeneous, Run-Time Reconfigurable LUT-Based Logic Neural Networks

**LiveLLNN** is a heterogeneous architecture designed for run-time reconfiguration on SoC FPGAs based on [LUT-Based Logic Neural Networks](https://github.com/capo-urjc/llnn) (LLNNs). By decoupling the network's structural interconnect from its learned logic parameters, LiveLLNN enables rapid model updates and weight adjustments purely via software, entirely eliminating the massive overhead of hardware re-synthesis.

## Architectural Overview

LiveLLNN leverages the hybrid architecture of modern SoC FPGAs (such as the Xilinx Zynq-7000 series) by efficiently partitioning the workload across the Processing System (PS) and Programmable Logic (PL):

1. **Static Soft-LUT Overlay (Programmable Logic):** 
   Instead of mapping fixed logic to generic FPGA resources, we construct a static interconnect DAG (Directed Acyclic Graph) derived from the topology of a trained logic neural network. The neurons are mapped to custom logic cells containing Xilinx `CFGLUT5` primitives. This establishes a specialized fabric of Look-Up Tables where the physical wiring is permanently fixed, but the Boolean function of every single neuron remains fully mutable.
   
2. **Memory-Mapped Control (Processing System):**
   An ARM processor securely communicates with the custom logic fabric via a memory-mapped AXI-Lite interface. The configuration ports (e.g., CDI/CE) of the embedded `CFGLUT5` primitives are aggregated and mapped to a specific address space. This allows the processor to serially shift new 32-bit truth tables into any targeted logic gate on-the-fly.
   
3. **Host-Side Training:** 
   The highly compute-intensive process of topological search and logic training (using differentiable logic frameworks like PyTorch) happens offline on a host machine. Once training is complete, the toolchain exports the physical overlay HDL logic rules alongside the learned truth tables (weights) in a compact format.

## Conceptual Workflow

The lifecycle of a LiveLLNN system operates in two completely separate time domains:

### Phase 1: Structural Synthesis (One-Time Cost)
A trained logic neural network model is parsed to extract its connectivity graph. The system generates a Verilog netlist instantiating the Soft-LUT overlay, routing the interconnects, and wrapping it within an AXI-addressable control module. The design is then synthesized into a static bitstream. This heavy physical implementation step happens exactly once for a given architecture topology.

### Phase 2: Run-Time Re-Programming (Zero-Synthesis Updates)
At run-time, the hardware loads the generated bitstream. When a new model is trained or updated weights are derived offline, they are exported into a binary weight file. The SoC processor parses this file and programs the internal truth tables of the network via direct memory writes. Forward-pass inference becomes sequential due to the `CFGLUT5` requiring a clk signal and blisteringly fast, while updating the weights across the entire network via the PS takes only a tiny fraction of a second.

This paves the way for continuous system on embedded edge devices which are capable of detecting concept drift, requesting offline retrains, and hot-swapping network parameters entirely in the field without ever invoking the massive synthesis toolchain.

## Setting up libraries and tools
```bash
# Set up model training and HDL generating
sudo apt install python3
sudo apt install python3-pip
pip3 install -r requirements.txt
```

We have set things up for a PYNQ-Z2 board, here are the [instructions](https://pynq.readthedocs.io/en/latest/getting_started/pynq_z2_setup.html) to set up the board. We are using the [CFGLUT5](https://docs.amd.com/r/en-US/ug953-vivado-7series-libraries/CFGLUT5) LUT for our example.
- Download PYNQ-Z2 board files: https://www.tulembedded.com/FPGA/ProductsPYNQ-Z2.html#:~:text=Z2%20Board%20File
- Extract and put them in a folder in root called `boards/tul/`
- Also the constraints file in the `constraint/` folder
- Make sure vivado is installed and added to path and `settings64.sh` is sourced

## Creating the models

The LiveLLNN project supports two distinct hardware generation flows. Both start from the same PyTorch models but diverge significantly at the HDL generation stage.

### Flow 1: Static LLNN
*Note: This flow bakes the truth tables directly into the static `case` statements of the generated HDL. Any change to the model requires a full Vivado re-synthesis.*
This flow is useful for putting the original Static LLNN architecture directly onto the PYNQ board.

```bash
# 1. Train a static model
python3 main.py --train --save --name model_static --dataset mnist20x20 -s 5 --num-iterations 1000

# 2. Test the trained model
python3 main.py --load --name model_static --dataset mnist20x20

# 3. Generate the static HDL code (VHDL depricated)
python3 main.py --load --sv --name model_static --dataset mnist20x20
```
Once step 3 is complete, you use `make build_overlay MODEL=model_static` to synthesize the static bitstream.

### Flow 2: Reconfigurable LLNN
*Note: This flow extracts the connectivity topological graph of a base model to generate a fabric of SoftLUT5 cells. Truth tables are exported as binaries to be hot-swapped over an AXI memory map at runtime, completely bypassing Vivado re-synthesis!*

To demonstrate hardware persistence and run-time orientation hot-swapping:

```bash
# 1. Train the base model on standard MNIST and EXPORT its wiring graph
python3 main.py --train --save --name model_base --dataset mnist20x20 -s 5 --num-iterations 1000 --export-wiring wiring/topo.json

# 2. Train a second model on rotated MNIST, explicitly LOADING the base wiring graph
python3 main.py --train --save --name model_rot --dataset mnist20x20_rotated -s 5 --num-iterations 1000 --wiring wiring/topo.json

# 3. Generate the Reconfigurable Overlay HDL (Only ever needs to be done once for model_base)
python3 hdl/generate_overlay.py --model model_base

# 4. Extract the software weights for both models
python3 scripts/extract_weights.py --model model_base
python3 scripts/extract_weights.py --model model_rot
```
Once step 3 is complete, you use `make build_reconfig MODEL=model_base` to synthesize the static bitstream. Once deployed to the PYNQ board, you can dynamically load the `weights.json` (or `weights.bin`) for either model into the PS and swap between recognizing standard and rotated MNIST in sub-milliseconds without touching Vivado!

## Synthesizing

### FPGA Build Flow (Vivado Makefile)

The repository includes a Makefile that automates the Vivado build process for creating the LLNN models for deployment on the PYNQ-Z2 FPGA. The Makefile wraps common Vivado Tcl flows for project creation, block design generation, synthesis, and overlay builds.

Before running any commands, ensure the Vivado environment is sourced:

```bash
# Example
source /tools/Xilinx/Vivado/<version>/settings64.sh
```

### Flow 3: Static LLNN FPGA Build

*Note: This flow synthesizes the HDL generated by main.py --sv directly into FPGA logic. Any change to the model requires a full Vivado re-build.*

This flow is used for deploying the static LLNN architecture where the truth tables are compiled directly into hardware.

```bash
# 1. Verify the generated HDL sources
make print-sources MODEL=model_static

# 2. Create the Vivado project and import all HDL sources
make project MODEL=model_static

# 3. Generate the Zynq block design (PS + PL integration)
make design MODEL=model_static

# 4. Build the FPGA bitstream (synthesis + implementation)
make build MODEL=model_static
```

The resulting artifacts will be placed in:

```bash
build/model_static/
```

Key outputs include:

```bash
top.bit
top.hwh
top.xsa
```

These can then be deployed to the PYNQ board for execution.

### Flow 4: Static LLNN Overlay Build

Instead of compiling the entire LLNN datapath as custom RTL, this flow builds the LLNN overlay fabric composed of SoftLUT5 cells.

```bash
make build_overlay MODEL=model_static
```

This runs the Vivado overlay flow defined in:

```bash
scripts/build_overlay.tcl
```

Outputs are written to:

```bash
build/model_static/overlay/
```

This produces the FPGA bitstream containing the SoftLUT5 LUT fabric overlay used by the LLNN accelerator.

### Flow 5: Reconfigurable LLNN Overlay Build

For the runtime-reconfigurable LLNN architecture, the FPGA only contains a fixed SoftLUT5 fabric. The actual LUT truth tables are loaded dynamically by the processor.

This allows models to be swapped without re-running Vivado.

First ensure the overlay HDL was generated:

```bash
python3 hdl/generate_overlay.py --model model_base
```

Then build the FPGA overlay:

```bash
make build_reconfig MODEL=model_base
```

This compiles the static FPGA fabric only once.

The output overlay bitstream will be placed in:

```bash
build/model_base/reconfig/
```

At runtime, the PYNQ processor can load different models by writing new LUT contents over AXI using the exported weight files.

Example runtime swap:

```bash
weights_base.json
weights_rot.json
```

Switching between them requires no FPGA reprogramming.


### Cleaning Build Outputs

To remove build artifacts for a specific model:

```bash
make clean MODEL=model_static
```

To remove all build outputs:

```bash
make clean
```

### Useful Debug Commands

Print all HDL sources detected by the build system:

```bash
make print-sources MODEL=model_static
```

Convert SystemVerilog sources to Verilog (for tools requiring Verilog):

```bash
make sv2v MODEL=model_static
```

Open the Vivado GUI project:

```bash
make open MODEL=model_static
```

## Running on Board

- `scp` the bitstreama andhardware handoff spec to the board
- Bitstream from `impl_1/` in your Vivado project
- HWH from from  `.gen/sources_1/bd/<bd_name>/hw_handoff/` in your Vivado project
- also `scp` all the files in the pynq_notebooks folder

## Importing LUTLayer

```python
import torch
from lutnn.lutlayer import LUTLayer, Aggregation

model = torch.nn.Sequential(
    torch.nn.Flatten(),
    LUTLayer(input_dim=1000, lut_size=6, n_luts=2048),
    LUTLayer(input_dim=2048, lut_size=6, n_luts=4000),
    Aggregation(num_classes=10, tau = 10)
)
```

## Background and Citations

This project is an architectural extension of the foundational LLNN concepts detailed in:

[LLNN: A Scalable LUT-Based Logic Neural Network Architecture for FPGAs](https://ieeexplore.ieee.org/abstract/document/11154450)

```bibtex
@ARTICLE{11154450,
  author={Ramírez, Iván and Garcia-Espinosa, Francisco J. and Concha, David and Aranda, Luis Alberto and Schiavi, Emanuele},
  journal={IEEE Transactions on Circuits and Systems I: Regular Papers}, 
  title={LLNN: A Scalable LUT-Based Logic Neural Network Architecture for FPGAs}, 
  year={2025},
  volume={},
  number={},
  pages={1-13},
  doi={10.1109/TCSI.2025.3606054}
}
```
