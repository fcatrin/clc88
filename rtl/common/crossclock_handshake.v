// based on The Cross-clock Handshake
// https://zipcpu.com/blog/2017/10/20/cdc.html

module crossclock_handshake (input src_clk, input dst_clk, input src_req, output reg signal, output busy);
   reg ack = 0;
   
   assign busy = (src_req || ack);
   
   always @ (posedge dst_clk) begin
      reg pipe = 0;
      { signal, pipe } <= { pipe, src_req };
   end
   
   always @ (posedge src_clk) begin
      reg pipe = 0;
      { ack, pipe } <= { pipe, signal };
   end
   
endmodule