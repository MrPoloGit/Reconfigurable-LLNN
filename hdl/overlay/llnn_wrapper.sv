module llnn_wrapper (
    input  logic        clk,
    input  logic        rst_n,
    // AXI-Lite slave
    input  logic [13:0] S_AXI_AWADDR,
    input  logic        S_AXI_AWVALID,
    output logic        S_AXI_AWREADY,
    input  logic [31:0] S_AXI_WDATA,
    input  logic [3:0]  S_AXI_WSTRB,
    input  logic        S_AXI_WVALID,
    output logic        S_AXI_WREADY,
    output logic [1:0]  S_AXI_BRESP,
    output logic        S_AXI_BVALID,
    input  logic        S_AXI_BREADY,
    input  logic [13:0] S_AXI_ARADDR,
    input  logic        S_AXI_ARVALID,
    output logic        S_AXI_ARREADY,
    output logic [31:0] S_AXI_RDATA,
    output logic [1:0]  S_AXI_RRESP,
    output logic        S_AXI_RVALID,
    input  logic        S_AXI_RREADY
);

    // Internal wires
    logic [399:0] net_i;
    logic [3:0]   net_o;

    // AXI controller, handles input/output registers from PS
    axi_lut_ctrl_hard #(
        .NET_INPUTS  (400),
        .NET_OUTPUTS (4)
    ) u_axi (
        .S_AXI_ACLK(clk),
        .S_AXI_ARESETN(rst_n),
        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),
        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BREADY(S_AXI_BREADY),
        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY),
        .net_i(net_i),
        .net_o(net_o)
    );

    // Inference network
    top u_net (
        .NET_I (net_i),
        .NET_O (net_o)
    );

endmodule