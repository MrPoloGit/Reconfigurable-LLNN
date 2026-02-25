#!/usr/bin/env python3
"""
extract_weights.py — Extract truth tables from a trained LLNN model.

This script is the bridge between PyTorch training (Phase 3) and the
PYNQ reconfiguration driver (Phase 4). It reads a trained .pth model,
performs argmax on the logits to harden each neuron's truth table,
and outputs a weights.json file matching the overlay's AXI address map.

Usage:
    python scripts/extract_weights.py --model simple_lutnn

Output:
    data/overlay/<name>/weights.json
    Format: { "gates": [ {"gate_id": 0, "init": 0x0000ABCD}, ... ] }
"""

import sys
import argparse
import json
import torch
import numpy as np
from pathlib import Path
import torch.nn.functional as F

sys.path.append(str(Path(__file__).parent.parent))
from lutnn.lutlayer import LUTLayer, Aggregation
from torch.nn import Flatten


def get_args():
    parser = argparse.ArgumentParser(description="Extract truth tables from trained LLNN.")
    parser.add_argument("--model", type=str, required=True,
                        help="Model name (stem of .pth in models/)")
    parser.add_argument("--name", type=str,
                        help="Overlay name (defaults to --model)")
    return parser.parse_args()


def extract_truth_tables(model):
    """
    For each LUTLayer, compute the hardened truth table:
        logits = stack(w, w_comp)
        rounded = round(softmax(logits, dim=0)[0])
        truth_table_int = sum( rounded[:, k] * 2^k  for k in range(2^lut_size) )

    Returns: list of (gate_id, init_value_32bit) tuples
    """
    gates = []
    gate_id = 0

    for layer in model.model:
        if isinstance(layer, LUTLayer):
            lut_size = layer.indices.shape[0]
            n_luts = layer.indices.shape[1]
            num_entries = 2 ** lut_size

            # Harden: softmax → round → packs into integer
            logits = torch.stack((layer.w, layer.w_comp), dim=0)
            w_round = torch.round(F.softmax(logits, dim=0)[0]).type(torch.int64)

            for neuron in range(n_luts):
                # Pack truth table bits into a single integer
                tt = 0
                for k in range(num_entries):
                    tt |= int(w_round[neuron, k].item()) << k

                # Zero-extend to 32 bits (LUT5 INIT width)
                # For LUT4 (16 entries): upper 16 bits are 0, I4 tied to 0
                gates.append({
                    "gate_id": gate_id,
                    "init": tt & 0xFFFFFFFF
                })
                gate_id += 1

        elif isinstance(layer, (Flatten, Aggregation)):
            pass
        else:
            raise ValueError(f"Unknown layer type: {type(layer)}")

    return gates


def main():
    args = get_args()
    name = args.name or args.model

    model_path = Path("models") / f"{args.model}.pth"
    if not model_path.exists():
        print(f"[weights] ERROR: Model not found: {model_path}")
        sys.exit(1)

    model = torch.load(model_path, weights_only=False, map_location="cpu")
    model.eval()

    gates = extract_truth_tables(model)

    # Write output
    out_dir = Path("data") / "overlay" / name
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "weights.json"

    output = {
        "model": args.model,
        "total_gates": len(gates),
        "gates": gates
    }

    with open(out_path, "w") as f:
        json.dump(output, f, indent=2)

    print(f"[weights] ✅ Extracted {len(gates)} truth tables → {out_path}")

    # Also write a compact binary file for fast loading
    bin_path = out_dir / "weights.bin"
    import struct
    with open(bin_path, "wb") as f:
        f.write(struct.pack("<I", len(gates)))  # header: gate count
        for g in gates:
            f.write(struct.pack("<I", g["init"]))  # 32-bit LE per gate
    print(f"[weights] ✅ Binary weights → {bin_path} ({bin_path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
