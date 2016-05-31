module afu_user_wb #(ADDR_LMT = 20, MDATA = 14, CACHE_WIDTH = 512, DATA_WIDTH = 32) 
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
		output [MDATA-1:0] 	 wr_req_mdata, 
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
		output  		    done,

		// Control info from software
		input [CACHE_WIDTH-1:0] 	    afu_context
	);
	wire 		   rst = ~reset_n;

	/* buf write port */
	wire [ADDR_LMT+3:0] wb_req_addr;
	wire [CACHE_WIDTH-1:0]	wb_req_data;
	wire [MDATA-1:0]	wb_req_mdata;
	wire 		wb_req_en;
	wire 	        wb_req_now;
	wire 	        wb_req_direct;
	wire 	        wb_rsp_valid;
	wire 	        wb_rsp_rvalid;

	wire 		user_clk;


	//clock_divider divider(
	//	.clk		(clk),
	//	.rst		(rst),
	//	.clk_o		(user_clk)
	//);

	write_buffer #(
		.ADDR_LMT(ADDR_LMT),
		.MDATA(MDATA), 
		.CACHE_WIDTH(CACHE_WIDTH),
		.DATA_WIDTH(DATA_WIDTH)
	) 
	wbuf(
		.clk			(clk),
		.rst			(rst),

		.wr_req_addr		(wr_req_addr),
		.wr_req_mdata		(wr_req_mdata), 
		.wr_req_data		(wr_req_data), 
		.wr_req_en		(wr_req_en), 
		.wr_req_almostfull	(wr_req_almostfull), 


		.wr_rsp0_valid		(wr_rsp0_valid), 
		.wr_rsp0_mdata		(wr_rsp0_mdata), 
		.wr_rsp1_valid		(wr_rsp1_valid), 
		.wr_rsp1_mdata		(wr_rsp1_mdata), 


		.wr_now 		(wb_req_now),
		.wr_addr 		(wb_req_addr),
		.wr_data		(wb_req_data),
		.wr_mdata		(wb_req_mdata),
		.wr_en			(wb_req_en),
		.wr_direct		(wb_req_direct),

		.wr_valid		(wb_rsp_valid), 
		.wr_real_valid		(wb_rsp_rvalid), 

		.start 			(start)
	);

	//matrix_multiply #(
	matrix_multiply_pl #(
		.ADDR_LMT(ADDR_LMT),
		.MDATA(MDATA), 
		.CACHE_WIDTH(CACHE_WIDTH),
		.DATA_WIDTH(DATA_WIDTH)
	)	
	mul1(
		.clk			(clk),
		.rst			(rst), 

		// rd req 
		.rd_req_addr       	(rd_req_addr),
		.rd_req_mdata      	(rd_req_mdata),
		.rd_req_en         	(rd_req_en),
		.rd_req_almostfull 	(rd_req_almostfull),

		// rd rsp 
		.rd_rsp_valid      	(rd_rsp_valid),
		.rd_rsp_mdata      	(rd_rsp_mdata),
		.rd_rsp_data       	(rd_rsp_data),

		// wr req 
		.wr_req_addr		(wb_req_addr),
		.wr_req_mdata      	(wb_req_mdata),
		.wr_req_data       	(wb_req_data),
		.wr_req_en         	(wb_req_en),
		.wr_req_now         	(wb_req_now),
		.wr_req_direct         	(wb_req_direct),
		.wr_req_almostfull 	(wr_req_almostfull),


		// wr rsp 
		.wr_rsp_valid     	(wb_rsp_valid),
		.wr_rsp_rvalid     	(wb_rsp_rvalid),

		// ctrl 
		.start			(start),
		.done			(done)
	);


endmodule // afu_user_wb
