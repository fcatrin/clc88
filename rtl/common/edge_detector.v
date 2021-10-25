module edge_detector
      #(parameter on_reset = 0)
       (input clk, input reset_n, input in, output rising, output falling);

   reg in_prev;

   assign rising  = !in_prev &  in;
   assign falling =  in_prev & !in;
   
   always @(posedge clk) begin
      if (!reset_n)
         in_prev <= on_reset;
      else
         in_prev <= in;
   end
 
endmodule