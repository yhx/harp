// Copyright (c) 2014-2015, Intel Corporation
//
// Redistribution  and  use  in source  and  binary  forms,  with  or  without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of  source code  must retain the  above copyright notice,
//   this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
// * Neither the name  of Intel Corporation  nor the names of its contributors
//   may be used to  endorse or promote  products derived  from this  software
//   without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,  BUT NOT LIMITED TO,  THE
// IMPLIED WARRANTIES OF  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED.  IN NO EVENT  SHALL THE COPYRIGHT OWNER  OR CONTRIBUTORS BE
// LIABLE  FOR  ANY  DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY,  OR
// CONSEQUENTIAL  DAMAGES  (INCLUDING,  BUT  NOT LIMITED  TO,  PROCUREMENT  OF
// SUBSTITUTE GOODS OR SERVICES;  LOSS OF USE,  DATA, OR PROFITS;  OR BUSINESS
// INTERRUPTION)  HOWEVER CAUSED  AND ON ANY THEORY  OF LIABILITY,  WHETHER IN
// CONTRACT,  STRICT LIABILITY,  OR TORT  (INCLUDING NEGLIGENCE  OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,  EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

module afu_user_wb #(ADDR_LMT = 20, MDATA = 14, CACHE_WIDTH = 512) 
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
      
   
   /* read port */ 
   reg [ADDR_LMT-1:0] r_rd_req_addr, n_rd_req_addr;  
   reg [MDATA-1:0] r_rd_req_mdata, n_rd_req_mdata;
   reg 		   r_rd_req_en, n_rd_req_en;
   assign rd_req_addr = r_rd_req_addr;
   assign rd_req_mdata = r_rd_req_mdata;
   assign rd_req_en = r_rd_req_en;

   /* write port */
   //reg [ADDR_LMT-1:0] r_wr_req_addr, n_wr_req_addr; 
   //reg [MDATA-1:0] r_wr_req_mdata, n_wr_req_mdata;
   //reg 		   r_wr_req_en, n_wr_req_en;
   //reg [511:0] 	   r_wr_req_data,n_wr_req_data;
   //assign wr_req_addr = r_wr_req_addr;
   //assign wr_req_mdata = r_wr_req_mdata;
   //assign wr_req_en = r_wr_req_en;
   //assign wr_req_data = r_wr_req_data;
   
   /* buf write port */
   reg [ADDR_LMT+3:0] write_addr, n_write_addr;
   reg [31:0]	write_data, n_write_data;
   reg 		write_en, n_write_en;
   reg 	        write_now, n_write_now;
   reg 	        write_valid;


   reg [4:0] 		   r_state, n_state;
   reg 			   r_done,n_done;
   
   assign done = r_done;

   reg [511:0] vec1;
   reg [511:0] mat1;
   reg [31:0] res;
   reg [31:0] res_back;
   reg [31:0] M;
   reg [31:0] N;
   reg [31:0] P;
   reg [ADDR_LMT-1:0] idxM;
   reg [ADDR_LMT-1:0] idxN;
   reg [ADDR_LMT-1:0] idxP;
   reg [31:0] addr_base;

   reg [31:0] res_tmp;
 
   reg [31:0] res_relu;
   reg [31:0] res_tmp_t;



   array_mul mul1(
	   .array1	(mat1[511:0]), 
	   .array2	(vec1[511:0]),
	   .res		(res_tmp)
   );


   ReLU active1(
           .in 		(res_tmp_t),
           .out 	(res_relu)
   );

   write_buf wbuf(
	   .clk 	(clk),
	   .reset_n 	(reset_n),
	   
	   .wr_req_addr	(wr_req_addr),
	   .wr_req_mdata 	(wr_req_mdata), 
	   .wr_req_data	(wr_req_data), 
	   .wr_req_en 	(wr_req_en), 
	   .wr_req_almostfull	(wr_req_almostfull), 


	   .wr_rsp0_valid	(wr_rsp0_valid), 
	   .wr_rsp0_mdata	(wr_rsp0_mdata), 
	   .wr_rsp1_valid	(wr_rsp1_valid), 
	   .wr_rsp1_mdata	(wr_rsp1_mdata), 


	   .wr_now 		(write_now),
	   .wr_addr 		(write_addr),
	   .wr_data		(write_data),
	   .wr_en		(write_en),

	   .wr_valid		(write_valid), 

	   .start 		(start)
   );


   always@(posedge clk)
     begin
	r_state <= rst ? 'd0 : n_state;
	r_done <= rst ? 1'b0 : n_done;   

	r_rd_req_addr <= rst ? 'd0 : n_rd_req_addr;  
	r_rd_req_mdata <= rst ? 'd0 : n_rd_req_mdata;
	r_rd_req_en <= rst ? 1'b0 : n_rd_req_en;

	write_addr <= rst ? 'd0 : n_write_addr;  
	write_en <= rst ? 1'b0 : n_write_en;
	write_data <= rst ? 'd0 : n_write_data;
	write_now <= rst ? 1'd0 : n_write_now;

	res_tmp_t <= res;
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
	   n_write_addr = write_addr;  
	   n_write_data = write_data;
	   n_write_en = 1'b0;
	   n_write_now = 1'b0;

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
				   res_back = 0;
				   res = 0;

				   vec1 = 0;
				   mat1 = 0;
				   res = 0;
				   res_back = 0;
				   M = 0;
				   N = 0;
				   P = 0;
				   idxM = 0;
				   idxN = 0;
				   idxP = 0;
				   addr_base = 0;

				   n_done = 0;
				   $display("Sending request for %x", n_rd_req_addr);
			   end
		   end
		   'd1:
		   begin
			   $display("D1");
			   if (rd_rsp_valid)
			   begin
				   M = rd_rsp_data[31:0];
				   N = rd_rsp_data[63:32];
				   P = rd_rsp_data[95:64];
				   $display("M: %d", M);
				   $display("N: %d", N);
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
			   if (idxN >= N)
			   begin
				   n_state = 'd13;
			   end
			   else 
			   begin
				   n_rd_req_addr = addr_base + 1 + (idxN<<1);
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
				   vec1 = rd_rsp_data;
				   n_state = 'd4;
			   end
			   else
			   begin
				   n_state = 'd3;
			   end
		   end
		   'd4:
		   begin
			   $display("D4");
			   n_rd_req_addr = addr_base + 2 + (idxN<<1);
			   n_rd_req_en = 1'b1;
			   n_rd_req_mdata = 0;
			   n_state = 'd5;
			   $display("Sending request for %x", n_rd_req_addr);
		   end
		   'd5:
		   begin
			   $display("D5");
			   if (rd_rsp_valid)
			   begin
				   mat1 = rd_rsp_data;
				   n_state = 'd6;
			   end
			   else
			   begin
				   n_state = 'd5;
			   end
		   end
		   'd6:
		   begin
			   $display("D6");
			   res = res_back + res_tmp;
			   res_back = res;
			   idxN = idxN + 1;
			   n_state = 'd2;
			   $display("res: %d:0x%h", res, res);
			   $display("idxN: %d", idxN);
			   $display("state: %d", n_state);
		   end
		   'd7:
		   begin
			   $display("D7");
			   begin
				   idxN = 0;
				   idxM = idxM + 1;
				   n_state = 'd2;
				   addr_base = addr_base + N*2;
				   res_back = 0;
				   $display("idxM: %d", idxM);
			   end
			   if (idxM >= M)
			   begin
			   	n_state = 'd11;
			   end
		   end
		   'd11:
		   begin
			   $display("D11");
			   if(!wr_req_almostfull)
			   begin
				   n_write_addr = 'd0 + idxM;
				   n_write_data = 0;
				   n_write_en = 1'b0;
				   n_write_now = 1'd1;
				   n_state ='d12;
			   end

		   end
		   'd12:
		   begin
			   $display("D12");
			   if(write_valid)
			   begin
				   n_state = 'd15;
			   end
		   end
		   'd13:
		   begin
			   $display("D13");
			   if(!wr_req_almostfull)
			   begin
				   n_write_addr = 'd0 + idxM;
				   n_write_data = res_relu;
				   //n_write_data = res;
				   n_write_en = 1'b1;
				   n_write_now = 1'b0;
				   n_state = 'd14;
				   $display("Write Data %d @ %d", res_relu, n_write_addr);
			   end
		   end
		   'd14:
		   begin
			   $display("D14");
			   if(write_valid)
			   begin
				   n_state = 'd7;
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

endmodule // afu_user

