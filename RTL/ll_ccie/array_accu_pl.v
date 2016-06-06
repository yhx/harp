module array_accu_pl #(CACHE_WIDTH = 512, DATA_WIDTH = 32)
	(
		input clk,
		input rst,
		input out,
		input inc,
		input [CACHE_WIDTH-1:0] array,
		output [CACHE_WIDTH-1:0] res,
		output ready
	);

	localparam DATA_SIZE = CACHE_WIDTH/DATA_WIDTH;

	reg [CACHE_WIDTH-1:0] add_0_res;
	reg [CACHE_WIDTH-1:0] add_o_res;

	assign res = add_o_res;

	reg enable0;
	assign ready = enable0;

	always@(posedge clk)
	begin
		enable0 <= rst ? 1'b0 : out;
	end

	genvar i;
	generate for (i=0; i<DATA_SIZE; i=i+1)
		begin:adder
			always@(posedge clk)
			begin
				if (rst)
				begin
					add_0_res[i<<5 +: DATA_WIDTH] <= 0;
				end
				else if (out)
				begin
					$display("EN:%d, INC:%d, OUT:%d, ADD_RES: %d", enable0, inc, out, array[i<<5 +: DATA_WIDTH] + add_0_res[i<<5 +: DATA_WIDTH]);
					add_o_res[i<<5 +: DATA_WIDTH] <= array[i<<5 +: DATA_WIDTH] + add_0_res[i<<5 +: DATA_WIDTH];
					add_0_res[i<<5 +: DATA_WIDTH] <= 'd0; 
				end
				else if (inc)
				begin
					$display("EN:%d, INC:%d, OUT:%d, ADD_RES: %d", enable0, inc, out, array[i<<5 +: DATA_WIDTH] + add_0_res[i<<5 +: DATA_WIDTH]);
					add_0_res[i<<5 +: DATA_WIDTH] <= array[i<<5 +: DATA_WIDTH] + add_0_res[i<<5 +: DATA_WIDTH];
				end
				else 
				begin
					add_0_res[i<<5 +: DATA_WIDTH] <= add_0_res[i<<5 +: DATA_WIDTH];
				end
			end
		end
	endgenerate

endmodule
