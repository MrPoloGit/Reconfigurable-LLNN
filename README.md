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
At run-time, the hardware loads the generated bitstream. When a new model is trained or updated weights are derived offline, they are exported into a binary weight file. The SoC processor parses this file and programs the internal truth tables of the network via direct memory writes. Forward-pass inference remains purely combinational and blisteringly fast, while updating the weights across the entire network via the PS takes only a tiny fraction of a second.

This paves the way for continuous, "Self-Healing" agentic systems on embedded edge devices—capable of detecting concept drift, requesting offline retrains, and hot-swapping network parameters entirely in the field without ever invoking the massive synthesis toolchain.


## Running

In python environment

```bash
python main.py --help
python -m venv venv

# Windows
source venv/Scripts/activate

# MacOS and Linux
source venv/bin/activate

pip install -e .
pip install -r requirements.txt
python main.py --train --save --name model1 --dataset mnist --batch-size 128 -lr 0.01 --num-iterations 10000
python main.py --load --name model1 --dataset mnist
python main.py --load --vhdl --name model1 --dataset mnist
python main.py --load --sv --name model1 --dataset mnist
```

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

## Train a model

`python main.py --train --save --name model1 --dataset mnist --batch-size 128 -lr 0.01 --num-iterations 10000`

## Test a trained model

`python main.py --load --name model1 --dataset mnist`

## Background and Citations

This project is an architectural extension of the foundational LLNN concepts detailed in:

[LLNN: A Scalable LUT-Based Logic Neural Network Architecture for FPGAs](https://ieeexplore.ieee.org/abstract/document/11154450)

If you build upon the core LLNN functionality, please cite:

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
