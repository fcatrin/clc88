/*
 * simple timer
 * 
 * init with wr_en = 1, max_ticks = microsecs
 * set enable = 1 to keep it working or enable = 0 stop it 
 * 
 * on timeout it will trigger irq = 1
 * set irq_ack = 1 to clear the irq flag 
 * 
 * get current value from value output
 * 
 */

module timer 
      #(parameter width = 5'd20,
        parameter resolution  = 8'd100)  // 100 = 1 microsec resolution (1M ticks pers second on 100Mhz clock)
       (input  clk, 
        input  reset_n, 
        input  enable, 
        input  wr_en,
        input  irq_ack,
        output reg irq,
        input [width-1:0] max_ticks, 
        output[width-1:0] value);

   reg[7:0] small_counter;
   reg[width-1:0] counter;
   reg[width-1:0] ticks;
   
   assign value = counter;
   
   always @(posedge clk) begin
      if (!reset_n) begin
         irq <= 0;
         ticks <= 0;
      end else if (!enable || wr_en || ticks == 0) begin
         irq <= 0;
         counter <= ticks;
         small_counter <= resolution;
      end else begin
         if (small_counter == 0) begin
            small_counter <= resolution;
            if (counter == 0) begin
               irq <= 1;
               counter <= ticks;
            end else begin
               counter <= counter - 1'b1;
            end
         end else begin
            small_counter <= small_counter - 1'b1;
         end
      end
      
      if (wr_en)   ticks <= max_ticks;
      if (irq_ack) irq <= 0;
   end
 
endmodule