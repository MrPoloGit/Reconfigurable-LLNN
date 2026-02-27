// -------------------------------------------------------------------------------------
// axi_lut_ctrl_hard.sv — AXI-Lite Slave for LLNN with hardened LUTs
//
// Simplified version of axi_lut_ctrl without SoftLUT gate programming.
// Only handles inference I/O via memory-mapped registers.
//
// Address Map:
//   0x3000–0x3030 : NET_I input registers (13 × 32-bit words = 416 bits, 400 used)
//   0x3034        : NET_O output register (R) — lower 4 bits = classification
// -------------------------------------------------------------------------------------

module axi_lut_ctrl_hard #(
    parameter NET_INPUTS = 400,
    parameter NET_OUTPUTS = 4,
    parameter ADDR_W = 14,
    parameter DATA_W = 32
) (
    // Clock / Reset
    input logic S_AXI_ACLK,
    input logic S_AXI_ARESETN,

    // AXI-Lite Slave Write Address Channel
    input  logic [ADDR_W-1:0] S_AXI_AWADDR,
    input  logic S_AXI_AWVALID,
    output logic S_AXI_AWREADY,

    // AXI-Lite Slave Write Data Channel
    input  logic [DATA_W-1:0] S_AXI_WDATA,
    input  logic [3:0] S_AXI_WSTRB,
    input  logic S_AXI_WVALID,
    output logic S_AXI_WREADY,

    // AXI-Lite Slave Write Response Channel
    output logic [1:0] S_AXI_BRESP,
    output logic S_AXI_BVALID,
    input  logic S_AXI_BREADY,

    // AXI-Lite Slave Read Address Channel
    input  logic [ADDR_W-1:0] S_AXI_ARADDR,
    input  logic S_AXI_ARVALID,
    output logic S_AXI_ARREADY,

    // AXI-Lite Slave Read Data Channel
    output logic [DATA_W-1:0] S_AXI_RDATA,
    output logic [1:0] S_AXI_RRESP,
    output logic S_AXI_RVALID,
    input  logic S_AXI_RREADY,

    // Inference I/O
    output logic [NET_INPUTS-1:0] net_i,
    input  logic [NET_OUTPUTS-1:0] net_o
);

  // =========================================================================
  //  Internal signals
  // =========================================================================
  localparam NUM_INPUT_WORDS = (NET_INPUTS + 31) / 32;  // 13 for 400 bits

  // AXI write latching
  logic aw_ready_r, w_ready_r;
  logic b_valid_r;
  logic [ADDR_W-1:0] aw_addr_r;
  logic aw_done, w_done;

  // AXI read
  logic ar_ready_r;
  logic r_valid_r;
  logic [DATA_W-1:0] r_data_r;
  logic [ADDR_W-1:0] ar_addr_r;

  // Input register file
  logic [DATA_W-1:0] input_regs [NUM_INPUT_WORDS];

  // Flatten input_regs into net_i
  genvar gi;
  generate
    for (gi = 0; gi < NUM_INPUT_WORDS; gi++) begin : pack_input
      if ((gi + 1) * 32 <= NET_INPUTS) begin       // if not last word, assign all 32 bits
        assign net_i[gi*32+:32] = input_regs[gi];
      end else begin                               // if last word, assign only the remaining bits
        assign net_i[NET_INPUTS-1 : gi*32] = input_regs[gi][NET_INPUTS-1-gi*32:0];
      end
    end
  endgenerate

  // =========================================================================
  //  AXI Write Address Channel
  // =========================================================================
  assign S_AXI_AWREADY = aw_ready_r;

  always_ff @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      aw_ready_r <= 1'b0;
      aw_done <= 1'b0;
      aw_addr_r <= '0;
    end else begin
      if (!aw_done && S_AXI_AWVALID && (!w_done || S_AXI_WVALID)) begin
        aw_ready_r <= 1'b1;
        aw_addr_r <= S_AXI_AWADDR;
        aw_done <= 1'b1;
      end else begin
        aw_ready_r <= 1'b0;
      end
      if (S_AXI_BVALID && S_AXI_BREADY) begin
        aw_done <= 1'b0;
      end
    end
  end

  // =========================================================================
  //  AXI Write Data Channel
  // =========================================================================
  assign S_AXI_WREADY = w_ready_r;

  always_ff @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      w_ready_r <= 1'b0;
      w_done <= 1'b0;
    end else begin
      if (!w_done && S_AXI_WVALID && (!aw_done || S_AXI_AWVALID)) begin
        w_ready_r <= 1'b1;
        w_done <= 1'b1;
      end else begin
        w_ready_r <= 1'b0;
      end
      if (S_AXI_BVALID && S_AXI_BREADY) begin
        w_done <= 1'b0;
      end
    end
  end

  // =========================================================================
  //  Write Decode
  // =========================================================================
  wire write_fire = aw_done && w_done;

  // Determine write target region from latched address
  wire addr_is_input = (aw_addr_r >= 14'h3000) && (aw_addr_r < 14'h3034);

  assign S_AXI_BRESP = 2'b00; // OKAY
  assign S_AXI_BVALID = b_valid_r;

  always_ff @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      b_valid_r <= 1'b0;
      for (int i = 0; i < NUM_INPUT_WORDS; i++) input_regs[i] <= '0;
    end else begin
      if (b_valid_r && S_AXI_BREADY) b_valid_r <= 1'b0;

      if (write_fire && !b_valid_r) begin
        if (addr_is_input) begin
          // Input register write
          input_regs[(aw_addr_r-14'h3000)>>2] <= S_AXI_WDATA;
          b_valid_r <= 1'b1;
        end else begin
          // Other address — just ACK
          b_valid_r <= 1'b1;
        end
      end
    end
  end

  // =========================================================================
  //  AXI Read Channel
  // =========================================================================
  assign S_AXI_ARREADY = ar_ready_r;
  assign S_AXI_RVALID = r_valid_r;
  assign S_AXI_RDATA = r_data_r;
  assign S_AXI_RRESP = 2'b00;

  always_ff @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      ar_ready_r <= 1'b0;
      r_valid_r <= 1'b0;
      r_data_r <= '0;
    end else begin
      if (S_AXI_ARVALID && !r_valid_r && !ar_ready_r) begin
        ar_ready_r <= 1'b1;
        ar_addr_r <= S_AXI_ARADDR;
      end else begin
        ar_ready_r <= 1'b0;
      end

      if (ar_ready_r) begin
        r_valid_r <= 1'b1;
        case (ar_addr_r)
          14'h3034: r_data_r <= {{(DATA_W - NET_OUTPUTS) {1'b0}}, net_o}; // NET_O
          default: r_data_r <= 32'hDEAD_BEEF;
        endcase
      end

      if (r_valid_r && S_AXI_RREADY) r_valid_r <= 1'b0;
    end
  end

endmodule
