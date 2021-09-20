`timescale 1ns / 1ps

// module to interface with the QMTECH daughter board buttons and displays
// just for testing. It will be replaced by a generic IO in the future

module qmtech_board (
   input clk,
   input reset_n,
   input  [4:0] buttons,
   input  [7:0] wr_data,
   output [7:0] rd_data,
   input  [3:0] addr,
   input wr_en
);
   
   assign rd_data = data;
   reg[7:0] data;

   always @(posedge clk) begin : register_read
     case (addr[3:0])
        4'h0: data <= {3'b0, ~buttons};
     endcase
   end
   
endmodule
