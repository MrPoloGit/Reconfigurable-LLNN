# AGENTS.md - Heterogeneous Logic Neural Network (LLNN) Implementation

## 1. Mission Profile
**Objective:** Deploy a Heterogeneous, Run-Time Reconfigurable Logic Neural Network on the PYNQ-Z2.
**Role:** HDL & Firmware Architect (Offline Mode).
**Hardware Target:** PYNQ-Z2 (Xilinx Zynq-7020 SoC).
**Network Context:**
- **Board IP:** `192.168.0.12` (User manages SSH connection manually).
- **Credentials:** `xilinx` / `xilinx`.
- **Constraint:** The Agent **DOES NOT** execute SSH commands directly. The Agent **GENERATES** scripts/files, and the User executes them.

---

## 2. Core Architecture
1.  **Overlay Approach:** We are building a static **Soft-LUT Overlay**.
    - **Logic:** `SoftLUT5` modules wrapping Xilinx `CFGLUT5` primitives (runtime-reconfigurable).
    - **Interconnect:** A fixed, random DAG generated once by Python from the trained model.
    - **Configuration:** AXI-Lite slave allows the ARM core to rewrite truth tables via serial CDI/CE interface without re-synthesis.
2.  **Heterogeneity:**
    - **Host (PC):** Trains `difflogic` models in PyTorch → Exports `weights.json`/`weights.bin` + overlay HDL.
    - **PS (ARM):** Loads `overlay.bit`, reads `weights.bin`, writes truth tables to AXI.
    - **PL (FPGA):** Executes combinational inference using the current truth tables.
3.  **AXI Address Map (16KB):**
    - `0x0000–0x1FFF`: Gate programming (write `gate_id * 4` = 32-bit truth table)
    - `0x2000`: STATUS (R) — bit 0 = cfg_busy
    - `0x2004`: TOTAL_GATES (R)
    - `0x3000–0x3030`: NET_I input registers (13 × 32-bit words)
    - `0x3034`: NET_O output register (R) — lower 4 bits = classification

---

## 3. Implementation Phases

### Phase 1: The Hardware Primitive (`SoftLUT5.sv`) ✅ DONE
*Goal: Create the reconfigurable logic cell.*
- [x] **`hdl/overlay/SoftLUT5.sv`:** Wraps `CFGLUT5` primitive with `dont_touch` attribute.
    - Input: `[4:0] lut_in` (5 data inputs; tie I4=0 for LUT4-mode compatibility).
    - Config: `cfg_ce`, `cfg_data` (serial, LSB-first, 32 cycles to reprogram).
    - Output: `lut_out` (combinational LUT5 output via O6).

### Phase 2: The Network Generator (`generate_overlay.py`) ✅ DONE
*Goal: Convert a PyTorch model into a reconfigurable Verilog netlist.*
- [x] **`hdl/generate_overlay.py`:**
    - Loads trained model, extracts wiring (connectivity DAG) only.
    - Generates `Globals.sv`, `top.sv`, `layerN.sv`, `comparator.sv`.
    - Each neuron → `SoftLUT5` instance with static wiring, dynamic truth tables.
    - Per-layer CE decode via generate block (`cfg_gate_sel == GATE_BASE + g`).
    - Exports `wiring_map.json` for the PYNQ driver.
- [x] **`hdl/overlay/axi_lut_ctrl.sv`:** AXI-Lite slave that:
    - Latches gate_id from address, truth_table from data.
    - Shifts out 32 bits serially (LSB first) to the selected CFGLUT5.
    - Hosts input/output registers for inference I/O.
- [x] **`hdl/build_overlay.tcl`:** Vivado Tcl automation for the full flow
    (create project → block design with Zynq PS → AXI interconnect → synth → bitstream).

### Phase 3: Truth Table Extraction ✅ DONE
- [x] **`scripts/extract_weights.py`:**
    - `softmax(w, w_comp) → round → argmax` per neuron.
    - Outputs `weights.json` and `weights.bin` (compact binary, 4 bytes/gate).

### Phase 4: The Runtime Driver (`pynq_driver.py`) ✅ DONE
- [x] **`scripts/pynq_driver.py`:**
    - `LLNNOverlay` class with `program_gate()`, `load_weights_json()`, `run_inference()`.
    - MMIO-based: `mmio.write(gate_id * 4, truth_table)` per gate.
    - Batch inference with accuracy reporting.

### Phase 5: The "Agentic" Loop (Self-Healing) — PENDING
- [ ] Drift test (rotate MNIST test set).
- [ ] Detect accuracy drop.
- [ ] Retrain → extract new weights → `program_all_gates()` → verify recovery.

---

## 4. File Map

| File | Purpose |
|------|---------|
| `hdl/overlay/SoftLUT5.sv` | CFGLUT5-backed reconfigurable LUT cell |
| `hdl/overlay/axi_lut_ctrl.sv` | AXI-Lite slave + serial shift controller |
| `hdl/generate_overlay.py` | Generates overlay HDL from trained PyTorch model |
| `hdl/build_overlay.tcl` | Vivado Tcl build automation |
| `hdl/convert2sv.py` | **LEGACY** — static LUT export (Golden Reference) |
| `scripts/extract_weights.py` | Extracts truth tables from trained model |
| `scripts/pynq_driver.py` | PYNQ-side overlay + inference driver |
| `data/overlay/<name>/` | Generated HDL + weights per model |
| `data/sv/<name>/` | Legacy static HDL output |

---

## 5. Operational Rules
1.  **Code Only:** Do not attempt `ping` or `ssh`. Just write the code/scripts.
2.  **No GUI:** Write Tcl for Vivado, never ask to open the GUI.
3.  **Incremental:** Do not proceed to Phase 5 until bitstream is verified (blinky/AXI test).
4.  **Resource Awareness:** PYNQ-Z2 has ~17,400 SLICEMs. If CFGLUT5 count exceeds limit, fall back to BRAM-backed MUX.

---

## 6. Agent Learnings
- `test_model.pth`: 2 layers × 2000 neurons, LUT2 (2 inputs each), 4000 total gates, 10 classes, 400 inputs.
- `test_lut6.pth`: Exists but untested (likely larger LUT size).
- The `venv/` directory contains PyTorch and dependencies. Always activate it before running Python scripts.
- Board at `192.168.0.12` is reachable via ping. SSH works with password auth (`xilinx`/`xilinx`). No SSH key is set up.
- `CFGLUT5` serial config is LSB-first, 32 cycles for LUT5, CE must be held high during shift.