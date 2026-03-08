// softlut5_test_bd.v — thin Verilog shell for Block Design Module Reference
// Same pattern as llnn_wrapper_bd.v but for the single-LUT test
module softlut5_test_bd (
    input         clk,
    input         rst_n,
    input  [15:0] S_AXI_AWADDR,
    input         S_AXI_AWVALID,
    output        S_AXI_AWREADY,
    input  [31:0] S_AXI_WDATA,
    input  [3:0]  S_AXI_WSTRB,
    input         S_AXI_WVALID,
    output        S_AXI_WREADY,
    output [1:0]  S_AXI_BRESP,
    output        S_AXI_BVALID,
    input         S_AXI_BREADY,
    input  [15:0] S_AXI_ARADDR,
    input         S_AXI_ARVALID,
    output        S_AXI_ARREADY,
    output [31:0] S_AXI_RDATA,
    output [1:0]  S_AXI_RRESP,
    output        S_AXI_RVALID,
    input         S_AXI_RREADY
);

    softlut5_test_wrapper u_core (
        .clk(clk), .rst_n(rst_n),
        .S_AXI_AWADDR(S_AXI_AWADDR), .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY), .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB), .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY), .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID), .S_AXI_BREADY(S_AXI_BREADY),
        .S_AXI_ARADDR(S_AXI_ARADDR), .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY), .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP), .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY)
    );

endmodule
