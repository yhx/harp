module ReLU(
	input [31:0] in,
	output [31:0] out
);

assign out = in[31:31]?0:in;

endmodule
