# Vivado Workflow
- Download PYNQ-Z2 board files: https://www.tulembedded.com/FPGA/ProductsPYNQ-Z2.html#:~:text=Z2%20Board%20File
    - Extract and put them in `<your vivado installation>/Vivado/<version>/data/boards/board_files`
    - If board_files doesn't exist create the folder, if tul folder isn't in board_files create it too.

- Create new Vivado project, including the hdl folder of the repo as sources
    - I'm not sure if it was necessary, but I added the constraints file: https://www.tulembedded.com/FPGA/ProductsPYNQ-Z2.html#:~:text=Z2%20Board%20File
    - I'm pretty sure it would work without it
- Follow this tutorial to create a block diagram with buttons hooked up to LEDs
    - https://digilent.com/reference/vivado/getting-started-with-ipi/2018.2
    - IMPORTANT: You can stop at the step where you generate the bitstream. We don't have to use Vitis to connect the Processing System (PS) to the Programmable Logic (PL)
- `scp` the bitstream and hardware handoff spec to the board
    - Bitstream from `impl_1/` in your Vivado project
    - HWH from from  `.gen/sources_1/bd/<bd_name>/hw_handoff/` in your Vivado project
    - `scp llnn.bit llnn.hwh xilinx@<pynq-ip>:~/`
- Create a Python notebook to load the bitstream and coordinate the MMIO

```python
from pynq import Overlay
ol = Overlay("/home/xilinx/first_llnn_wrapper.bit")  # loads bitstream + parses .hwh

print(ol.ip_dict.keys()) 
# should print something like " dict_keys(['axi_gpio_0', 'axi_gpio_1', 'processing_system7_0'])"

from pynq.lib import AxiGPIO
import time
btns = AxiGPIO(ol.ip_dict['axi_gpio_0']).channel1
leds = AxiGPIO(ol.ip_dict['axi_gpio_0']).channel2
while True:
    leds.write(btns.read(), 0xF)
    time.sleep(0.1)
```

- Pressing the four buttons on the PYNQ board should light up the corresponding LED! You can also write directly to the addresses that the GPIO AXI buses read from:

```python
from pynq import mmio
gpio_addr = ol.ip_dict['axi_gpio_0']['phys_addr']
mmio = MMIO(gpio_addr, 0x10000)
mmio.write(0x000C, 0x0)  # direction = output
mmio.write(0x0008, 0xF)  # all 4 LEDs on, writing 4'b1111
```