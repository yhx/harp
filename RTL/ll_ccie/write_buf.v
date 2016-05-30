module write_buf #(ADDR_LMT = 20, MDATA = 14, CACHE_WIDTH = 512)
	(
		// Global signal
		input 		    	 clk, 
		input 		    	 reset_n, 
		// Write Request 
		output [ADDR_LMT-1:0]    wr_req_addr, 
		output [MDATA-1:0] 	 wr_req_mdata, 
		output [CACHE_WIDTH-1:0] wr_req_data, 
		output 		    	 wr_req_en, 
		input 		    	 wr_req_almostfull, 

		// Write Response 
		input 		    	 wr_rsp0_valid, 
		input [MDATA-1:0] 	 wr_rsp0_mdata, 
		input 		    	 wr_rsp1_valid, 
		input [MDATA-1:0] 	 wr_rsp1_mdata, 

		// Input Write Request
		input 		    	 wr_now,
		input [ADDR_LMT+3:0]	 wr_addr,
		input [31:0] 	    	 wr_data,
		input               	 wr_en,
		// Input Write Response
		output 			 wr_valid,

		input 			 start
	);

	reg [ADDR_LMT-1:0]    r_wr_req_addr, n_wr_req_addr;
	reg [MDATA-1:0]       r_wr_req_mdata, n_wr_req_mdata; 
	reg [CACHE_WIDTH-1:0] r_wr_req_data, n_wr_req_data; 
	reg		      r_wr_req_en, n_wr_req_en; 

	assign wr_req_addr = r_wr_req_addr;
	assign wr_req_mdata = r_wr_req_mdata;
	assign wr_req_data = r_wr_req_data;
	assign wr_req_en = r_wr_req_en;



	wire [ADDR_LMT-1:0] cl_addr;
	reg [3:0] offset_addr;
	reg [31:0] index_addr;

	assign cl_addr = wr_addr[ADDR_LMT+3:4];
	assign offset_addr = wr_addr[3:0];
	assign index_addr = offset_addr << 5;

	reg [511:0] buffer;

	reg [31:0] iter;

	reg [2:0] r_state, n_state;

	reg n_write;

	assign wr_valid = wr_rsp0_valid | wr_rsp1_valid | ~n_write;

	always@(posedge clk)
	begin
		r_state 	<= reset_n?n_state:'b0;

		r_wr_req_addr 	<= reset_n?n_wr_req_addr:'b0;
		r_wr_req_mdata 	<= reset_n?n_wr_req_mdata:'b0;
		r_wr_req_data 	<= reset_n?n_wr_req_data:'b0;
		r_wr_req_en 	<= reset_n?n_wr_req_en:'b0; 

	end

	always@(*)
	begin
		n_state = r_state;

		n_wr_req_addr = r_wr_req_addr;
		n_wr_req_mdata = r_wr_req_mdata;
		n_wr_req_data = r_wr_req_data;
		n_wr_req_en = 1'b0;

		case(r_state)
			'd0:
			begin
				$display("Write D0");
				if (start)
				begin
					n_state = 'd1;
					n_wr_req_en = 0;
					n_wr_req_mdata = 0;
					n_wr_req_data = 0;
					n_wr_req_en = 0;
				end
			end
			'd1:
			begin
				$display("Write D1");
				if (wr_en) 
				begin
					$display("Index: %d", index_addr);
					buffer[index_addr+: 32] = wr_data;
					$display("buffer: 0x%h", buffer);
				end
				if ((offset_addr == 4'd15) && (wr_en))
				begin
					n_write = 1'b1;
					n_state = 'd2;
				end
				else if ((wr_now) && (offset_addr != 4'd0))
				begin
					n_write = 1'b1;
					n_state = 'd2;
				end
				else
				begin
					n_write = 1'b0;
					n_state = 'd1;
				end
				$display("Local write %d, Real write finished: %d, finshed: %d", ~n_write, wr_rsp0_valid | wr_rsp1_valid, wr_valid);
			end
			'd2:
			begin
				$display("Write D2");
				if (!wr_req_almostfull) 
				begin
					n_state = 'd1;
					n_wr_req_data = buffer;
					n_wr_req_mdata = 0;
					n_wr_req_en = n_write;
					n_wr_req_addr = cl_addr;
					$display("RealWrite: 0x%h@%d", n_wr_req_data, n_wr_req_addr);
				end
			end
		endcase
	end

endmodule
