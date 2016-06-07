afu_user_wb.v: The outmost module
	-- write_buffer_pl.v: A write buffer which merge 16 32-bit writes to one cacheline write.
	-- matrix_multiply_buf_pl.v: A pipelined matrix mutiplier, this module only contains the memory operations.
		--array_mul_pl.v: multiply two cachelines
		--num_accu_pl.v: accumulate the output of array_mul_pl to get the final result

