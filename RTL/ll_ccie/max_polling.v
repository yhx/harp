module max_pooling (
	input [127: 0] in,
	output [31:0] out
);

wire signed [31:0] in0;
wire signed [31:0] in1;
wire signed [31:0] in2;
wire signed [31:0] in3;

assign in0 = in[31:0];
assign in1 = in[63:32];
assign in2 = in[95:64];
assign in3 = in[127:96];

reg signed [31:0] max0;
reg signed [31:0] max1;

assign max0 = in0>in1?in0:in1;
assign max1 = in2>in3?in2:in3;

assign out = max0>max1?max0:max1;

endmodule // max_pooling
