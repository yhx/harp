module conv2d #(ADDR_LMT = 20, MDATA = 14, CACHE_WIDTH = 512, DATA_WIDTH = 32) 
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
	/* DBS's favorite polarity */
	wire 		   rst = ~reset_n;


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
	reg 		r_wr_req_en, n_wr_req_en;
	reg 	        r_wr_req_now, n_wr_req_now;

	assign wr_req_addr = r_wr_req_addr;
	assign wr_req_data = r_wr_req_data;
	assign wr_req_en = r_wr_req_en;
	assign wr_req_now = r_wr_req_now;


	reg [4:0] 		   r_state, n_state;
	reg 			   r_done,n_done;

	assign done = r_done;

	localparam LINE_SIZE = CACHE_WIDTH/DATA_WIDTH;
	localparam KERNEL_SIZE = 4;
	localparam IMAGE_SIZE = 50;

	reg [CACHE_WIDTH-1:0] kernel1 [0:3];
	reg [CACHE_WIDTH-1:0] img1 [0:49];


	reg [DATA_WIDTH-1:0] O;
	reg [DATA_WIDTH-1:0] R;
	reg [DATA_WIDTH-1:0] C;
	reg [DATA_WIDTH-1:0] K;

	reg [DATA_WIDTH-1:0] idxO;
	reg [DATA_WIDTH-1:0] idxK;

	reg [ADDR_LMT-1:0] idxCL;

	reg [DATA_WIDTH-1:0] addr_base;

	reg [CACHE_WIDTH-1:0] in1;
	reg [CACHE_WIDTH-1:0] k1;
	reg [DATA_WIDTH-1:0] out1;

	reg [CACHE_WIDTH-1:0] in2;
	reg [CACHE_WIDTH-1:0] k2;
	reg [DATA_WIDTH-1:0] out2;

	reg [DATA_WIDTH-1:0] k_size;
	assign k_size = K*K/LINE_SIZE;

	reg [DATA_WIDTH:0] img_size;
	assign img_size = R*C/LINE_SIZE;

	reg [DATA_WIDTH-1:0] res_out;
	assign res_out = out1 + out2;

	array_mul mul1(
		.array1		(in1), 
		.array2		(k1),
		.res		(out1)
	);

	array_mul mul2(
		.array1		(in2), 
		.array2		(k2),
		.res		(out2)
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
		r_wr_req_now <= rst ? 1'd0 : n_wr_req_now;
	end

	/* read request FSM */
	always@(*)
	begin
		n_state = r_state;
		n_done = r_done;
		/* read port signals */
		n_rd_req_addr = r_rd_req_addr;  
		n_rd_req_mdata = r_rd_req_mdata;
		n_rd_req_en = 1'b0;
		/* write port signals */
		n_wr_req_addr = wr_req_addr;  
		n_wr_req_data = wr_req_data;
		n_wr_req_en = 1'b0;
		n_wr_req_now = 1'b0;

		case(r_state)
			'd0:
			begin
				/* we've got the go signal, configuration data should be valid */
				$display("D0");
				if(start && !rd_req_almostfull)
				begin
					n_rd_req_addr = 0;
					n_rd_req_mdata = 0;
					n_rd_req_en = 1'b1;
					n_state = 'd1;

					addr_base = 'd0;

					O = 0;
					R = 0;
					C = 0;
					K = 0;

					idxO = 0;
					idxK = 0;
					idxCL = 0;

					n_done = 0;

					$display("Sending request for %x", n_rd_req_addr);
				end
			end
			'd1:
			begin
				$display("D1");
				if (rd_rsp_valid)
				begin
					O = rd_rsp_data[31:0];
					R = rd_rsp_data[63:32];
					C = rd_rsp_data[95:64];
					K = rd_rsp_data[127:96];
					$display("O: %d", O);
					$display("R: %d", R);
					$display("C: %d", C);
					$display("P: %d", P);
					n_state = 'd2;
				end
				else
				begin
					n_state = 'd1;
				end
			end
			'd2:
			begin
				$display("D2");
				if (idxO >= O)
				begin
					n_state = 'd5;
				end
				else if (idxK >= k_size)
				begin
					n_state = 'd4;
				end
				else 
				begin
					n_rd_req_addr = addr_base + 1;
					n_rd_req_mdata = 0;
					n_rd_req_en = 1'b1;
					n_state = 'd3;
					$display("Sending request for %x", n_rd_req_addr);
				end
			end
			'd3:
			begin
				$display("D3");
				if (rd_rsp_valid)
				begin
					kernel1[idxK] = rd_rsp_data;
					addr_base = addr_base + 1;
					idxK = idxK + 1;
					n_state = 'd2;
				end
				else
				begin
					n_state = 'd3;
				end
			end
			'd4:
			begin
				$display("D4");
			end
			'd6:
			begin
				if (idxCL >= img_size)
				begin
					n_state = 'd6;
				end
				else 
				begin
					n_rd_req_addr = addr_base + 1;
					n_rd_req_en = 1'b1;
					n_rd_req_mdata = 0;
					n_state = 'd5;
				end
				$display("Sending request for %x", n_rd_req_addr);
			end
			'd5:
			begin
				$display("D5");
				if (rd_rsp_valid)
				begin
					img1[idxCL] = rd_rsp_data;
					idxCL = idxCL + 1;
					addr_base = addr_base + 1;
					n_state = 'd6;
				end
				else
				begin
					n_state = 'd5;
				end
			end
			'd15:
			begin
				$display("D15");
				n_done = 1'b1;
			end
			default:
			begin
				n_state = 'd0;
			end
		endcase // case (r_state)
	end // always@ (*)

endmodule // conv2d

