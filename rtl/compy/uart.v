`timescale 1ns / 1ps

module uart (
      input  clk50,
      input  sys_clk,
      input  reset_n,
      input  uart_rx,
      output uart_tx,
      output       rd_avail,
      input        rd_req,
      output reg   rd_rdy,
      output [7:0] rd_data,
      
      input  [7:0] wr_data,
      input        wr_en,
      output       wr_busy
      );

   always @ (posedge clk50) begin : recv_data_in
      recv_buffer_we <= 0;
      
      if (~reset_n) begin
         recv_buffer_addr_in <= 0;
      end
      
      if (uart_rx_done) begin
         recv_buffer_addr_wr <= recv_buffer_addr_in;
         recv_buffer_data_wr <= uart_rx_data_o;
         recv_buffer_we      <= 1;
         recv_buffer_addr_in <= recv_buffer_addr_in + 1'b1;
      end
   end
   
   localparam RD_IDLE = 0;
   localparam RD_WAIT = 1;
   localparam RD_DONE = 2;
   
   reg[1:0] rd_state = RD_IDLE;
   
   always @ (posedge clk50) begin : recv_data_out
      if (~reset_n) begin
         rd_state = RD_IDLE;
         recv_buffer_addr_out <= 0;
         rd_rdy <= 0;
      end
      
      case(rd_state) 
         RD_IDLE: begin
            rd_rdy <= 0;
            if (rd_req) begin
               recv_buffer_addr_rd <= recv_buffer_addr_out;
               rd_state <= RD_WAIT;
            end
         end
         RD_WAIT: rd_state <= RD_DONE;
         RD_DONE: begin
            rd_rdy <= 1;
            rd_state <= RD_IDLE;
         end
      endcase
   end
   
   wire [7:0] uart_rx_data_o;
   wire uart_rx_done;

   uart_rx_path uart_rx_path_u (
         .clk_i(clk50), 
         .uart_rx_i(uart_rx), 
         .uart_rx_data_o(uart_rx_data_o), 
         .uart_rx_done(uart_rx_done)
      );

   uart_tx_path uart_tx_path_u (
         .clk_i(clk50), 
         .uart_tx_data_i(wr_data), 
         .uart_tx_en_i(uart_wr_en), 
         .uart_tx_o(uart_tx),
         .busy(uart_wr_busy)
      );
   
   reg[8:0]  recv_buffer_addr_wr;
   reg[8:0]  recv_buffer_addr_in;
   reg[8:0]  recv_buffer_addr_rd;
   reg[8:0]  recv_buffer_addr_out;
   reg[7:0]  recv_buffer_data_wr;
   reg       recv_buffer_we;
   
   assign rd_avail = recv_buffer_addr_in != recv_buffer_addr_out;
   
   dpram #(512, 9, 8) recv_buffer (
         .rdaddress (recv_buffer_addr_rd),
         .rdclock (sys_clk),
         .q (rd_data),
         .wraddress (recv_buffer_addr_wr),
         .wren (recv_buffer_we),
         .wrclock (clk50),
         .data (recv_buffer_data_wr)
      );
   
   wire uart_wr_en;
   crossclock_signal send_signal (
      .dst_clk(clk50),
      .src_req(wr_en),
      .signal(uart_wr_en)
   );
      
   wire uart_wr_busy;
   crossclock_signal send_busy (
         .dst_clk(sys_clk),
         .src_req(uart_wr_busy),
         .signal(wr_busy)
   );
   

endmodule