// // -------------------------------------------------------------------------------------
// // softlut5_test_wrapper.sv — Minimal test: one SoftLUT5 + AXI controller
// //
// // This is a sanity-check design to verify the CFGLUT5 primitive works on
// // the PYNQ-Z2 before building the full 1512-gate overlay.
// //
// // AXI Address Map (via axi_lut_ctrl, 64KB):
// //   0x0000       : Gate 0 truth table (write 32-bit INIT value)
// //   0x8000       : STATUS (R) — bit 0 = cfg_busy
// //   0x8004       : TOTAL_GATES (R) — returns 1
// //   0x9000       : NET_I input register (only bits [4:0] used)
// //   0x9004       : NET_O output register (R) — bit 0 = LUT output
// // -------------------------------------------------------------------------------------

// module softlut5_test_wrapper (
//     input  logic        clk,
//     input  logic        rst_n,
//     // AXI-Lite slave
//     input  logic [15:0] S_AXI_AWADDR,
//     input  logic        S_AXI_AWVALID,
//     output logic        S_AXI_AWREADY,
//     input  logic [31:0] S_AXI_WDATA,
//     input  logic [3:0]  S_AXI_WSTRB,
//     input  logic        S_AXI_WVALID,
//     output logic        S_AXI_WREADY,
//     output logic [1:0]  S_AXI_BRESP,
//     output logic        S_AXI_BVALID,
//     input  logic        S_AXI_BREADY,
//     input  logic [15:0] S_AXI_ARADDR,
//     input  logic        S_AXI_ARVALID,
//     output logic        S_AXI_ARREADY,
//     output logic [31:0] S_AXI_RDATA,
//     output logic [1:0]  S_AXI_RRESP,
//     output logic        S_AXI_RVALID,
//     input  logic        S_AXI_RREADY
// );

//     // ── Parameters ─────────────────────────────────────────────────────
//     localparam TOTAL_GATES = 1;
//     localparam NET_INPUTS  = 5;   // 5 LUT inputs
//     localparam NET_OUTPUTS = 1;   // 1 LUT output
//     localparam GATE_SEL_W  = 1;   // (TOTAL_GATES > 1) ? clog2 : 1

//     // ── Internal wires ─────────────────────────────────────────────────
//     logic [NET_INPUTS-1:0]  net_i;
//     logic [NET_OUTPUTS-1:0] net_o;
//     logic [GATE_SEL_W-1:0]  cfg_gate_sel;
//     logic                   cfg_ce;
//     logic                   cfg_data;

//     // ── AXI controller ─────────────────────────────────────────────────
//     axi_lut_ctrl #(
//         .TOTAL_GATES (TOTAL_GATES),
//         .NET_INPUTS  (NET_INPUTS),
//         .NET_OUTPUTS (NET_OUTPUTS),
//         .ADDR_W      (16),
//         .DATA_W      (32)
//     ) u_axi (
//         .S_AXI_ACLK    (clk),
//         .S_AXI_ARESETN (rst_n),
//         .S_AXI_AWADDR  (S_AXI_AWADDR),
//         .S_AXI_AWVALID (S_AXI_AWVALID),
//         .S_AXI_AWREADY (S_AXI_AWREADY),
//         .S_AXI_WDATA   (S_AXI_WDATA),
//         .S_AXI_WSTRB   (S_AXI_WSTRB),
//         .S_AXI_WVALID  (S_AXI_WVALID),
//         .S_AXI_WREADY  (S_AXI_WREADY),
//         .S_AXI_BRESP   (S_AXI_BRESP),
//         .S_AXI_BVALID  (S_AXI_BVALID),
//         .S_AXI_BREADY  (S_AXI_BREADY),
//         .S_AXI_ARADDR  (S_AXI_ARADDR),
//         .S_AXI_ARVALID (S_AXI_ARVALID),
//         .S_AXI_ARREADY (S_AXI_ARREADY),
//         .S_AXI_RDATA   (S_AXI_RDATA),
//         .S_AXI_RRESP   (S_AXI_RRESP),
//         .S_AXI_RVALID  (S_AXI_RVALID),
//         .S_AXI_RREADY  (S_AXI_RREADY),
//         .cfg_gate_sel  (cfg_gate_sel),
//         .cfg_ce        (cfg_ce),
//         .cfg_data      (cfg_data),
//         .net_i         (net_i),
//         .net_o         (net_o)
//     );

