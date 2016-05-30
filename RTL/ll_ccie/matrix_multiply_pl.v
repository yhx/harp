module matrix_multiply_pl #(ADDR_LMT = 20, MDATA = 14, CACHE_WIDTH = 512, DATA_WIDTH = 32) 
	(
		input 		    	clk, 
		input 		    	rst, 

		// Read Request
		output [ADDR_LMT-1:0]   rd_req_addr, 
		output [MDATA-1:0]	rd_req_mdata, 
		output			rd_req_en, 
		input			rd_req_almostfull, 

		// Read Response
		input			rd_rsp_valid, 
		input [MDATA-1:0]	rd_rsp_mdata, 
		input [CACHE_WIDTH-1:0] rd_rsp_data, 

		// Write Request 
		output [ADDR_LMT+3:0]	wr_req_addr, 
		output [MDATA-1:0] 	wr_req_mdata, 
		output [DATA_WIDTH-1:0]	wr_req_data, 
		output			wr_req_en, 
		output 		    	wr_req_now, 
		input 		    	wr_req_almostfull, 

		// Write Response 
		input 		    	wr_rsp_valid, 

		// Start input signal
		input 		    	start, 

		// Done output signal 
		output  		done 

	);


	/* read port */ 
	reg [ADDR_LMT-1:0] r_rd_req_addr, n_rd_req_addr;  
	reg [MDATA-1:0] r_rd_req_mdata, n_rd_req_mdata;
	reg 		   r_rd_req_en, n_rd_req_en;
	assign rd_req_addr = r_rd_req_addr;
	assign rd_req_mdata = r_rd_req_mdata;
	assign rd_req_en = r_rd_req_en;


	/* buf write port */
	reg [ADDR_LMT+3:0] r_wr_req_addr;
	reg [DATA_WIDTH-1:0]	r_wr_req_data;
	reg [MDATA-1:0]	r_wr_req_mdata;
	reg 		r_wr_req_en;
	reg 	        r_wr_req_now;

	assign wr_req_addr = r_wr_req_addr;
	assign wr_req_data = r_wr_req_data;
	assign wr_req_mdata = r_wr_req_mdata;
	assign wr_req_en = r_wr_req_en;
	assign wr_req_now = r_wr_req_now;


	reg 			   r_done,n_done;


	localparam 		addr_vec1 = 1;

	localparam [3:0]	STATE_IDLE = 'd0, 
	STATE_INIT = 'd1,
	STATE_WAIT = 'd2,
	STATE_RUN = 'd3,
	STATE_FINISH = 'd4;

	wire 			run;
	reg [3:0] 		r_state, n_state;


	assign done = r_done;
	assign run = (r_state == STATE_RUN) && (!r_done);


	reg [DATA_WIDTH-1:0] perf_count;
	reg [DATA_WIDTH-1:0] perf_start;


	reg [DATA_WIDTH-1:0] M;
	reg [DATA_WIDTH-1:0] N;
	reg [DATA_WIDTH-1:0] P;
	reg [DATA_WIDTH-1:0] MN;
	reg [DATA_WIDTH-1:0] PN;
	reg [DATA_WIDTH-1:0] MNP;

	reg [ADDR_LMT-1:0] idxM;
	reg [ADDR_LMT-1:0] idxN;
	reg [ADDR_LMT-1:0] idxP;

	reg [CACHE_WIDTH-1:0] vec1;
	reg [CACHE_WIDTH-1:0] vec2;

	reg [DATA_WIDTH-1:0] res_mul;

	reg [ADDR_LMT-1:0] addr_vec2;

	reg [ADDR_LMT-1:0] vec1_idx;
	reg [ADDR_LMT-1:0] vec2_idx;
	reg [ADDR_LMT-1:0] rd_offset;

	reg [ADDR_LMT+3:0] wr_idx;

	reg [ADDR_LMT+3:0] finish_idx;

	reg [DATA_WIDTH-1:0] read_count;

	reg rd_req_f;
	reg vec1_select;
	reg read_vec;
	reg mul_ready;


	array_mul_pl #(
		.CACHE_WIDTH (CACHE_WIDTH),
		.DATA_WIDTH (DATA_WIDTH)
	)
	mul (
		.clk (clk),
		.rst (rst),
		.enable (read_vec),
		.array1 (vec1),
		.array2 (vec2),
		.res	(res_mul),
		.ready	(mul_ready)
	);

	// Read address update
	always@(posedge clk)
	begin
		if (run && !rd_req_almostfull && !rst && !rd_req_f)
		begin
			if (vec1_select)
			begin
				r_rd_req_addr <= addr_vec1 + vec1_idx + rd_offset;
				$display("Read: %d", addr_vec1 + vec1_idx + rd_offset);
			end
			else
			begin
				r_rd_req_addr <= addr_vec2 + vec2_idx + rd_offset;
				$display("Read: %d", addr_vec2 + vec2_idx + rd_offset);
			end

			r_rd_req_mdata <= 'd0;
			r_rd_req_en <= 1'b1;

			if ((vec1_idx >= MN - N) && vec1_select)
			begin
				vec1_select <= 1'b0;
				vec1_idx <= 'd0;
				if (rd_offset >= N-1)
				begin
					rd_offset <= 'd0;
					if (vec2_idx >= (PN - N)) 
					begin
						rd_req_f <= 1'b1;
					end
					else
					begin
						vec2_idx <= vec2_idx + N;
					end

				end
				else
				begin
					rd_offset <= rd_offset + 1;
				end
			end
			else 
			begin
				vec1_select <= 1'b1;
				if (vec1_select)
				begin
					vec1_idx <= vec1_idx + N;
				end
			end
		end
		else
		begin
			if (rst)
			begin
				rd_req_f <= 1'b0;
				vec1_select <= 1'b0;

				read_count <= 'b0;
				vec1_idx <= 'd0;
				vec2_idx <= 'd0;
				rd_offset <= 'd0;
			end

			r_rd_req_addr <= rst?'d0:n_rd_req_addr;
			r_rd_req_mdata <= rst?'d0:n_rd_req_mdata;
			r_rd_req_en <= rst?'d0:n_rd_req_en;
		end
	end

	// Read responds
	always@(posedge clk)
	begin
		if (run && rd_rsp_valid)
		begin
			$display("Readed: %d %d %d %d ... %d %d", rd_rsp_data[31:0], rd_rsp_data[63:32], rd_rsp_data[95:64], rd_rsp_data[127:96], rd_rsp_data[479:448], rd_rsp_data[511:480]);
			if (read_count == 0)	
			begin
				vec1 <= vec1;
				vec2 <= rd_rsp_data;
				read_vec <= 1'd0;
			end
			else
			begin
				vec1 <= rd_rsp_data;
				vec2 <= vec2;
				read_vec <= 1'd1;
			end

			if (read_count == M)
			begin
				read_count <= 'd0;
			end
			else
			begin
				read_count <= read_count + 1;
			end
		end
		else 
		begin
			read_vec <= 1'd0;
			if (rst)
			begin
				read_count <= 'd0;
			end
		end
	end

	//Write request
	always@(posedge clk)
	begin
		if (run && !wr_req_almostfull && mul_ready)
		begin
			$display("Write %d@%d", res_mul, wr_idx);
			r_wr_req_addr <= wr_idx;
			r_wr_req_data <= res_mul;
			r_wr_req_en <= 'd1;
			r_wr_req_mdata <= 'd0;
			wr_idx <= wr_idx + 1;

			if (finish_idx >= M*P*N - 1)
			begin
				r_wr_req_now <= 1'b1;
			end
			else 
			begin
				r_wr_req_now <= 1'b0;
			end
		end
		else
		begin
			r_wr_req_en <= 'd0;
			r_wr_req_mdata <= 'd0;
			r_wr_req_now <= 1'b0;
			if (rst)
			begin
				wr_idx <= 'd0;
			end
		end
	end

	//Write response
	always@(posedge clk)
	begin
		if (run && wr_rsp_valid)
		begin
			$display("Wrote: %d", finish_idx);
			finish_idx <= finish_idx + 1;
		end
		else 
		begin
			if (rst)
			begin
				finish_idx <= 'd0;
			end
		end
	end


	//FSM
	always@(posedge clk)
	begin
		r_state <= rst ? 'd0 : n_state;
		r_done <= rst ? 1'b0 : n_done;   
	end


	always@(*)
	begin
		n_state = r_state;
		n_done = r_done;
		n_rd_req_en = 1'b0;

		case(r_state)
			STATE_IDLE:
			begin
				$display("IDLE");
				if(start && !rd_req_almostfull)
				begin
					n_rd_req_addr = 0;
					n_rd_req_mdata = 0;
					n_rd_req_en = 1'b1;

					idxM = 0;
					idxN = 0;
					idxP = 0;

					//perf_start = perf_count;

					n_done = 0;

					n_state = STATE_INIT;
					$display("Sending request for %x", n_rd_req_addr);
				end
			end
			STATE_INIT:
			begin
				$display("INIT");
				if (rd_rsp_valid)
				begin
					M = rd_rsp_data[31:0];
					N = rd_rsp_data[63:32];
					P = rd_rsp_data[95:64];
					MN = M * N;
					PN = P * N;
					MNP = M * N * P;
					$display("M: %d", M);
					$display("N: %d", N);
					$display("P: %d", P);

					addr_vec2 = addr_vec1 + MN;

					n_state = STATE_WAIT;
				end
			end
			STATE_WAIT:
			begin
				$display("WAIT");
				n_state = STATE_RUN;
			end
			STATE_RUN:
			begin
				$display("RUN");
				if (finish_idx >= MNP)
				begin
					$display("Finish %d >= %d", finish_idx, MN*P);
					n_state = STATE_FINISH;
				end
			end
			STATE_FINISH:
			begin
				$display("FINISH");
				n_done = 1'b1;
			end
			default:
			begin
				n_state = STATE_IDLE;
			end
		endcase // case (r_state)
	end // always@ (*)

	// Perf
	always@(posedge clk)
	begin
		perf_count <= rst ? 'd0 : perf_count + 1;
	end
	always@(posedge clk)
	begin
		if (r_state == STATE_INIT)
		begin
			perf_start <= perf_count;
		end
		else if (r_state == STATE_FINISH)
		begin
			$display("CYCLE: %d %d %d", perf_count - perf_start, perf_count, perf_start);
		end

	end

endmodule // matrix_multiply_pl

