module array_add_pl #(CACHE_WIDTH = 512, DATA_WIDTH = 32)
	(
		input clk,
		input rst,
		input enable,
		input [CACHE_WIDTH-1:0] array1,
		input [CACHE_WIDTH-1:0] array2,
		output [CACHE_WIDTH-1:0] res,
		output ready
	);

	localparam DATA_SIZE = CACHE_WIDTH/DATA_WIDTH;

	reg [DATA_WIDTH-1:0] add_0_res;

	assign res = add_0_res;

	reg enable0;
	assign ready = enable0;

	always@(posedge clk)
	begin
		enable0 <= rst ? 1'b0 : enable;
	end

	genvar i;
	generate for (i=0; i<DATA_SIZE; i++)
		begin:adder
			always@(posedge clk)
			begin
				if (enable)
				begin
					//$display("ADD_RES: %d@%d, %d@%d", add_3_res[0], 0, add_3_res[1], 1);
					add_0_res[i<<5 +: DATA_WIDTH] <= array1[i<<5 +: DATA_WIDTH] + array1[i<<5 +: DATA_WIDTH];

				end
				else 
				begin
					add_0_res[i<<5 +: DATA_WIDTH] <= 'd0;
				end
			end
		end
	endgenerate

endmodule

