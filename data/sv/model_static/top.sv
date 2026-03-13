// --------------------------------------------------------------------------------------
// top.sv: Top module of the LUTNN
// --------------------------------------------------------------------------------------

`include "Globals.sv"

module top (
	input  logic [NET_INPUTS-1:0] NET_I,
	output logic [3:0] NET_O
);

	logic [L0_NEURONS-1:0]              F_L0;
	logic [L1_NEURONS-1:0]              F_L1;
	logic [$clog2(CLASS_OUTS+1)-1:0] C0;
	logic [$clog2(CLASS_OUTS+1)-1:0] C1;
	logic [$clog2(CLASS_OUTS+1)-1:0] C2;
	logic [$clog2(CLASS_OUTS+1)-1:0] C3;
	logic [$clog2(CLASS_OUTS+1)-1:0] C4;
	logic [$clog2(CLASS_OUTS+1)-1:0] C5;
	logic [$clog2(CLASS_OUTS+1)-1:0] C6;
	logic [$clog2(CLASS_OUTS+1)-1:0] C7;
	logic [$clog2(CLASS_OUTS+1)-1:0] C8;
	logic [$clog2(CLASS_OUTS+1)-1:0] C9;
	logic [$clog2(CLASS_OUTS+1)-1:0] max0;
	logic [$clog2(CLASS_OUTS+1)-1:0] max1;
	logic [$clog2(CLASS_OUTS+1)-1:0] max2;
	logic [$clog2(CLASS_OUTS+1)-1:0] max3;
	logic [$clog2(CLASS_OUTS+1)-1:0] max4;
	logic [$clog2(CLASS_OUTS+1)-1:0] max5;
	logic [$clog2(CLASS_OUTS+1)-1:0] max6;
	logic [$clog2(CLASS_OUTS+1)-1:0] max7;
	logic                             idx0;
	logic                             idx1;
	logic                             idx2;
	logic                             idx3;
	logic                             idx4;
	logic                             idx5;
	logic                             idx6;
	logic                             idx7;
	logic                             idx8;

	// Instantiate layers
	layer0 L0 (
		.in  (NET_I),
		.out (F_L0)
	);

	layer1 L1 (
		.in  (F_L0),
		.out (F_L1)
	);

	// Parameterized popcount function
	function automatic [8:0] popcount;
		input [199:0] v;
		integer i;
		begin
			popcount = 0;
			for (i = 0; i < 200; i = i + 1)
				popcount = popcount + v[i];
		end
	endfunction

	// Popcount per class
	assign C9 = popcount(F_L1[1999:1800]);
	assign C8 = popcount(F_L1[1799:1600]);
	assign C7 = popcount(F_L1[1599:1400]);
	assign C6 = popcount(F_L1[1399:1200]);
	assign C5 = popcount(F_L1[1199:1000]);
	assign C4 = popcount(F_L1[999:800]);
	assign C3 = popcount(F_L1[799:600]);
	assign C2 = popcount(F_L1[599:400]);
	assign C1 = popcount(F_L1[399:200]);
	assign C0 = popcount(F_L1[199:0]);

	// Comparator reduction chain
	comparator CMP0 (
		.in1 (C0),
		.in2 (C1),
		.max (max0),
		.idx (idx0)
	);

	comparator CMP1 (
		.in1 (max0),
		.in2 (C2),
		.max (max1),
		.idx (idx1)
	);

	comparator CMP2 (
		.in1 (max1),
		.in2 (C3),
		.max (max2),
		.idx (idx2)
	);

	comparator CMP3 (
		.in1 (max2),
		.in2 (C4),
		.max (max3),
		.idx (idx3)
	);

	comparator CMP4 (
		.in1 (max3),
		.in2 (C5),
		.max (max4),
		.idx (idx4)
	);

	comparator CMP5 (
		.in1 (max4),
		.in2 (C6),
		.max (max5),
		.idx (idx5)
	);

	comparator CMP6 (
		.in1 (max5),
		.in2 (C7),
		.max (max6),
		.idx (idx6)
	);

	comparator CMP7 (
		.in1 (max6),
		.in2 (C8),
		.max (max7),
		.idx (idx7)
	);

	comparator CMP8 (
		.in1 (max7),
		.in2 (C9),
		.max (),
		.idx (idx8)
	);

	// Output encoding (argmax)
	always_comb begin
		NET_O = 4'b1111;
		if (idx0 == 1'b0 && idx1 == 1'b0 && idx2 == 1'b0 && idx3 == 1'b0 && idx4 == 1'b0 && idx5 == 1'b0 && idx6 == 1'b0 && idx7 == 1'b0 && idx8 == 1'b0) NET_O = 4'b0000;
		if (idx0 == 1'b1 && idx1 == 1'b0 && idx2 == 1'b0 && idx3 == 1'b0 && idx4 == 1'b0 && idx5 == 1'b0 && idx6 == 1'b0 && idx7 == 1'b0 && idx8 == 1'b0) NET_O = 4'b0001;
		if (idx1 == 1'b1 && idx2 == 1'b0 && idx3 == 1'b0 && idx4 == 1'b0 && idx5 == 1'b0 && idx6 == 1'b0 && idx7 == 1'b0 && idx8 == 1'b0) NET_O = 4'b0010;
		if (idx2 == 1'b1 && idx3 == 1'b0 && idx4 == 1'b0 && idx5 == 1'b0 && idx6 == 1'b0 && idx7 == 1'b0 && idx8 == 1'b0) NET_O = 4'b0011;
		if (idx3 == 1'b1 && idx4 == 1'b0 && idx5 == 1'b0 && idx6 == 1'b0 && idx7 == 1'b0 && idx8 == 1'b0) NET_O = 4'b0100;
		if (idx4 == 1'b1 && idx5 == 1'b0 && idx6 == 1'b0 && idx7 == 1'b0 && idx8 == 1'b0) NET_O = 4'b0101;
		if (idx5 == 1'b1 && idx6 == 1'b0 && idx7 == 1'b0 && idx8 == 1'b0) NET_O = 4'b0110;
		if (idx6 == 1'b1 && idx7 == 1'b0 && idx8 == 1'b0) NET_O = 4'b0111;
		if (idx7 == 1'b1 && idx8 == 1'b0) NET_O = 4'b1000;
		if (idx8 == 1'b1) NET_O = 4'b1001;
	end

endmodule : top
