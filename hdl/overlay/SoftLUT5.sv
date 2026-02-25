// -------------------------------------------------------------------------------------
// SoftLUT5.sv — Reconfigurable Logic Cell for LLNN Overlay
// Wraps the Xilinx CFGLUT5 primitive (available in SLICEM sites on 7-Series)
//
// Usage:
//   - lut_in[4:0] are the 5 data inputs (tie I4=0 for LUT4 compatibility)
//   - lut_out is the combinational LUT output (O6)
//   - To reprogram: assert cfg_ce, clock in 32 bits on cfg_data (LSB first)
//   - cfg_out carries the displaced bit (for optional daisy-chaining)
// -------------------------------------------------------------------------------------

module SoftLUT5 (
    input logic clk,

    // Data path (combinational)
    input  logic [4:0] lut_in,
    output logic       lut_out,

    // Configuration interface (directly from AXI controller)
    input  logic cfg_ce,
    input  logic cfg_data,
    output logic cfg_out
);

  // Prevent Vivado from optimizing away the reconfigurable LUT
  (* dont_touch = "true", LOCK_PINS = "all" *)
  CFGLUT5 #(
      .INIT(32'h0000_0000)  // Power-on default (overwritten at runtime by PS)
  ) cfglut_inst (
      .O5 (),           // LUT4 output (unused — we use O6 for full LUT5)
      .O6 (lut_out),    // LUT5 output: INIT[{I4,I3,I2,I1,I0}]
      .I0 (lut_in[0]),
      .I1 (lut_in[1]),
      .I2 (lut_in[2]),
      .I3 (lut_in[3]),
      .I4 (lut_in[4]),  // Tie to 0 externally for LUT4 mode
      .CDI(cfg_data),   // Configuration Data In  (serial, LSB first)
      .CDO(cfg_out),    // Configuration Data Out (daisy-chain)
      .CE (cfg_ce),     // Configuration Enable
      .CLK(clk)         // Configuration Clock
  );

endmodule
