module matrix_multiply #(ADDR_LMT = 20, MDATA = 14, CACHE_WIDTH = 512, DATA_WIDTH = 32) 
	(
		input 		    clk, 
		input 		    rst, 

		// Read Request
		output [ADDR_LMT-1:0]    rd_req_addr, 
		output [MDATA-1:0] 	    rd_req_mdata, 
		output 		    rd_req_en, 
		input 		    rd_req_almostfull, 

		// Read Response
		input 		    rd_rsp_valid, 
		input [MDATA-1:0] 	    rd_rsp_mdata, 
		input [CACHE_WIDTH-1:0]  rd_rsp_data, 

		// Write Request 
		output [ADDR_LMT+3:0]    wr_req_addr, 
		output [MDATA-1:0] 	    wr_req_mdata, 
		output [DATA_WIDTH-1:0] wr_req_data, 
		output 		    wr_req_en, 
		output 		    wr_req_now, 
		input 		    wr_req_almostfull, 

		// Write Response 
		input 		    wr_rsp_valid, 

		// Start input signal
		input 		    start, 

		// Done output signal 
		output  		    done 

	);

	/* read port */ 
	reg [ADDR_LMT-1:0] r_rd_req_addr, n_rd_req_addr;  
	reg [MDATA-1:0] r_rd_req_mdata, n_rd_req_mdata;
	reg 		   r_rd_req_en, n_rd_req_en;
	assign rd_req_addr = r_rd_req_addr;
	assign rd_req_mdata = r_rd_req_mdata;
	assign rd_req_en = r_rd_req_en;


	/* buf write port */
	reg [ADDR_LMT+3:0] r_wr_req_addr, n_wr_req_addr;
	reg [DATA_WIDTH-1:0]	r_wr_req_data, n_wr_req_data;
	reg [MDATA-1:0]	r_wr_req_mdata, n_wr_req_mdata;
	reg 		r_wr_req_en, n_wr_req_en;
	reg 	        r_wr_req_now, n_wr_req_now;

	assign wr_req_addr = r_wr_req_addr;
	assign wr_req_data = r_wr_req_data;
	assign wr_req_mdata = r_wr_req_mdata;
	assign wr_req_en = r_wr_req_en;
	assign wr_req_now = r_wr_req_now;


	reg 			   r_done,n_done;
	assign done = r_done;

	reg [4:0] 		   r_state, n_state;

	localparam [4:0]	STATE_IDLE = 'd0,
	STATE_INIT = 'd1,
	STATE_ADDR1 = 'd2,
	STATE_MAT1 = 'd3,
	STATE_ADDR2 = 'd4,
	STATE_MAT2 = 'd5,
	STATE_ITER_M = 'd6,
	STATE_ITER_N = 'd7,
	STATE_ITER_P = 'd8,
	STATE_WRITE = 'd9,
	STATE_WAIT_W = 'd10,
	STATE_WRITE_NOW = 'd11,
	STATE_WAIT_WN = 'd12,
	STATE_FINISH = 'd13;

	reg [CACHE_WIDTH-1:0] vec1;
	reg [CACHE_WIDTH-1:0] vec2;
	reg [DATA_WIDTH-1:0] res;
	reg [DATA_WIDTH-1:0] res_back;

	reg [DATA_WIDTH-1:0] M;
	reg [DATA_WIDTH-1:0] N;
	reg [DATA_WIDTH-1:0] P;

	reg [DATA_WIDTH-1:0] MN;
	reg [DATA_WIDTH-1:0] PN;
	reg [DATA_WIDTH-1:0] MNP;

	reg [ADDR_LMT-1:0] idxM;
	reg [ADDR_LMT-1:0] idxN;
	reg [ADDR_LMT-1:0] idxP;

	reg [DATA_WIDTH-1:0] addr_vec1;
	reg [DATA_WIDTH-1:0] addr_vec2;

	reg [DATA_WIDTH-1:0] res_tmp;

	reg [DATA_WIDTH-1:0] res_relu;
	reg [DATA_WIDTH-1:0] res_tmp_t;

	reg [DATA_WIDTH-1:0] perf_count;
	reg [DATA_WIDTH-1:0] perf_start;

	array_mul mul1(
		.array1	(vec1[CACHE_WIDTH-1:0]), 
		.array2	(vec2[CACHE_WIDTH-1:0]),
		.res		(res_tmp)
	);


	ReLU active1(
		.in 		(res_tmp_t),
		.out 	(res_relu)
	);


	always@(posedge clk)
	begin
		r_state <= rst ? 'd0 : n_state;
		r_done <= rst ? 1'b0 : n_done;   

		r_rd_req_addr <= rst ? 'd0 : n_rd_req_addr;  
		r_rd_req_mdata <= rst ? 'd0 : n_rd_req_mdata;
		r_rd_req_en <= rst ? 1'b0 : n_rd_req_en;

		r_wr_req_addr <= rst ? 'd0 : n_wr_req_addr;  
		r_wr_req_en <= rst ? 1'b0 : n_wr_req_en;
		r_wr_req_data <= rst ? 'd0 : n_wr_req_data;
		r_wr_req_mdata <= rst ? 'd0 : n_wr_req_mdata;
		r_wr_req_now <= rst ? 1'd0 : n_wr_req_now;

		res_tmp_t <= res;
	end

	always@(*)
	begin
		n_state = r_state;
		n_done = r_done;
		/* read port signals */
		n_rd_req_addr = r_rd_req_addr;  
		n_rd_req_mdata = r_rd_req_mdata;
		n_rd_req_en = 1'b0;
		/* write port signals */
		n_wr_req_addr = r_wr_req_addr;  
		n_wr_req_data = r_wr_req_data;
		n_wr_req_mdata = r_wr_req_mdata;
		n_wr_req_en = 1'b0;
		n_wr_req_now = 1'b0;

		case(r_state)
			STATE_IDLE:
			begin
				$display("IDLE");
				if(start && !rd_req_almostfull)
				begin
					n_rd_req_addr = 0;
					n_rd_req_mdata = 0;
					n_rd_req_en = 1'b1;
					n_state = STATE_INIT;

					res_back = 0;
					res = 0;

					vec1 = 0;
					vec2 = 0;

					M = 0;
					N = 0;
					P = 0;
					idxM = 0;
					idxN = 0;
					idxP = 0;

					n_done = 0;
					//perf_start = perf_count;
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
					$display("M: %d", M);
					$display("N: %d", N);
					$display("P: %d", P);

					MN = M*N;
					PN = P*N;
					MNP = MN * P;

					addr_vec1 = 'd1;
					addr_vec2 = addr_vec1 + M*N;

					n_state = STATE_ADDR1;
				end
				else
				begin
					n_state = STATE_INIT;
				end
			end
			STATE_ADDR1:
			begin
				$display("ADDR1");
				if (idxN >= N)
				begin
					n_state = STATE_WRITE;
				end
				else 
				begin
					n_rd_req_addr = addr_vec1 + idxN + idxM;
					n_rd_req_mdata = 0;
					n_rd_req_en = 1'b1;
					n_state = STATE_MAT1;
					$display("Sending request for %x", n_rd_req_addr);
				end
			end
			STATE_MAT1:
			begin
				$display("MAT1");
				if (rd_rsp_valid)
				begin
					vec1 = rd_rsp_data;
					n_state = STATE_ADDR2;
				end
				else
				begin
					n_state = STATE_MAT1;
				end
			end
			STATE_ADDR2:
			begin
				$display("ADDR2");
				n_rd_req_addr = addr_vec2 + idxN + idxP;
				n_rd_req_mdata = 0;
				n_rd_req_en = 1'b1;
				n_state = STATE_MAT2;
				$display("Sending request for %x", n_rd_req_addr);
			end
			STATE_MAT2:
			begin
				$display("MAT2");
				if (rd_rsp_valid)
				begin
					vec2 = rd_rsp_data;
					n_state = STATE_ITER_N;
				end
				else
				begin
					n_state = STATE_MAT2;
				end
			end
			STATE_ITER_N:
			begin
				$display("ITER_N");
				res = res_back + res_tmp;
				res_back = res;
				idxN = idxN + 1;
				n_state = STATE_ADDR1;
				$display("res: %d:0x%h", res, res);
				$display("idxN: %d", idxN);
				$display("state: %d", n_state);
			end
			STATE_ITER_M:
			begin
				$display("ITER_M");
				idxN = 0;
				idxM = idxM + N;
				n_state = STATE_ADDR1;
				res_back = 0;
				$display("idxM: %d", idxM);
				if (idxM >= MN)
				begin
					n_state = STATE_ITER_P;
				end
			end
			STATE_ITER_P:
			begin
				$display("ITER_P");
				idxN = 0;
				idxM = 0;
				idxP = idxP + N;
				n_state = STATE_ADDR1;
				res_back = 0;
				$display("idxP: %d", idxP);
				if (idxP >= PN)
				begin
					n_state = STATE_WRITE_NOW;
				end
			end
			STATE_WRITE_NOW:
			begin
				$display("WRITE_NOW");
				if(!wr_req_almostfull)
				begin
					n_wr_req_en = 1'b1;
					n_wr_req_now = 1'd1;
					n_state = STATE_WAIT_WN;
				end

			end
			STATE_WAIT_WN:
			begin
				$display("WAIT_WN");
				if(wr_rsp_valid)
				begin
					n_state = STATE_FINISH;
				end
			end
			STATE_WRITE:
			begin
				$display("WRITE");
				if(!wr_req_almostfull)
				begin
					n_wr_req_addr = 'd0 + idxM + idxP * M;
					n_wr_req_data = res_relu;
					n_wr_req_mdata = 'd0;
					//n_wr_req_data = res;
					n_wr_req_en = 1'b1;
					n_wr_req_now = 1'b0;
					n_state = STATE_WAIT_W;
					$display("Write Data %d @ %d", res_relu, n_wr_req_addr);
				end
			end
			STATE_WAIT_W:
			begin
				$display("WAITW");
				$display("wr_rsp_valid: %d", wr_rsp_valid);
				if(wr_rsp_valid)
				begin
					n_state = STATE_ITER_M;
				end
			end
			STATE_FINISH:
			begin
				$display("FINISH");
				n_done = 1'b1;
			end
			default:
			begin
				n_state = 'd0;
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

endmodule // matrix_multiply

