#!/usr/bin/env python3
"""
pynq_driver.py — PYNQ-side driver for the LLNN Reconfigurable Overlay

Runs on the ARM core of the PYNQ-Z2. Handles:
  1. Loading the overlay bitstream
  2. Programming gate truth tables via MMIO (AXI-Lite)
  3. Running inference on binarized input samples

Usage (on the PYNQ board):
    python3 pynq_driver.py --overlay llnn_overlay.bit --weights weights.json

AXI Address Map (matches axi_lut_ctrl.sv):
    0x0000–0x1FFF : Gate programming  (write gate_id * 4 = 32-bit truth table)
    0x2000        : STATUS            (bit 0 = cfg_busy)
    0x2004        : TOTAL_GATES       (read-only)
    0x3000–0x3030 : NET_I input regs  (13 × 32-bit words)
    0x3034        : NET_O output reg  (lower 4 bits = classification)
"""

import json
import struct
import time
import argparse
import numpy as np

# PYNQ imports (only available on the board)
try:
    from pynq import Overlay, MMIO
    PYNQ_AVAILABLE = True
except ImportError:
    PYNQ_AVAILABLE = False
    print("[driver] WARNING: pynq not available — running in dry-run mode")


# =============================================================================
#  AXI Address Map Constants
# =============================================================================
ADDR_GATE_BASE   = 0x0000
ADDR_STATUS      = 0x2000
ADDR_GATE_COUNT  = 0x2004
ADDR_INPUT_BASE  = 0x3000
ADDR_OUTPUT      = 0x3034
TOTAL_ADDR_SPACE = 0x4000  # 16KB


class LLNNOverlay:
    """High-level driver for the LLNN reconfigurable overlay."""

    def __init__(self, bitstream_path):
        """Load the overlay bitstream and initialize MMIO."""
        print(f"[driver] Loading overlay: {bitstream_path}")
        self.ol = Overlay(bitstream_path)
        # MMIO to the AXI-Lite slave (address assigned by Vivado, typically 0x43C00000)
        # The exact base address comes from the .hwh file, which PYNQ parses automatically.
        # We access it via the IP dict:
        ip_name = list(self.ol.ip_dict.keys())[0]
        base_addr = self.ol.ip_dict[ip_name]['phys_addr']
        self.mmio = MMIO(base_addr, TOTAL_ADDR_SPACE)
        self.total_gates = self.mmio.read(ADDR_GATE_COUNT)
        print(f"[driver] Overlay loaded. Total gates: {self.total_gates}")

    def is_busy(self):
        """Check if the configuration controller is busy."""
        return bool(self.mmio.read(ADDR_STATUS) & 0x1)

    def wait_ready(self, timeout_ms=100):
        """Wait for the configuration controller to finish."""
        start = time.time()
        while self.is_busy():
            if (time.time() - start) * 1000 > timeout_ms:
                raise TimeoutError("Config controller busy timeout")
            time.sleep(0.0001)

    def program_gate(self, gate_id, truth_table):
        """Program a single gate with a 32-bit truth table."""
        self.wait_ready()
        self.mmio.write(ADDR_GATE_BASE + gate_id * 4, truth_table & 0xFFFFFFFF)

    def program_all_gates(self, truth_tables):
        """
        Program all gates from a list of truth table integers.
        truth_tables[i] = 32-bit INIT value for gate i.
        """
        print(f"[driver] Programming {len(truth_tables)} gates...")
        t0 = time.time()
        for gate_id, tt in enumerate(truth_tables):
            self.program_gate(gate_id, tt)
        elapsed = (time.time() - t0) * 1000
        print(f"[driver] ✅ All gates programmed in {elapsed:.1f} ms")

    def load_weights_json(self, json_path):
        """Load truth tables from a weights.json file."""
        with open(json_path) as f:
            data = json.load(f)
        truth_tables = [0] * data["total_gates"]
        for gate in data["gates"]:
            truth_tables[gate["gate_id"]] = gate["init"]
        self.program_all_gates(truth_tables)

    def load_weights_bin(self, bin_path):
        """Load truth tables from a weights.bin file (faster)."""
        with open(bin_path, "rb") as f:
            count = struct.unpack("<I", f.read(4))[0]
            truth_tables = list(struct.unpack(f"<{count}I", f.read(count * 4)))
        self.program_all_gates(truth_tables)

    def run_inference(self, input_bits):
        """
        Run inference on a binarized input sample.

        Args:
            input_bits: numpy array or list of 0/1 values, length = NET_INPUTS (e.g., 400)

        Returns:
            int: predicted class (0–9 for MNIST)
        """
        # Pack input bits into 32-bit words and write to input registers
        input_bits = np.array(input_bits, dtype=np.uint32)
        num_words = (len(input_bits) + 31) // 32
        for w in range(num_words):
            start = w * 32
            end = min(start + 32, len(input_bits))
            word = 0
            for b in range(start, end):
                word |= int(input_bits[b]) << (b - start)
            self.mmio.write(ADDR_INPUT_BASE + w * 4, word)

        # Read output (combinational — available immediately)
        result = self.mmio.read(ADDR_OUTPUT) & 0xF
        return result

    def run_batch_inference(self, samples, labels=None):
        """
        Run inference on a batch of samples and optionally compute accuracy.

        Args:
            samples: 2D array [N, NET_INPUTS] of binarized inputs
            labels:  1D array [N] of ground-truth labels (optional)

        Returns:
            predictions: list of predicted classes
            accuracy: float (if labels provided, else None)
        """
        predictions = []
        for i, sample in enumerate(samples):
            pred = self.run_inference(sample)
            predictions.append(pred)

        if labels is not None:
            correct = sum(p == l for p, l in zip(predictions, labels))
            accuracy = correct / len(labels)
            print(f"[driver] Accuracy: {correct}/{len(labels)} = {accuracy:.4f}")
            return predictions, accuracy

        return predictions, None


# =============================================================================
#  CLI Entry Point
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description="PYNQ driver for LLNN overlay")
    parser.add_argument("--overlay", type=str, required=True,
                        help="Path to .bit file")
    parser.add_argument("--weights", type=str, required=True,
                        help="Path to weights.json or weights.bin")
    parser.add_argument("--test-data", type=str,
                        help="Optional: path to test data for accuracy check")
    args = parser.parse_args()

    if not PYNQ_AVAILABLE:
        print("[driver] ERROR: Must run on the PYNQ board (pynq library required)")
        return

    # Load overlay
    driver = LLNNOverlay(args.overlay)

    # Program gates
    if args.weights.endswith(".bin"):
        driver.load_weights_bin(args.weights)
    else:
        driver.load_weights_json(args.weights)

    # Optional: test inference
    if args.test_data:
        data = np.load(args.test_data)
        samples = data["inputs"]
        labels = data["labels"]
        driver.run_batch_inference(samples, labels)
    else:
        print("[driver] Ready for inference. Use LLNNOverlay.run_inference().")


if __name__ == "__main__":
    main()
