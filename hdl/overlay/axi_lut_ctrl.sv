// -------------------------------------------------------------------------------------
// axi_lut_ctrl.sv — AXI-Lite Slave for LLNN Overlay Configuration
//
// Built from axi_lut_ctrl_hard.sv with gate programming added.
//
// Address Map (64KB):
//   0x0000–0x7FFF : Gate programming (write gate_id*4 = 32-bit truth table, up to 8192)
//   0x8000        : STATUS   (R)  — bit 0 = cfg_busy
//   0x8004        : GATE_CNT (R)  — total number of gates
//   0x9000+       : NET_I input registers (ceil(NET_INPUTS/32) × 32-bit words)
//   0x9000+N*4    : NET_O output register (R) — lower bits = classification
// -------------------------------------------------------------------------------------

module axi_lut_ctrl #(
    parameter TOTAL_GATES = 1512,
    parameter NET_INPUTS = 400,
    parameter NET_OUTPUTS = 4,
    parameter ADDR_W = 16,
    parameter DATA_W = 32,
    parameter GATE_SEL_W = (TOTAL_GATES > 1) ? $clog2(TOTAL_GATES) : 1
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

    // Configuration Interface to SoftLUT5 grid
    output logic [GATE_SEL_W-1:0] cfg_gate_sel,
    output logic cfg_ce,
    output logic cfg_data,

    // Inference I/O
    output logic [NET_INPUTS-1:0] net_i,
    input  logic [NET_OUTPUTS-1:0] net_o
);

  // =========================================================================
  //  Constants
  // =========================================================================
  localparam NUM_INPUT_WORDS = (NET_INPUTS + 31) / 32;
  localparam [ADDR_W-1:0] ADDR_INPUT_BASE = ADDR_W'(16'h9000);
  localparam [ADDR_W-1:0] ADDR_OUTPUT     = ADDR_INPUT_BASE + ADDR_W'(NUM_INPUT_WORDS * 4);

  // Input register file
  logic [DATA_W-1:0] input_regs [NUM_INPUT_WORDS];

  // Flatten input_regs into net_i
  genvar gi;
  generate
    for (gi = 0; gi < NUM_INPUT_WORDS; gi++) begin : pack_input
      if ((gi + 1) * 32 <= NET_INPUTS) begin
        assign net_i[gi*32+:32] = input_regs[gi];
      end else begin
        assign net_i[NET_INPUTS-1 : gi*32] = input_regs[gi][NET_INPUTS-1-gi*32:0];
      end
    end
  endgenerate

  // =========================================================================
  //  Config Shift FSM (the new thing vs axi_lut_ctrl_hard.sv)
  // =========================================================================
  typedef enum logic [1:0] { IDLE, SHIFTING, RESPOND } cfg_state_t;
  cfg_state_t cfg_state;
  logic [DATA_W-1:0] shift_reg;
  logic [5:0] bit_cnt;
  logic [GATE_SEL_W-1:0] gate_sel_r;

  assign cfg_gate_sel = gate_sel_r;
  assign cfg_data     = shift_reg[31];            // MSB first
  assign cfg_ce       = (cfg_state == SHIFTING);

  // =========================================================================
  //  AXI-Lite Write Channel  (IDENTICAL pattern to axi_lut_ctrl_hard.sv)
  //
  //  Accepts AW and W independently (they may arrive on different cycles
  //  from the Xilinx protocol converter). When both have been captured,
  //  performs the write and issues B response.
  // =========================================================================
  logic s_axi_awready_reg = 1'b0;
  logic s_axi_wready_reg  = 1'b0;
  logic s_axi_bvalid_reg  = 1'b0;

  logic aw_captured = 1'b0;
  logic w_captured  = 1'b0;
  logic [ADDR_W-1:0] aw_addr_latched;
  logic [DATA_W-1:0] w_data_latched;

  assign S_AXI_AWREADY = s_axi_awready_reg;
  assign S_AXI_WREADY  = s_axi_wready_reg;
  assign S_AXI_BRESP   = 2'b00;
  assign S_AXI_BVALID  = s_axi_bvalid_reg;

  // Address decode from latched address
  wire wr_addr_is_gate  = (aw_addr_latched < ADDR_W'(16'h8000));
  wire wr_addr_is_input = (aw_addr_latched >= ADDR_INPUT_BASE)
                        && (aw_addr_latched <  ADDR_OUTPUT);

  always_ff @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      s_axi_awready_reg <= 1'b0;
      s_axi_wready_reg  <= 1'b0;
      s_axi_bvalid_reg  <= 1'b0;
      aw_captured        <= 1'b0;
      w_captured         <= 1'b0;
      cfg_state          <= IDLE;
      bit_cnt            <= '0;
      shift_reg          <= '0;
      gate_sel_r         <= '0;
      for (int i = 0; i < NUM_INPUT_WORDS; i++) input_regs[i] <= '0;
    end else begin

      // --- AW channel: accept address when offered and not already captured ---
      if (S_AXI_AWVALID && !aw_captured) begin
        s_axi_awready_reg <= 1'b1;
        aw_addr_latched   <= S_AXI_AWADDR;
        aw_captured       <= 1'b1;
      end else begin
        s_axi_awready_reg <= 1'b0;
      end

      // --- W channel: accept data when offered and not already captured ---
      if (S_AXI_WVALID && !w_captured) begin
        s_axi_wready_reg <= 1'b1;
        w_data_latched   <= S_AXI_WDATA;
        w_captured       <= 1'b1;
      end else begin
        s_axi_wready_reg <= 1'b0;
      end

      // --- B channel: clear response when master accepts ---
      if (s_axi_bvalid_reg && S_AXI_BREADY) begin
        s_axi_bvalid_reg <= 1'b0;
      end

      // --- Write execute + Config Shift FSM ---
      case (cfg_state)
        IDLE: begin
          // Both channels captured → perform write + issue B
          if (aw_captured && w_captured && !s_axi_bvalid_reg) begin
            if (wr_addr_is_gate) begin
              // Gate programming → start 32-cycle serial shift
              gate_sel_r       <= aw_addr_latched[GATE_SEL_W+1:2];
              shift_reg        <= w_data_latched;
              bit_cnt          <= '0;
              cfg_state        <= SHIFTING;
              // Clear capture flags so AW/W can accept next transaction
              aw_captured      <= 1'b0;
              w_captured       <= 1'b0;
              // NOTE: s_axi_bvalid_reg NOT set here — delayed until RESPOND
            end else begin
              // Input register or unmapped → immediate BVALID
              if (wr_addr_is_input) begin
                input_regs[(aw_addr_latched - ADDR_INPUT_BASE) >> 2] <= w_data_latched;
              end
              s_axi_bvalid_reg <= 1'b1;
              aw_captured      <= 1'b0;
              w_captured       <= 1'b0;
            end
          end
        end

        SHIFTING: begin
          shift_reg <= {shift_reg[DATA_W-2:0], 1'b0};  // left shift, MSB out
          bit_cnt   <= bit_cnt + 1'b1;
          if (bit_cnt == 6'd31) begin
            cfg_state <= RESPOND;
          end
        end

        RESPOND: begin
          s_axi_bvalid_reg <= 1'b1;
          cfg_state        <= IDLE;
        end

        default: cfg_state <= IDLE;
      endcase
    end
  end

  // =========================================================================
  //  AXI-Lite Read Channel  (IDENTICAL to axi_lut_ctrl_hard.sv, plus
  //  STATUS and GATE_COUNT registers)
  // =========================================================================
  logic s_axi_arready_reg = 1'b0, s_axi_arready_next;
  logic s_axi_rvalid_reg  = 1'b0, s_axi_rvalid_next;
  logic [DATA_W-1:0] s_axi_rdata_reg = '0;
  logic mem_rd_en;

  assign S_AXI_ARREADY = s_axi_arready_reg;
  assign S_AXI_RVALID  = s_axi_rvalid_reg;
  assign S_AXI_RDATA   = s_axi_rdata_reg;
  assign S_AXI_RRESP   = 2'b00;

  always_comb begin
    mem_rd_en = 1'b0;
    s_axi_arready_next = 1'b0;
    s_axi_rvalid_next  = s_axi_rvalid_reg && !S_AXI_RREADY;

    if (S_AXI_ARVALID
        && (!S_AXI_RVALID || S_AXI_RREADY)
        && (!s_axi_arready_reg)) begin
      s_axi_arready_next = 1'b1;
      s_axi_rvalid_next  = 1'b1;
      mem_rd_en           = 1'b1;
    end
  end

  always_ff @(posedge S_AXI_ACLK) begin
    s_axi_arready_reg <= s_axi_arready_next;
    s_axi_rvalid_reg  <= s_axi_rvalid_next;

    if (mem_rd_en) begin
      if (S_AXI_ARADDR == ADDR_W'(16'h8000)) begin
        // STATUS: bit 0 = cfg_busy
        s_axi_rdata_reg <= {31'b0, (cfg_state != IDLE)};
      end else if (S_AXI_ARADDR == ADDR_W'(16'h8004)) begin
        // GATE_COUNT
        s_axi_rdata_reg <= TOTAL_GATES;
      end else if (S_AXI_ARADDR >= ADDR_INPUT_BASE && S_AXI_ARADDR < ADDR_OUTPUT) begin
        s_axi_rdata_reg <= input_regs[(S_AXI_ARADDR - ADDR_INPUT_BASE) >> 2];
      end else if (S_AXI_ARADDR == ADDR_OUTPUT) begin
        s_axi_rdata_reg <= {{(DATA_W - NET_OUTPUTS){1'b0}}, net_o};
      end else begin
        s_axi_rdata_reg <= 32'hDEAD_BEEF;
      end
    end

    if (!S_AXI_ARESETN) begin
      s_axi_arready_reg <= 1'b0;
      s_axi_rvalid_reg  <= 1'b0;
      s_axi_rdata_reg   <= '0;
    end
  end

endmodule
