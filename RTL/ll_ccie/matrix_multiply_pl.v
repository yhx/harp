module matrix_multiply_pl #(ADDR_LMT = 20, MDATA = 14, CACHE_WIDTH = 512, DATA_WIDTH = 32) 
	(
		input 		    		clk, 
		input 		    		rst, 

		// Read Request
		output [ADDR_LMT-1:0]   	rd_req_addr, 
		output [MDATA-1:0]		rd_req_mdata, 
		output				rd_req_en, 
		input				rd_req_almostfull, 

		// Read Response
		input				rd_rsp_valid, 
		input [MDATA-1:0]		rd_rsp_mdata, 
		input [CACHE_WIDTH-1:0] 	rd_rsp_data, 

		// Write Request 
		output [ADDR_LMT+3:0]		wr_req_addr, 
		output [MDATA-1:0] 		wr_req_mdata, 
		output [CACHE_WIDTH-1:0]	wr_req_data, 
		output				wr_req_en, 
		output 		    		wr_req_now, 
		output 		    		wr_req_direct, 
		input 		    		wr_req_almostfull, 

		// Write Response 
		input 		    		wr_rsp_valid, 
		input 		    		wr_rsp_rvalid, 

		// Start input signal
		input 		    		start, 

		// Done output signal 
		output  			done 

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
	reg [CACHE_WIDTH-1:0]	r_wr_req_data;
	reg [MDATA-1:0]	r_wr_req_mdata;
	reg 		r_wr_req_en;
	reg 	        r_wr_req_now;
	reg 	        r_wr_req_direct;

	assign wr_req_addr = r_wr_req_addr;
	assign wr_req_data = r_wr_req_data;
	assign wr_req_mdata = r_wr_req_mdata;
	assign wr_req_en = r_wr_req_en;
	assign wr_req_now = r_wr_req_now;
	assign wr_req_direct = r_wr_req_direct;

	reg 			   r_done,n_done;
	assign done = r_done;

	localparam DATA_SIZE = CACHE_WIDTH/DATA_WIDTH;
	localparam 		addr_vec1 = 1;

	localparam [3:0]	
	STATE_IDLE = 'd0, 
	STATE_INIT = 'd1,
	STATE_WAIT = 'd2,
	STATE_RUN = 'd3,
	STATE_ADDUP = 'd4,
	STATE_FINISH = 'd5;

	reg [3:0] 		r_state, n_state;

	wire 			run, accu_run;
	assign run = (r_state == STATE_RUN) && (!r_done);
	assign accu_run = (r_state == STATE_ADDUP) && (!r_done);

	//Perf manage
	reg [DATA_WIDTH-1:0] perf_cnt;
	reg [DATA_WIDTH-1:0] perf_start;

	// INIT parameter
	reg [DATA_WIDTH-1:0] M;
	reg [DATA_WIDTH-1:0] N;
	reg [DATA_WIDTH-1:0] P;
	reg [DATA_WIDTH-1:0] MN;
	reg [DATA_WIDTH-1:0] MP_;
	reg [DATA_WIDTH-1:0] PN;
	reg [DATA_WIDTH-1:0] MNP;

	// TEMP results
	reg [CACHE_WIDTH-1:0] vec1;
	reg [CACHE_WIDTH-1:0] vec2;
	reg [DATA_WIDTH-1:0] res_mul;

	reg [CACHE_WIDTH-1:0] inc;
	reg [CACHE_WIDTH-1:0] res_accu;

	// Base address
	reg [ADDR_LMT-1:0] addr_vec2;
	reg [ADDR_LMT-1:0] addr_wr_base;

	// Address index
	reg [ADDR_LMT-1:0] vec1_idx;
	reg [ADDR_LMT-1:0] vec2_idx;
	reg [ADDR_LMT-1:0] rd_offset;

	reg [ADDR_LMT-1:0] accu_idx;
	reg [ADDR_LMT-1:0] accu_offset;

	reg [ADDR_LMT+3:0] wr_idx;
	reg [ADDR_LMT-1:0] accu_wr_idx;

	// RW counters
	reg [DATA_WIDTH-1:0] rd_cnt;
	reg [DATA_WIDTH-1:0] wr_cnt;

	reg [DATA_SIZE-1:0] accu_rd_cnt;
	reg [DATA_SIZE-1:0] accu_wr_cnt;
	//reg [DATA_SIZE-1:0] accu_inc_cnt;

	reg [ADDR_LMT+3:0] finish_cnt;
	reg [DATA_SIZE-1:0] accu_finish_cnt;

	// Control Singals
	reg rd_req_f;
	reg accu_rd_req_f;
	reg vec1_select;
	reg ready_vec;
	reg ready_mul;
	reg ready_inc;
	reg ready_accu;

	array_accu_pl #(
		.CACHE_WIDTH (CACHE_WIDTH),
		.DATA_WIDTH (DATA_WIDTH)
	)
	accuer (
		.clk (clk),
		.rst (rst),
		.inc (ready_inc),
		.array (inc),
		.res	(res_accu),
		.ready	(ready_accu)
	);

	array_mul_pl #(
		.CACHE_WIDTH (CACHE_WIDTH),
		.DATA_WIDTH (DATA_WIDTH)
	)
	mul (
		.clk (clk),
		.rst (rst),
		.enable (ready_vec),
		.array1 (vec1),
		.array2 (vec2),
		.res	(res_mul),
		.ready	(ready_mul)
	);

	// Read address update
	always@(posedge clk)
	begin
		if (run && !rd_req_almostfull && !rd_req_f)
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
				if (vec2_idx >= (PN - N))
				begin
					vec2_idx <= 'd0;
					if (rd_offset >= N-1)
					begin
						rd_req_f <= 1'b1;
					end
					else
					begin
						rd_offset <= rd_offset + 1;
					end
				end
				else
				begin
					vec2_idx <= vec2_idx + N;
				end
				//if (rd_offset >= N-1)
				//begin
				//	rd_offset <= 'd0;
				//	if (vec2_idx >= (PN - N)) 
				//	begin
				//		rd_req_f <= 1'b1;
				//	end
				//	else
				//	begin
				//		vec2_idx <= vec2_idx + N;
				//	end

				//end
				//else
				//begin
				//	rd_offset <= rd_offset + 1;
				//end
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
		else if (accu_run && !rd_req_almostfull && !accu_rd_req_f)
		begin
			r_rd_req_addr <= (addr_wr_base>>4) + accu_idx + accu_offset;
			$display("CL num: %d", (MP_));
			$display("Read: %d", addr_wr_base + accu_idx + accu_offset);
			r_rd_req_mdata <= 'd0;
			r_rd_req_en <= 1'b1;

			if (accu_idx >= (MP_)*N - (MP_))
			begin
				accu_idx <= 'd0;
				if (accu_offset >= ((MP_)-1))
				begin
					accu_rd_req_f <= 1'b1;
				end
				else
				begin
					accu_offset <= accu_offset + 1;
				end
			end
			else
			begin
				accu_idx <= accu_idx + (MP_);
			end
		end
		else
		begin
			if (rst)
			begin
				rd_req_f <= 1'b0;
				vec1_select <= 1'b0;
				accu_rd_req_f <= 1'b0;

				accu_idx <= 'd0;
				accu_offset <= 'd0;
				rd_cnt <= 'd0;
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
			if (rd_cnt == 0)	
			begin
				vec1 <= vec1;
				vec2 <= rd_rsp_data;
				ready_vec <= 1'd0;
			end
			else
			begin
				vec1 <= rd_rsp_data;
				vec2 <= vec2;
				ready_vec <= 1'd1;
			end

			if (rd_cnt == M)
			begin
				rd_cnt <= 'd0;
			end
			else
			begin
				rd_cnt <= rd_cnt + 1;
			end
		end
		else if (accu_run && rd_rsp_valid)
		begin
			$display("Readed: %d %d %d %d ... %d %d", rd_rsp_data[31:0], rd_rsp_data[63:32], rd_rsp_data[95:64], rd_rsp_data[127:96], rd_rsp_data[479:448], rd_rsp_data[511:480]);
			inc <= rd_rsp_data;
			if (accu_rd_cnt == 0)
			begin
				ready_inc <= 1'b0;
			end
			else
			begin
				ready_inc <= 1'b1;
			end
			if (accu_rd_cnt == N-1)
			begin
				accu_rd_cnt <= 'd0;
			end
			else
			begin
				accu_rd_cnt <= accu_rd_cnt + 1;
			end

		end
		else 
		begin
			ready_inc <= 1'b0;
			ready_vec <= 1'b0;
			if (rst)
			begin
				rd_cnt <= 'd0;
				accu_rd_cnt <= 'd0;
			end
		end
	end

	//Write request
	always@(posedge clk)
	begin
		if (run && !wr_req_almostfull && ready_mul)
		begin
			$display("Write %d@%d", res_mul, wr_idx + addr_wr_base);
			r_wr_req_addr <= wr_idx + addr_wr_base;
			r_wr_req_data <= { 480'd0, res_mul};
			r_wr_req_en <= 1'b1;
			r_wr_req_direct <= 1'b0;
			r_wr_req_mdata <= 'd0;

			if (wr_cnt >= M*P - 1)
			begin
				r_wr_req_now <= 1'b1;
				wr_cnt <= 'd0;
				wr_idx <= ((wr_idx>>4) + 1)<<4;
			end
			else
			begin
				wr_idx <= wr_idx + 1;
				r_wr_req_now <= 1'b0;
				wr_cnt <= wr_cnt + 1;
			end

			//if (wr_idx >= M*P*N - 1)
			//begin
			//	r_wr_req_now <= 1'b1;
			//end
			//else 
			//begin
			//	r_wr_req_now <= 1'b0;
			//end
		end
		else if (accu_run && !wr_req_almostfull && ready_accu)
		begin
			$display("Write: %d %d %d %d ... %d %d@%d", res_accu[31:0], res_accu[63:32], res_accu[95:64], res_accu[127:96], res_accu[479:448], res_accu[511:480], accu_wr_idx + addr_wr_base);
			r_wr_req_addr <= accu_wr_idx + addr_wr_base;
			r_wr_req_data <= res_accu;
			r_wr_req_direct <= 1'b1;
			r_wr_req_en <= 1'b0;
			r_wr_req_now <= 1'b0;
			r_wr_req_mdata <= 'd0;

			accu_wr_idx <= accu_wr_idx + DATA_SIZE;
		end
		else
		begin
			r_wr_req_en <= 1'b0;
			r_wr_req_direct <= 1'b0;
			r_wr_req_mdata <= 'd0;
			r_wr_req_now <= 1'b0;
			if (rst)
			begin
				wr_idx <= 'd0;
				wr_cnt <= 'd0;

				accu_wr_idx <= 'd0;
				accu_wr_cnt <= 'd0;
			end
		end
	end

	//Write response
	always@(posedge clk)
	begin
		if (run && (wr_rsp_valid || wr_rsp_rvalid))
		begin
			$display("Wrote: %d", finish_cnt);
			if (wr_rsp_valid && wr_rsp_rvalid)
			begin
				$display("Wrote: %d", finish_cnt + 1);
				finish_cnt <= finish_cnt + 2;
			end
			else
			begin
				finish_cnt <= finish_cnt + 1;
			end
		end
		else if (accu_run && (wr_rsp_valid || wr_rsp_rvalid))
		begin
			$display("Wrote: %d", accu_finish_cnt);
			if (wr_rsp_valid && wr_rsp_rvalid)
			begin
				$display("Wrote: %d", accu_finish_cnt + 1);
				accu_finish_cnt <= accu_finish_cnt + 2;
			end
			else
			begin
				accu_finish_cnt <= accu_finish_cnt + 1;
			end
		end
		else 
		begin
			if (rst)
			begin
				accu_finish_cnt <= 'd0;
				finish_cnt <= 'd0;
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
					MP_ = (P * M + 15)>>4;
					PN = P * N;
					MNP = M * N * P;
					$display("M: %d", M);
					$display("N: %d", N);
					$display("P: %d", P);

					addr_vec2 = addr_vec1 + MN;
					addr_wr_base = ((MN + PN + 1)<<4);

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
				if (finish_cnt >= MNP)
				begin
					$display("Finish %d >= %d", finish_cnt, MN*P);
					n_state = STATE_ADDUP;
				end
			end
			STATE_ADDUP:
			begin
				$display("ADDUP");
				if (accu_finish_cnt >= (MP_))
				begin
					$display("Finish %d >= %d", finish_cnt, MN*P);
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
		perf_cnt <= rst ? 'd0 : perf_cnt + 1;
	end
	always@(posedge clk)
	begin
		if (r_state == STATE_INIT)
		begin
			perf_start <= perf_cnt;
		end
		else if (r_state == STATE_FINISH)
		begin
			$display("CYCLE: %d %d %d", perf_cnt - perf_start, perf_cnt, perf_start);
		end

	end

endmodule // matrix_multiply_pl

