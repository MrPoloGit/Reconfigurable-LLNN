// --------------------------------------------------------------------------------------
// comparator.sv: Receives two inputs and outputs the maximum and its index
// --------------------------------------------------------------------------------------

`include "Globals.sv"

module comparator (
	input  logic [$clog2(CLASS_OUTS+1)-1:0] in1,
	input  logic [$clog2(CLASS_OUTS+1)-1:0] in2,
	output logic [$clog2(CLASS_OUTS+1)-1:0] max,
	output logic                            idx
);

	always_comb begin
		if (in1 >= in2) begin
			idx = 1'b0;
			max = in1;
		end else begin
			idx = 1'b1;
			max = in2;
		end
	end

endmodule : comparator
