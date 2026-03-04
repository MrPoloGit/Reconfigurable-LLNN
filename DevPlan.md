# Dev Plan
1. Get PYNQ board setup
2. Get base LLNN synthesized onto PYNQ, verifying our generated SV
    1. Hello World on PYNQ: blink an LED
    2. sv2v on generated LUTs
        1. Simulate?
    3. Create packaged overlay in Vivado IP Viewer
    4. Create Python Notebook for processing data on PYNQ
        1. How do you load data onto PYNQ?
    5. Test accuracy?
3. Create new architecture
    1. Generate HDL from PyTorch model (from ipynb results)
        1. Top mod
            1. SoftLUTs, constrained by PyTorch model connections
        2. AXI-lite handler
        3. Do we need clocks?
    2. Generate LUT INITs
        1. PyTorch tensor storage?
        2. JSON, PT?
    3. Integrate BRAM and LUT connections in Vivado IP Manager
        1. Creates PYNQ Overlay
    4. Create Python Notebook to handle data (see 2d)
    5. Test accuracy?
4. Rotated MNIST????
