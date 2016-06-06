module num_accu_pl #(CACHE_WIDTH = 512, DATA_WIDTH = 32)
	(
		input clk,
		input rst,
		input [DATA_WIDTH-1:0] size_out,
		input inc,
		input [DATA_WIDTH-1:0] array,
		output [DATA_WIDTH-1:0] res,
		output ready
	);


	reg [DATA_WIDTH-1:0] add_0_res;
	reg [DATA_WIDTH-1:0] add_o_res;
	reg [DATA_WIDTH-1:0] cnt;

	assign res = add_o_res;

	reg enable0;
	assign ready = enable0;

	always@(posedge clk)
	begin
		if (rst)
		begin
			add_0_res[DATA_WIDTH-1 : 0] <= 0;
			enable0 <= 1'b0;
			cnt <= 'd0;
		end
		else if (inc)
		begin
			$display("EN:%d, INC:%d, CNT:%d/%d, ADD_RES: %d", enable0, inc, cnt, size_out, array[DATA_WIDTH-1 : 0] + add_0_res[DATA_WIDTH-1 : 0]);
			if (cnt < (size_out - 1))
			begin
				add_0_res[DATA_WIDTH-1 : 0] <= array[DATA_WIDTH-1 : 0] + add_0_res[DATA_WIDTH-1 : 0];
				cnt <= cnt + 1;
				enable0 <= 1'b0;
			end
			else 
			begin
				add_o_res[DATA_WIDTH-1 : 0] <= array[DATA_WIDTH-1 : 0] + add_0_res[DATA_WIDTH-1 : 0];
				add_0_res[DATA_WIDTH-1 : 0] <= 'd0; 
				enable0 <= 1'b1;
				cnt <= 'd0;
			end
		end
		else 
		begin
			add_0_res[DATA_WIDTH-1 : 0] <= add_0_res[DATA_WIDTH-1 : 0];
			cnt <= cnt;
			enable0 <= 1'b0;
		end
	end

endmodule
