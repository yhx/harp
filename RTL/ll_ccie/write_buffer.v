module write_buffer #(ADDR_LMT = 20, MDATA = 14, CACHE_WIDTH = 512, DATA_WIDTH = 32)
	(
		// Global signal
		input 		    	 	clk, 
		input 		    	 	rst, 
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
		output 			 	wr_real_valid,

		input 			 	start
	);

	reg [ADDR_LMT-1:0]    r_wr_req_addr, n_wr_req_addr;
	reg [MDATA-1:0]       r_wr_req_mdata, n_wr_req_mdata; 
	reg [CACHE_WIDTH-1:0] r_wr_req_data, n_wr_req_data; 
	reg		      r_wr_req_en, n_wr_req_en; 

	assign wr_req_addr = r_wr_req_addr;
	assign wr_req_mdata = r_wr_req_mdata;
	assign wr_req_data = r_wr_req_data;
	assign wr_req_en = r_wr_req_en;

	reg [2:0] r_state, n_state;
	localparam [2:0] 	STATE_WB_IDLE = 'd0,
	STATE_WB_WR = 'd1;


	wire [ADDR_LMT-1:0] cl_addr;
	reg [3:0] offset_addr;
	reg [DATA_WIDTH-1:0] index_addr;

	assign cl_addr = wr_addr[ADDR_LMT+3:4];
	assign offset_addr = wr_addr[3:0];
	assign index_addr = offset_addr << 5;

	reg [CACHE_WIDTH-1:0] buffer;

	reg [DATA_WIDTH-1:0] iter;


	reg [ADDR_LMT-1:0] cur_addr;
	reg cacheOn;

	reg r_wr_valid, n_wr_valid;

	assign wr_real_valid = wr_rsp0_valid | wr_rsp1_valid;
	assign wr_valid = r_wr_valid;

	always@(posedge clk)
	begin
		r_state 	<= rst?'d0:n_state;

		r_wr_req_addr 	<= rst?'d0:n_wr_req_addr;
		r_wr_req_mdata 	<= rst?'d0:n_wr_req_mdata;
		r_wr_req_data 	<= rst?'d0:n_wr_req_data;

		r_wr_req_en 	<= rst?1'b0:n_wr_req_en; 
		r_wr_valid	<= rst?1'b0:n_wr_valid; 

		if (rst)
		begin
			buffer <= 'd0;
		end

	end

	always@(*)
	begin
		n_state = r_state;

		n_wr_req_addr = r_wr_req_addr;
		n_wr_req_mdata = r_wr_req_mdata;
		n_wr_req_data = r_wr_req_data;
		n_wr_req_en = 1'b0;
		n_wr_valid = 1'b0;

		case(r_state)
			STATE_WB_IDLE:
			begin
				$display("[WB_IDLE]");
				if (start)
				begin
					n_state = STATE_WB_WR;
					n_wr_req_en = 0;
					n_wr_req_mdata = 0;
					n_wr_req_data = 0;
				end
			end
			STATE_WB_WR:
			begin
				$display("[WB_WR] En:%d, Now:%d, Direct:%d", wr_en, wr_now, wr_direct);
				if (wr_direct) 
				begin
					if (!wr_req_almostfull)
					begin
						$display("[WB_WR] D_WR: 0x%h@%d", wr_data, cl_addr);
						n_wr_req_data = wr_data;
						n_wr_req_mdata = wr_mdata;
						n_wr_req_addr = cl_addr;
						n_wr_req_en = 1'b1;
						n_wr_valid = 1'b0;

						$display("[WB_WR] R_WR: 0x%h@%d", n_wr_req_data, n_wr_req_addr);
					end
				end
				else 
				begin
					if (wr_en) 
					begin
						$display("[WB_WR] L_WR: 0x%h@%d", wr_data, index_addr);

						buffer[index_addr+: 32] = wr_data[31:0];
						$display("[WB_WR] Buffer: 0x%h", buffer);
						n_wr_valid = 1'b1;
						cur_addr = cl_addr;
						cacheOn = 1'b1;
					end

					if ((((offset_addr == 4'd15) && wr_en) || (wr_now && cacheOn)) && (!wr_direct))
					begin
						n_wr_valid = 1'b0;
						if (!wr_req_almostfull)
						begin
							$display("Cached?:%d", cacheOn);
							n_wr_req_data = buffer;
							//$display("[WB_WR] MData: %d", wr_mdata);
							n_wr_req_mdata = wr_en ? wr_mdata : 0;
							n_wr_req_en = cacheOn;
							n_wr_req_addr = cur_addr;
							$display("[WB_WR] R_WR: 0x%h@%d", n_wr_req_data, n_wr_req_addr);
						end
						else 
						begin
							n_wr_req_en = 1'b0;
							$display("[WB_ERROR]: Too much wr!!!"); 
						end
						cacheOn = 1'b0;
					end
					else 
					begin
						n_wr_req_en = 'd0;
					end
					$display("Local write %d, Real write finished: %d, finshed: %d", n_wr_valid, wr_rsp0_valid | wr_rsp1_valid, wr_valid);
				end
			end
			default:
			begin
				n_state = STATE_WB_IDLE;
			end
		endcase
	end

endmodule
