module array_mul_pl #(CACHE_WIDTH = 512, DATA_WIDTH = 32)
	(
		input clk,
		input rst,
		input enable,
		input [CACHE_WIDTH-1:0] array1,
		input [CACHE_WIDTH-1:0] array2,
		output [DATA_WIDTH-1:0] res,
		output ready
	);

	localparam DATA_SIZE = CACHE_WIDTH/DATA_WIDTH;

	reg [DATA_WIDTH-1:0] mul_res [0:DATA_SIZE-1];
	reg [DATA_WIDTH-1:0] add_1_res [0:(DATA_SIZE>>1)-1];
	reg [DATA_WIDTH-1:0] add_2_res [0:(DATA_SIZE>>2)-1];
	reg [DATA_WIDTH-1:0] add_3_res [0:(DATA_SIZE>>3)-1];
	reg [DATA_WIDTH-1:0] add_0_res;

	assign res = add_0_res;

	reg enable1;
	reg enable2;
	reg enable3;
	reg enable4;

	reg enable0;
	assign ready = enable0;


	always@(posedge clk)
	begin
		enable1 <= rst ? 1'b0 : enable;
		enable2 <= rst ? 1'b0 : enable1;
		enable3 <= rst ? 1'b0 : enable2;
		enable4 <= rst ? 1'b0 : enable3;
		enable0 <= rst ? 1'b0 : enable4;
	end

	//multiplier size 16
	genvar i;
	generate for(i=0; i<DATA_SIZE; i++)
		begin:multiplier
			always@(posedge clk)
			begin
				if (enable && (!rst))
				begin
					//$display("ARRAY1: %d, ARRAY2: %d", array1[i*DATA_WIDTH +: DATA_WIDTH], array2[i*DATA_WIDTH +: DATA_WIDTH]);
					mul_res[i] <= array1[i*DATA_WIDTH +: DATA_WIDTH] * array2[i*DATA_WIDTH +: DATA_WIDTH];
				end
				else 
				begin
					mul_res[i] <= 'd0;
				end
			end
		end
	endgenerate

	//adder_1 size 8
	genvar j;
	generate for (j=0; j<(DATA_SIZE>>1); j++)
		begin:adder_1
			always@(posedge clk)
			begin
				if (enable1)
				begin
					//$display("MUL_RES: %d, %d", mul_res[j*2], mul_res[j*2+1]);
					add_1_res[j] <= mul_res[j*2] + mul_res[j*2 + 1];
				end
				else
				begin
					add_1_res[j] <= 'd0;
				end
			end
		end
	endgenerate

	//adder_2 size 4
	genvar k;
	generate for (k=0; k<(DATA_SIZE>>2); k++)
		begin:adder_2
			always@(posedge clk)
			begin
				if (enable2)
				begin
					//$display("ADD_1_RES: %d, %d", add_1_res[k*2], add_1_res[k*2+1]);
					add_2_res[k] <= add_1_res[k*2] + add_1_res[k*2 + 1];
				end
				else
				begin
					add_2_res[k] <= 'd0;
				end
			end
		end
	endgenerate

	//adder_3 size 2
	genvar l;
	generate for (l=0; l<(DATA_SIZE>>3); l++)
		begin:adder_3
			always@(posedge clk)
			begin
				if (enable3)
				begin
					//$display("ADD_2_RES: %d, %d", add_2_res[l*2], add_1_res[l*2+1]);
					add_3_res[l] <= add_2_res[l*2] + add_2_res[l*2 + 1];
				end
				else
				begin
					add_3_res[l] <= 'd0;
				end
			end
		end
	endgenerate

	always@(posedge clk)
	begin
		if (enable4)
		begin
			//$display("ADD_3_RES: %d@%d, %d@%d", add_3_res[0], 0, add_3_res[1], 1);
			add_0_res <= add_3_res[0] + add_3_res[1];
		end
		else
		begin
			add_0_res <= 'd0;
		end
	end


endmodule // array_mul_pl
