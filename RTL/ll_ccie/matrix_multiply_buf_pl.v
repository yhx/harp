module matrix_multiply_buf_pl #(ADDR_LMT = 20, MDATA = 14, CACHE_WIDTH = 512, DATA_WIDTH = 32) 
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
	localparam RAM_DEPTH = 1024/DATA_SIZE;
	localparam [ADDR_LMT-1:0] addr_vec1 = 1;

	localparam [3:0]	
	STATE_IDLE = 'd0, 
	STATE_INIT = 'd1,
	STATE_WAIT = 'd2,
	STATE_RUN = 'd3,
	STATE_ADDUP = 'd4,
	STATE_FINISH = 'd5,
	STATE_NONE = 'd6;

	reg [3:0] 		r_state, n_state;

	wire 			run;
	assign run = (r_state == STATE_RUN) && (!r_done);

	//Perf manage
	reg [DATA_WIDTH-1:0] perf_cnt;
	reg [DATA_WIDTH-1:0] perf_start;

	// Base address
	wire [ADDR_LMT-1:0] addr_vec2;
	wire [ADDR_LMT-1:0] addr_wr_base;


	// INIT parameter
	reg [CACHE_WIDTH-1:0] para, n_para;

	wire [ADDR_LMT-1:0] M;
	wire [ADDR_LMT-1:0] N;
	wire [ADDR_LMT-1:0] P;
	wire [ADDR_LMT-1:0] MN;
	wire [ADDR_LMT-1:0] MP;
	wire [ADDR_LMT-1:0] PN;
	assign M = para[ADDR_LMT-1:0];
	assign N = para[DATA_WIDTH + ADDR_LMT-1:DATA_WIDTH];
	assign P = para[DATA_WIDTH + DATA_WIDTH + ADDR_LMT-1: DATA_WIDTH+DATA_WIDTH];
	assign MN = M * N;
	assign PN = P * N;
	assign MP = M * P;
	assign addr_vec2 = addr_vec1 + MN;
	assign addr_wr_base = ((MN + PN + 20'd1)<<4);

	// TEMP results
	reg [CACHE_WIDTH-1:0] buffer [RAM_DEPTH-1:0];
	reg [CACHE_WIDTH-1:0] vec1;
	reg [CACHE_WIDTH-1:0] vec2;
	wire [DATA_WIDTH-1:0] res_mul;

	wire [DATA_WIDTH-1:0] res_accu;

	// Address index
	reg [ADDR_LMT-1:0] vec1_idx;
	reg [ADDR_LMT-1:0] vec2_idx;
	reg [ADDR_LMT-1:0] rd_offset;


	reg [ADDR_LMT+3:0] wr_idx;

	// RW counters
	reg [DATA_WIDTH-1:0] rd_cnt;
	reg [DATA_WIDTH-1:0] rd_vec1_cnt;
	reg [DATA_WIDTH-1:0] wr_cnt;


	reg [DATA_WIDTH:0] finish_cnt;

	// Control Signals
	reg rd_req_f;
	reg vec2_read;
	reg vec1_select;
	reg vec2_buffered;
	reg vec1_rsp;
	reg ready_vec;
	wire ready_mul;
	wire ready_accu;

	num_accu_pl #(
		.CACHE_WIDTH (CACHE_WIDTH),
		.DATA_WIDTH (DATA_WIDTH)
	)
	accuer (
		.clk (clk),
		.rst (rst),
		.size_out ({12'd0, N}),
		.inc (ready_mul),
		.array (res_mul),
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

	// Read request 
	always@(posedge clk)
	begin
		if (run && !rd_req_almostfull && !rd_req_f)
		begin
			if (vec1_select)
			begin
				r_rd_req_addr <= addr_vec1 + vec1_idx + rd_offset;
				$display("Read Vec1: %d", addr_vec1 + vec1_idx + rd_offset);
			end
			else
			begin
				r_rd_req_addr <= addr_vec2 + vec2_idx + rd_offset;
				$display("Read Vec2: %d", addr_vec2 + vec2_idx + rd_offset);
			end

			r_rd_req_mdata <= 'd0;
			r_rd_req_en <= 1'b1;



			if (rd_offset >= N-1 && vec1_select)
			begin
				rd_offset <= 'd0;
				if (vec1_idx >= MN-N)
				begin
					vec1_idx <= 'd0;
					vec2_read <= 1'b0;
					vec1_select <= 1'b0;

					if (vec2_idx >= (PN-N))
					begin
						vec2_idx <= vec2_idx;
						rd_req_f <= 1'b1;
						$display("READ FINISH");
					end
					else
					begin

						vec2_idx <= vec2_idx + N;
					end
				end
				else
				begin
					vec2_read <= 1'b1;
					vec1_select <= 1'b1;

					vec1_idx <= vec1_idx + N;
					vec2_idx <= vec2_idx;
				end
			end
			else
			begin
				vec1_select <= vec2_read ? 1'b1 : (~vec1_select);
				rd_offset <= vec1_select ? (rd_offset + 20'd1) : rd_offset;

				vec2_read <= vec2_read;

				vec1_idx <= vec1_idx;
				vec2_idx <= vec2_idx;
			end


		end
		else
		begin
			if (rd_req_almostfull)
			begin
				$display("[WARN] READ FULL!!!");
			end
			if (rst)
			begin
				rd_req_f <= 1'b0;
				vec1_select <= 1'b0;
				vec2_read <= 1'b0;

				vec1_idx <= 'd0;
				vec2_idx <= 'd0;
				rd_offset <= 'd0;
			end
			else
			begin
				rd_req_f <= rd_req_f;
				vec1_select <= vec1_select;
				vec2_read <= vec2_read;

				vec1_idx <= vec1_idx;
				vec2_idx <= vec2_idx;
				rd_offset <= rd_offset;
			end

			r_rd_req_addr <= rst ? 20'd0 : n_rd_req_addr;
			r_rd_req_mdata <= rst ? 14'd0 : n_rd_req_mdata;
			r_rd_req_en <= rst ? 1'b0 : n_rd_req_en;
		end
	end

	// Read responds
	always@(posedge clk)
	begin
		if (run && rd_rsp_valid)
		begin
			$display("Readed: %d %d %d %d ... %d %d", rd_rsp_data[31:0], rd_rsp_data[63:32], rd_rsp_data[95:64], rd_rsp_data[127:96], rd_rsp_data[479:448], rd_rsp_data[511:480]);
			if (!vec1_rsp)	
			begin
				vec1 <= vec1;
				vec2 <= vec2;
				buffer[rd_cnt] <=  rd_rsp_data;
				ready_vec <= 1'd0;
			end
			else
			begin
				vec1 <= rd_rsp_data;
				vec2 <= buffer[rd_cnt];
				buffer[rd_cnt] <= buffer[rd_cnt];
				ready_vec <= 1'd1;
			end

			if ((rd_cnt >= N-1) && vec1_rsp)
			begin
				rd_cnt <= 'd0;
				if (rd_vec1_cnt >= M-1)
				begin
					rd_vec1_cnt <= 0;
					vec2_buffered <=1'b0;
					vec1_rsp <= 1'b0;

				end
				else
				begin
					vec2_buffered <= 1'b1;
					vec1_rsp <= 1'b1;
					rd_vec1_cnt <= rd_vec1_cnt + 1;
				end
			end
			else
			begin
				vec1_rsp <= vec2_buffered ? 1'b1 : (~vec1_rsp);
				vec2_buffered <= vec2_buffered;
				rd_vec1_cnt <= rd_vec1_cnt;
				if (vec1_rsp)
				begin
					rd_cnt <= rd_cnt + 1;
				end
				else
				begin
					rd_cnt <= rd_cnt;
				end
			end
		end
		else 
		begin
			ready_vec <= 1'b0;
			if (rst)
			begin
				rd_cnt <= 'd0;
				rd_vec1_cnt <= 'd0;

				vec1_rsp <= 1'b0;
				vec2_buffered <= 1'b0;
			end
			else
			begin
				rd_cnt <= rd_cnt;
				rd_vec1_cnt <= rd_vec1_cnt;

				vec1_rsp <= vec1_rsp;
				vec2_buffered <= vec2_buffered;
			end
		end
	end

	//Write request
	always@(posedge clk)
	begin
		if (run && !wr_req_almostfull && ready_accu)
		begin
			$display("Write %d@%d", res_accu, wr_idx + addr_wr_base);
			r_wr_req_addr <= wr_idx + addr_wr_base;
			r_wr_req_data <= { 480'd0, res_accu};
			r_wr_req_en <= 1'b1;
			r_wr_req_direct <= 1'b0;
			r_wr_req_mdata <= 'd0;


			//TODO delete this
			if (wr_idx >= MN*P - 1)
			begin
				r_wr_req_now <= 1'b1;
				wr_idx <= wr_idx;
			end
			else
			begin
				wr_idx <= wr_idx + 24'd1;
				r_wr_req_now <= 1'b0;
			end

			//TODO uncomment this
			//if (wr_cnt >= M - 1)
			//begin
			//	r_wr_req_now <= 1'b1;
			//	wr_cnt <= 'd0;
			//	wr_idx <= ((wr_idx>>4) + 24'd1)<<4;
			//end
			//else
			//begin
			//	wr_idx <= wr_idx + 24'd1;
			//	r_wr_req_now <= 1'b0;
			//	wr_cnt <= wr_cnt + 1;
			//end
		end
		else
		begin
			if (wr_req_almostfull)
			begin
				$display("[ERROR] WRITE FULL!!!");
			end

			r_wr_req_en <= 1'b0;
			r_wr_req_direct <= 1'b0;
			r_wr_req_mdata <= 'd0;
			r_wr_req_now <= 1'b0;
			if (rst)
			begin
				wr_idx <= 'd0;
				wr_cnt <= 'd0;
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
		else 
		begin
			if (rst)
			begin
				finish_cnt <= 'd0;
			end
			else
			begin
				finish_cnt <= finish_cnt;
			end
		end
	end


	//FSM
	always@(posedge clk)
	begin
		r_state <= rst ? 'd0 : n_state;
		para <= rst ? 'd0 : n_para;

		r_done <= rst ? 1'b0 : n_done;   
	end


	always@(*)
	begin
		n_state = r_state;
		n_done = r_done;
		n_para = para;

		n_rd_req_addr = 'd0;
		n_rd_req_mdata = 'd0;
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
					n_para = rd_rsp_data;
					n_state = STATE_WAIT;
				end
			end
			STATE_WAIT:
			begin
				$display("WAIT");
				$display("M: %d", M);
				$display("N: %d", N);
				$display("P: %d", P);
				n_state = STATE_RUN;
			end
			STATE_RUN:
			begin
				$display("RUN");
				//TODO: change MNP to MP
				if (finish_cnt >= MN*P)
				begin
					$display("Finish %d >= %d", finish_cnt, MN*P);
					n_state = STATE_ADDUP;
				end
			end
			STATE_ADDUP:
			begin
				$display("ADDUP");
				n_state = STATE_FINISH;
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

endmodule // matrix_multiply_buf_pl

