module afu_user_test #(ADDR_LMT = 20, MDATA = 14, CACHE_WIDTH = 512) 
	(
		input 		    clk, 
		input 		    reset_n, 

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
		output [ADDR_LMT-1:0]    wr_req_addr, 
		output [MDATA-1:0] 	    wr_req_mdata, 
		output [CACHE_WIDTH-1:0] wr_req_data, 
		output 		    wr_req_en, 
		input 		    wr_req_almostfull, 

		// Write Response 
		input 		    wr_rsp0_valid, 
		input [MDATA-1:0] 	    wr_rsp0_mdata, 
		input 		    wr_rsp1_valid, 
		input [MDATA-1:0] 	    wr_rsp1_mdata, 

		// Start input signal
		input 		    start, 

		// Done output signal 
		output  		    done 

		// Control info from software
		//input [511:0] 	    afu_context
	);
	/* DBS's favorite polarity */
	wire 		   rst = ~reset_n;

	localparam addr_vec1 = 'd1;

	/* read port */ 
	reg [ADDR_LMT-1:0] r_rd_req_addr;  
	reg [MDATA-1:0] r_rd_req_mdata;
	reg 		   r_rd_req_en;
	assign rd_req_addr = r_rd_req_addr;
	assign rd_req_mdata = r_rd_req_mdata;
	assign rd_req_en = r_rd_req_en;

	/* write port */
	reg [ADDR_LMT-1:0] r_wr_req_addr; 
	reg [MDATA-1:0] r_wr_req_mdata;
	reg 		   r_wr_req_en;
	reg [511:0] 	   r_wr_req_data;
	assign wr_req_addr = r_wr_req_addr;
	assign wr_req_mdata = r_wr_req_mdata;
	assign wr_req_en = r_wr_req_en;
	assign wr_req_data = r_wr_req_data;

	reg [4:0] 		   r_state, n_state;
	reg 			   r_done,n_done;


	assign run = !r_done;

	reg [ADDR_LMT-1:0] vec1_idx;
	reg rd_req_f;

	assign done = rd_req_f;
	always@(posedge clk)
	begin
		if (run && !rd_req_almostfull && !rd_req_f)
		begin
			r_rd_req_addr <= addr_vec1;
			$display("Read Vec1: %d", addr_vec1);

			r_rd_req_mdata <= 'd0;
			r_rd_req_en <= 1'b1;

			if (vec1_idx >= 540000)
			begin
				rd_req_f <= 1'b1;
			end
			else 
			begin
				vec1_idx <= vec1_idx + 1;
			end
		end
		else 
		begin
			if (rst)
			begin
				rd_req_f <= 1'b0;

				vec1_idx <= 'd0;
			end

			r_rd_req_addr <= 'd0;
			r_rd_req_mdata <= 'd0;
			r_rd_req_en <= 'd0;
		end
	end

endmodule
