`timescale 1ns / 1ps

module uart (
      input  clk50,
      input  reset_n,
      input  uart_rx,
      output uart_tx
      );

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
         .uart_tx_data_i(uart_rx_data_o), 
         .uart_tx_en_i(uart_rx_done), 
         .uart_tx_o(uart_tx)
      );

endmodule