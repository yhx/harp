module write_buffer_pl #(ADDR_LMT = 20, MDATA = 14, CACHE_WIDTH = 512, DATA_WIDTH = 32)
	(
		// Global signal
		input 		    	 	clk, 
		input 		    	 	rst, 

		//input 			 start,
		//
		// Write Request 
		output [ADDR_LMT-1:0]    	wr_req_addr, 
		output [MDATA-1:0] 	 	wr_req_mdata, 
		output [CACHE_WIDTH-1:0] 	wr_req_data, 
		output 		    	 	wr_req_en, 
		input 		    	 	wr_req_almostfull, 

		// Write Response 
		input 		    	 	wr_rsp0_valid, 
		input [MDATA-1:0] 	 	wr_rsp0_mdata, 
		input 		    	 	wr_rsp1_valid, 
		input [MDATA-1:0] 	 	wr_rsp1_mdata, 

		// Input Write Request
		input 		    	 	wr_now,
		input [ADDR_LMT+3:0]	 	wr_addr,
		input [CACHE_WIDTH-1:0]		wr_data,
		input [MDATA-1:0] 	 	wr_mdata,
		input               	 	wr_en,
		input 				wr_direct,
		// Input Write Response
		output 			 	wr_valid,
		output 			 	wr_real_valid

	);

	reg [ADDR_LMT-1:0]    r_wr_req_addr;
	reg [MDATA-1:0]       r_wr_req_mdata; 
	reg [CACHE_WIDTH-1:0] r_wr_req_data; 
	reg		      r_wr_req_en; 

	assign wr_req_addr = r_wr_req_addr;
	assign wr_req_mdata = r_wr_req_mdata;
	assign wr_req_data = r_wr_req_data;
	assign wr_req_en = r_wr_req_en;

	wire [ADDR_LMT-1:0] cl_addr;
	wire [3:0] offset_addr;
	wire [DATA_WIDTH-1:0] index_addr;

	assign cl_addr = wr_addr[ADDR_LMT+3:4];
	assign offset_addr = wr_addr[3:0];
	assign index_addr = offset_addr << 5;

	reg [CACHE_WIDTH-1:0] buffer;
	reg [MDATA-1:0] buf_mdata;

	reg [ADDR_LMT-1:0] cur_addr;

	reg cacheOn;
	reg wr_real;
	reg r_wr_valid;

	assign wr_real_valid = wr_rsp0_valid | wr_rsp1_valid;
	assign wr_valid = r_wr_valid;

	always@(posedge clk)
	begin
		if (rst)
		begin
			buffer <= 'd0;
			r_wr_req_addr 	<= 'd0;
			r_wr_req_mdata 	<= 'd0;
			r_wr_req_data 	<= 'd0;

			r_wr_req_en 	<= 1'b0; 
			r_wr_valid	<= 1'b0; 

			cacheOn <= 1'b0;
			wr_real <= 1'b0;
			r_wr_valid <= 1'b0;
		end
		else if (wr_direct) 
		begin
			if (!wr_req_almostfull)
			begin
				$display("[WB_WR] D_WR: {%d, %d, %d, %d, ..., %d, %d, %d, %d}@%d", wr_data[511:480], wr_data[479:448], wr_data[447:416], wr_data[415:384], wr_data[127:96], wr_data[95:64], wr_data[63:32], wr_data[31:0], cl_addr);

				r_wr_req_data <= wr_data;
				r_wr_req_mdata <= wr_mdata;
				r_wr_req_addr <= cl_addr;
				r_wr_req_en <= 1'b1;

			end
			else 
			begin
				r_wr_req_data <= 'd0;
				r_wr_req_mdata <= 'd0;
				r_wr_req_addr <= 'd0;
				r_wr_req_en <= 1'b0;
				$display("[WB_ERROR]: Too much wr!!!"); 
			end

			wr_real <= 1'b0;
			r_wr_valid <= 1'b0;
			cacheOn <= cacheOn;
		end
		else 
		begin
			//$display("[WB_WR] En:%d, Now:%d, Direct:%d", wr_en, wr_now, wr_direct);

			buffer[index_addr +: 32] <= wr_en ? wr_data[31:0] : buffer[index_addr +: 32];
			cur_addr <= wr_en ? cl_addr : cur_addr;
			buf_mdata <= wr_en ? wr_mdata : 'd0;

			if (wr_real)
			begin
				if (!wr_req_almostfull)
				begin
					r_wr_req_data <= buffer;
					r_wr_req_mdata =  buf_mdata;
					r_wr_req_en = 1'b1;
					r_wr_req_addr = cur_addr;
					$display("[WB_WR] R_WR: {%d, %d, %d, %d, ..., %d, %d, %d, %d}@%d", buffer[511:480], buffer[479:448], buffer[447:416], buffer[415:384], buffer[127:96], buffer[95:64], buffer[63:32], buffer[31:0], cur_addr);
				end
				else 
				begin
					r_wr_req_data <= 'd0;
					r_wr_req_mdata <= 'd0;
					r_wr_req_addr <= 'd0;
					r_wr_req_en <= 1'b0;
					$display("[WB_ERROR]: Too much wr!!!"); 
				end
			end
			else 
			begin
				r_wr_req_data <= 'd0;
				r_wr_req_mdata <= 'd0;
				r_wr_req_addr <= 'd0;
				r_wr_req_en <= 1'b0;
			end


			if ((wr_now && (cacheOn|| wr_en)) || ((offset_addr == 4'd15) && wr_en))
			begin

				wr_real <= 1'b1;
				r_wr_valid <= 1'b0;
				cacheOn <= 1'b0;
			end
			else if (wr_en)	
			begin
				$display("[WB_WR] L_WR: 0x%d@%d", wr_data[31:0], index_addr);

				wr_real <= 1'b0;
				r_wr_valid <= 1'b1;
				cacheOn <= 1'b1;
			end
			else
			begin
				wr_real <= 1'b0;
				r_wr_valid <= 1'b0;
				cacheOn <= cacheOn;
			end

		end
	end

endmodule
