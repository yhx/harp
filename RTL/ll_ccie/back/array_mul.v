module array_mul(
	input [511:0] array1,
	input [511:0] array2,
	output [31:0] res
);

wire [31:0] mul_0;
wire [31:0] mul_1;
wire [31:0] mul_2;
wire [31:0] mul_3;
wire [31:0] mul_4;
wire [31:0] mul_5;
wire [31:0] mul_6;
wire [31:0] mul_7;
wire [31:0] mul_8;
wire [31:0] mul_9;
wire [31:0] mul_10;
wire [31:0] mul_11;
wire [31:0] mul_12;
wire [31:0] mul_13;
wire [31:0] mul_14;
wire [31:0] mul_15;

wire [31:0] add_0;
wire [31:0] add_1;
wire [31:0] add_2;
wire [31:0] add_3;
wire [31:0] add_4;
wire [31:0] add_5;
wire [31:0] add_6;
wire [31:0] add_7;
wire [31:0] add_8;

wire [31:0] add_1_0;
wire [31:0] add_1_1;
wire [31:0] add_1_2;
wire [31:0] add_1_3;

wire [31:0] add_2_0;
wire [31:0] add_2_1;



assign mul_0 = array1[31:0]*array2[31:0];
assign mul_1 = array1[63:32]*array2[63:32];
assign mul_2 = array1[95:64]*array2[95:64];
assign mul_3 = array1[127:96]*array2[127:96];
assign mul_4 = array1[159:128]*array2[159:128];
assign mul_5 = array1[191:160]*array2[191:160];
assign mul_6 = array1[223:192]*array2[223:192];
assign mul_7 = array1[255:224]*array2[255:224];
assign mul_8 = array1[287:256]*array2[287:256];
assign mul_9 = array1[319:288]*array2[319:288];
assign mul_10 = array1[351:320]*array2[351:320];
assign mul_11 = array1[383:352]*array2[383:352];
assign mul_12 = array1[415:384]*array2[415:384];
assign mul_13 = array1[447:416]*array2[447:416];
assign mul_14 = array1[479:448]*array2[479:448];
assign mul_15 = array1[511:480]*array2[511:480];

assign add_0 = mul_0 + mul_1;
assign add_1 = mul_2 + mul_3;
assign add_2 = mul_4 + mul_5;
assign add_3 = mul_6 + mul_7;
assign add_4 = mul_8 + mul_9;
assign add_5 = mul_10 + mul_11;
assign add_6 = mul_12 + mul_13;
assign add_7 = mul_14 + mul_15;


assign add_1_0 = add_0 + add_1;
assign add_1_1 = add_2 + add_3;
assign add_1_2 = add_4 + add_5;
assign add_1_3 = add_6 + add_7;

assign add_2_0 = add_1_0 + add_1_1;
assign add_2_1 = add_1_2 + add_1_3;

assign res =  add_2_0 + add_2_1;

endmodule
