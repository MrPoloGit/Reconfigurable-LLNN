// =============================================================================
// tb_axi_lut_ctrl.sv — Testbench for axi_lut_ctrl_hard AXI-Lite slave
//
// Tests:
//   1. Single read from output register (no prior writes)
//   2. Single write (AW and W simultaneous)
//   3. Single write (AW before W)
//   4. Single write (W before AW)
//   5. Read-back of input register
//   6. Burst-style: write all 13 input registers, then read output
//
// Run in Vivado:
//   In the Tcl console:
//     add_files -fileset sim_1 hdl/tb_axi_lut_ctrl.sv
//     set_property top tb_axi_lut_ctrl [get_filesets sim_1]
//     launch_simulation
// =============================================================================

`timescale 1ns / 1ps

module tb_axi_lut_ctrl;

  // ── Parameters ──────────────────────────────────────────────────────────
  localparam ADDR_W      = 14;
  localparam DATA_W      = 32;
  localparam NET_INPUTS  = 400;
  localparam NET_OUTPUTS = 4;
  localparam CLK_PERIOD  = 40;  // 25 MHz (matches your FCLK_CLK0)

  // ── DUT signals ─────────────────────────────────────────────────────────
  logic                 clk = 0;
  logic                 rst_n = 0;

  logic [ADDR_W-1:0]   awaddr;
  logic                 awvalid = 0;
  logic                 awready;

  logic [DATA_W-1:0]   wdata;
  logic [3:0]           wstrb = 4'hF;
  logic                 wvalid = 0;
  logic                 wready;

  logic [1:0]           bresp;
  logic                 bvalid;
  logic                 bready = 0;

  logic [ADDR_W-1:0]   araddr;
  logic                 arvalid = 0;
  logic                 arready;

  logic [DATA_W-1:0]   rdata;
  logic [1:0]           rresp;
  logic                 rvalid;
  logic                 rready = 0;

  logic [NET_INPUTS-1:0]  net_i;
  logic [NET_OUTPUTS-1:0] net_o;

  // ── Hardwire net_o from net_i for testing (no real network) ─────────
  // Just XOR-reduce the first 4 bits so the output changes with input
  assign net_o = net_i[3:0] ^ net_i[7:4];

  // ── DUT ─────────────────────────────────────────────────────────────────
  axi_lut_ctrl_hard #(
    .NET_INPUTS  (NET_INPUTS),
    .NET_OUTPUTS (NET_OUTPUTS),
    .ADDR_W      (ADDR_W),
    .DATA_W      (DATA_W)
  ) dut (
    .S_AXI_ACLK    (clk),
    .S_AXI_ARESETN (rst_n),
    .S_AXI_AWADDR  (awaddr),
    .S_AXI_AWVALID (awvalid),
    .S_AXI_AWREADY (awready),
    .S_AXI_WDATA   (wdata),
    .S_AXI_WSTRB   (wstrb),
    .S_AXI_WVALID  (wvalid),
    .S_AXI_WREADY  (wready),
    .S_AXI_BRESP   (bresp),
    .S_AXI_BVALID  (bvalid),
    .S_AXI_BREADY  (bready),
    .S_AXI_ARADDR  (araddr),
    .S_AXI_ARVALID (arvalid),
    .S_AXI_ARREADY (arready),
    .S_AXI_RDATA   (rdata),
    .S_AXI_RRESP   (rresp),
    .S_AXI_RVALID  (rvalid),
    .S_AXI_RREADY  (rready),
    .net_i         (net_i),
    .net_o         (net_o)
  );

  // ── Clock ───────────────────────────────────────────────────────────────
  always #(CLK_PERIOD/2) clk = ~clk;

  // ── AXI task: write with AW+W simultaneous ─────────────────────────────
  task axi_write_sim(input [ADDR_W-1:0] addr, input [DATA_W-1:0] data);
    @(posedge clk);
    awaddr  = addr;
    awvalid = 1;
    wdata   = data;
    wvalid  = 1;
    bready  = 1;
    // Wait for both READY
    fork
      begin : aw_wait
        while (!awready) @(posedge clk);
        @(posedge clk); awvalid = 0;
      end
      begin : w_wait
        while (!wready) @(posedge clk);
        @(posedge clk); wvalid = 0;
      end
    join
    // Wait for BVALID
    while (!bvalid) @(posedge clk);
    @(posedge clk);
    bready = 0;
  endtask

  // ── AXI task: write with AW first, then W (serialized) ─────────────────
  task axi_write_aw_first(input [ADDR_W-1:0] addr, input [DATA_W-1:0] data);
    // Phase 1: AW only
    @(posedge clk);
    awaddr  = addr;
    awvalid = 1;
    wvalid  = 0;
    bready  = 1;
    while (!awready) @(posedge clk);
    @(posedge clk);
    awvalid = 0;
    // Phase 2: W only (delay 2 cycles to stress-test)
    @(posedge clk);
    @(posedge clk);
    wdata  = data;
    wvalid = 1;
    while (!wready) @(posedge clk);
    @(posedge clk);
    wvalid = 0;
    // Wait for BVALID
    while (!bvalid) @(posedge clk);
    @(posedge clk);
    bready = 0;
  endtask

  // ── AXI task: write with W first, then AW (serialized) ─────────────────
  task axi_write_w_first(input [ADDR_W-1:0] addr, input [DATA_W-1:0] data);
    // Phase 1: W only
    @(posedge clk);
    wdata  = data;
    wvalid = 1;
    awvalid = 0;
    bready  = 1;
    while (!wready) @(posedge clk);
    @(posedge clk);
    wvalid = 0;
    // Phase 2: AW only (delay 2 cycles)
    @(posedge clk);
    @(posedge clk);
    awaddr  = addr;
    awvalid = 1;
    while (!awready) @(posedge clk);
    @(posedge clk);
    awvalid = 0;
    // Wait for BVALID
    while (!bvalid) @(posedge clk);
    @(posedge clk);
    bready = 0;
  endtask

  // ── AXI task: read ─────────────────────────────────────────────────────
  task axi_read(input [ADDR_W-1:0] addr, output [DATA_W-1:0] data);
    @(posedge clk);
    araddr  = addr;
    arvalid = 1;
    rready  = 1;
    while (!arready) @(posedge clk);
    @(posedge clk);
    arvalid = 0;
    while (!rvalid) @(posedge clk);
    data = rdata;
    @(posedge clk);
    rready = 0;
  endtask

  // ── Test sequence ──────────────────────────────────────────────────────
  logic [DATA_W-1:0] rd_data;
  integer pass_count = 0;
  integer fail_count = 0;
  integer test_num   = 0;

  task check(input string name, input [DATA_W-1:0] expected, input [DATA_W-1:0] actual);
    test_num++;
    if (actual === expected) begin
      $display("  [PASS] Test %0d: %s — got 0x%08X", test_num, name, actual);
      pass_count++;
    end else begin
      $display("  [FAIL] Test %0d: %s — expected 0x%08X, got 0x%08X", test_num, name, expected, actual);
      fail_count++;
    end
  endtask

  initial begin
    $display("\n========================================");
    $display(" AXI-Lite Controller Testbench");
    $display("========================================\n");

    // Reset
    rst_n = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);

    // ── Test 1: Read output register (all inputs zero after reset) ───
    $display("[Test Group 1] Read output after reset");
    axi_read(14'h3034, rd_data);
    check("Read NET_O after reset", 32'h0, rd_data);

    // ── Test 2: Write (AW+W simultaneous) ────────────────────────────
    $display("[Test Group 2] Write with AW+W simultaneous");
    axi_write_sim(14'h3000, 32'hCAFE_0001);
    axi_read(14'h3000, rd_data);
    check("Read-back reg[0] after sim write", 32'hCAFE_0001, rd_data);

    // ── Test 3: Write (AW before W) ──────────────────────────────────
    $display("[Test Group 3] Write with AW before W");
    axi_write_aw_first(14'h3004, 32'hBEEF_0002);
    axi_read(14'h3004, rd_data);
    check("Read-back reg[1] after AW-first write", 32'hBEEF_0002, rd_data);

    // ── Test 4: Write (W before AW) ──────────────────────────────────
    $display("[Test Group 4] Write with W before AW");
    axi_write_w_first(14'h3008, 32'hDEAD_0003);
    axi_read(14'h3008, rd_data);
    check("Read-back reg[2] after W-first write", 32'hDEAD_0003, rd_data);

    // ── Test 5: Write all 13 registers + read output ─────────────────
    $display("[Test Group 5] Write all 13 input registers, read output");
    for (int i = 0; i < 13; i++) begin
      axi_write_sim(14'h3000 + i*4, i == 0 ? 32'h0000_00FF : 32'h0);
    end
    axi_read(14'h3034, rd_data);
    $display("  NET_O = 0x%08X (class = %0d)", rd_data, rd_data[3:0]);
    // net_o = net_i[3:0] ^ net_i[7:4] = 4'hF ^ 4'hF = 4'h0
    check("NET_O after writing 0xFF to reg[0]", 32'h0, rd_data);

    // ── Test 6: Read from unmapped address ───────────────────────────
    $display("[Test Group 6] Read from unmapped address");
    axi_read(14'h0000, rd_data);
    check("Read unmapped addr → DEAD_BEEF", 32'hDEAD_BEEF, rd_data);

    // ── Summary ──────────────────────────────────────────────────────
    $display("\n========================================");
    $display(" Results: %0d PASSED, %0d FAILED", pass_count, fail_count);
    $display("========================================\n");

    if (fail_count > 0)
      $display("*** SOME TESTS FAILED ***\n");
    else
      $display("*** ALL TESTS PASSED ***\n");

    $finish;
  end

  // ── Timeout watchdog ───────────────────────────────────────────────────
  initial begin
    #(CLK_PERIOD * 5000);
    $display("\n*** TIMEOUT — simulation hung (likely AXI deadlock) ***\n");
    $finish;
  end

endmodule