//     // ── Single SoftLUT5 ────────────────────────────────────────────────
//     // Gate 0 is the only gate, so CE is active whenever cfg_gate_sel == 0
//     // (which is always, since TOTAL_GATES=1). The axi_lut_ctrl handles
//     // the gate-select decode internally — cfg_ce is only high during the
//     // SHIFTING state.

//     logic cfg_out_unused;

//     SoftLUT5 u_lut (
//         .clk      (clk),
//         .lut_in   (net_i),
//         .lut_out  (net_o[0]),
//         .cfg_ce   (cfg_ce),          // From AXI controller shift FSM
//         .cfg_data (cfg_data),        // Serial config data (MSB first)
//         .cfg_out  (cfg_out_unused)   // CDO — unused for single LUT
//     );

// endmodule


module softlut5_test_wrapper (
    input  logic        clk,
    input  logic        rst_n,

    // AXI-Lite slave
    input  logic [15:0] S_AXI_AWADDR,
    input  logic        S_AXI_AWVALID,
    output logic        S_AXI_AWREADY,
    input  logic [31:0] S_AXI_WDATA,
    input  logic [3:0]  S_AXI_WSTRB,
    input  logic        S_AXI_WVALID,
    output logic        S_AXI_WREADY,
    output logic [1:0]  S_AXI_BRESP,
    output logic        S_AXI_BVALID,
    input  logic        S_AXI_BREADY,
    input  logic [15:0] S_AXI_ARADDR,
    input  logic        S_AXI_ARVALID,
    output logic        S_AXI_ARREADY,
    output logic [31:0] S_AXI_RDATA,
    output logic [1:0]  S_AXI_RRESP,
    output logic        S_AXI_RVALID,
    input  logic        S_AXI_RREADY
);

    // ─────────────────────────────────────────────
    // LUT inputs / outputs
    // ─────────────────────────────────────────────
    logic [4:0] net_i;
    logic [0:0] net_o;

    // ─────────────────────────────────────────────
    // Config registers
    // ─────────────────────────────────────────────
    logic [31:0] cfg_shift_reg;
    logic [5:0]  cfg_count;
    logic        cfg_busy;

    logic cfg_ce;
    logic cfg_data;

    // ─────────────────────────────────────────────
    // AXI registers
    // ─────────────────────────────────────────────

    logic write_truth;

    assign write_truth = (S_AXI_AWVALID && S_AXI_WVALID &&
                         (S_AXI_AWADDR[15:0] == 16'h0000));

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cfg_shift_reg <= 0;
            cfg_count <= 0;
            cfg_busy <= 0;
        end
        else begin

            // Start shifting when PS writes truth table
            if (write_truth && !cfg_busy) begin
                cfg_shift_reg <= S_AXI_WDATA;
                cfg_count <= 6'd32;
                cfg_busy <= 1;
            end

            // Shift operation
            else if (cfg_busy) begin
                cfg_shift_reg <= {cfg_shift_reg[30:0],1'b0};
                cfg_count <= cfg_count - 1;

                if (cfg_count == 1)
                    cfg_busy <= 0;
            end
        end
    end

    assign cfg_ce   = cfg_busy;
    assign cfg_data = cfg_shift_reg[31];  // MSB first

    // ─────────────────────────────────────────────
    // LUT instance
    // ─────────────────────────────────────────────

    logic cfg_out_unused;

    (* DONT_TOUCH = "yes" *) SoftLUT5 u_lut (
        .clk      (clk),
        .lut_in   (net_i),
        .lut_out  (net_o[0]),
        .cfg_ce   (cfg_ce),
        .cfg_data (cfg_data),
        .cfg_out  (cfg_out_unused)
    );

endmodule