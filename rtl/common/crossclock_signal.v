module crossclock_signal 
      # (parameter width = 1)
      (input dst_clk, input[width-1:0] src_req, output reg[width-1:0] signal);
   
   always @ (posedge dst_clk) begin
      reg[width-1:0] pipe = 0;
      { signal, pipe } <= { pipe, src_req };
   end
endmodule