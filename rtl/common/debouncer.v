module debouncer (input clk, input in, output out);
 
   parameter DEBOUNCE_TIME = 500000;  // 10ms at 50 MHz
   
   reg [18:0] counter = 0;
   reg state = 1'b0;
 
   always @(posedge clk)
   begin
      if (in !== state && counter < DEBOUNCE_TIME) begin
         counter <= counter + 1'b1;
      end else if (counter == DEBOUNCE_TIME) begin
         state <= in;
         counter <= 0;
      end else begin
         counter <= 0;
      end
   end
 
   assign out = state;
 
endmodule