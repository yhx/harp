
module clock_divider(
	input clk,
	input rst,
	output clk_o
);

reg r_clk;
assign clk_o = r_clk;

always@(posedge clk)
begin
	if (rst)
	begin
		r_clk <= 1'b0;
	end
	else 
	begin
		r_clk <= ~clk_o;
	end
end

endmodule
