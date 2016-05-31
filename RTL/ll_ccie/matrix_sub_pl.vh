localparam DATA_SIZE = CACHE_WIDTH/DATA_WIDTH;


reg [CACHE_WIDTH-1:0] inc;
reg [CACHE_WIDTH-1:0] res;

reg [ADDR_LMT-1:0] addr_offset;
reg [ADDR_LMT-1:0] addr_idx;
reg [ADDR_LMT-1:0] add_wr_idx;

reg [DATA_SIZE-1:0] add_rd_count;
reg [DATA_SIZE-1:0] add_inc_count;
reg [DATA_SIZE-1:0] add_wr_count;

reg [DATA_SIZE-1:0] add_finish_idx;


reg add_rd_req_f;
reg ready_inc;
reg ready_add;

array_accu_pl #(
	.CACHE_WIDTH (CACHE_WIDTH),
	.DATA_WIDTH (DATA_WIDTH)
)
adder (
	.clk (clk),
	.rst (rst),
	.inc (ready_inc),
	.array (inc),
	.res	(res),
	.ready	(ready_add)
);

always@(posedge clk)
begin
	if (add_run && !rd_req_almostfull && !add_rd_req_f)
	begin
		r_rd_req_addr <= (addr_wr_base>>4) + addr_idx + addr_offset;
		$display("CL num: %d", ((MP+15)>>4));
		$display("Read: %d", addr_wr_base + addr_idx + addr_offset);
		r_rd_req_mdata <= 'd0;
		r_rd_req_en <= 1'b1;

		if (addr_idx >= ((MP+15)>>4)*N - ((MP+15)>>4))
		begin
			addr_idx <= 'd0;
			if (addr_offset >= (((MP+15)>>4)-1))
			begin
				add_rd_req_f <= 1'b1;
			end
			else
			begin
				addr_offset <= addr_offset + 1;
			end
		end
		else
		begin
			addr_idx <= addr_idx + ((MP+15)>>4);
		end
	end
	else
	begin
		if (rst)
		begin
			add_rd_req_f <= 1'b0;
			addr_idx <= 'd0;
			addr_offset <= 'd0;
		end
		r_rd_req_en <= 1'b0;
	end
end

always@(posedge clk)
begin
	if (add_run && rd_rsp_valid)
	begin
		$display("Readed: %d %d %d %d ... %d %d", rd_rsp_data[31:0], rd_rsp_data[63:32], rd_rsp_data[95:64], rd_rsp_data[127:96], rd_rsp_data[479:448], rd_rsp_data[511:480]);
		inc <= rd_rsp_data;
		if (add_rd_count == 0)
		begin
			ready_inc <= 1'b0;
		end
		else
		begin
			ready_inc <= 1'b1;
		end
		if (add_rd_count == N-1)
		begin
			add_rd_count <= 'd0;
		end
		else
		begin
			add_rd_count <= add_rd_count + 1;
		end

	end
	else
	begin
		ready_inc <= 1'd0;
		if (rst)
		begin
			add_rd_count <= 'd0;
		end
	end
end

always@(posedge clk)
begin
	if (add_run && !wr_req_almostfull && ready_inc)
	begin
		if (add_inc_count == N-2)
		begin
			$display("Write %d@%d", res, wr_idx + addr_wr_base);
			r_wr_req_addr <= add_wr_idx + addr_wr_base;
			r_wr_req_data <= res;
			r_wr_req_en <= 1'b1;
			r_wr_req_mdata <= 'd0;
			add_inc_count <= 'd0;

			if (add_wr_count >= M-1)
			begin
				r_wr_req_now <= 1'b1;
				add_wr_count <= 'd0;
				add_wr_idx <= ((wr_idx>>4)+1)<<4;
			end
			else
			begin
				add_wr_idx <= add_wr_idx + 1;
				r_wr_req_now <= 1'b0;
				add_wr_count <= add_wr_count + 1;
			end
		end
		else 
		begin
			r_wr_req_en <= 1'b0;
			r_wr_req_now <= 1'b0;
			add_inc_count  <= add_inc_count + 1;
		end
	end
	else
	begin
		r_wr_req_en <= 1'b0;
		r_wr_req_mdata <= 'd0;
		r_wr_req_now <= 1'b0;
		if (rst)
		begin
			add_wr_idx <= 'd0;
			add_wr_count <= 'd0;
			add_inc_count <= 'd0;
		end
	end
end

always@(posedge clk)
begin
	if (add_run && (wr_rsp_valid || wr_rsp_rvalid))
	begin
		$display("Wrote: %d", add_finish_idx);
		if (wr_rsp_valid && wr_rsp_rvalid)
		begin
			$display("Wrote: %d", add_finish_idx + 1);
			add_finish_idx <= add_finish_idx + 2;
		end
		else
		begin
			add_finish_idx <= add_finish_idx + 1;
		end
	end
	else 
	begin
		if (rst)
		begin
			add_finish_idx <= 'd0;
		end
	end
end
