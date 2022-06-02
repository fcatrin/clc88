`timescale 1ns / 1ps

module compy (
   input clk50,
   input key_reset,
   input key_mode,
   input [4:0] buttons,
   output vga_hs,
   output vga_vs,
   output [4:0] vga_r,
   output [5:0] vga_g,
   output [4:0] vga_b,
   input  uart_rx,
   output uart_tx,
   output [7:0] led_segment,
   output [2:0] led_digit
);
   
   wire pll_locked;
   wire sys_reset;
   
   wire key_mode_pressed;
   wire key_reset_pressed;

   wire[4:0] buttons_pressed;
   
   reg boot_reset = 1;
   reg user_reset = 0;
   
   assign sys_reset = boot_reset || user_reset;
   
   // keep reset until pll locks
   always @ (posedge clk50) begin
      reg [4:0] counter = 5'd0;
      if (pll_locked) begin
         counter <= counter + 1'b1;
         if (counter == 5'b11111) begin 
            boot_reset <= 0;
         end
      end
   end

   // handle user requested reset
   always @ (posedge clk50) begin
      if (!key_reset_pressed && pll_locked) begin
         user_reset <= 1;
      end else begin
         user_reset <= 0;
      end
   end

   system system_inst (
      .clk(clk50),
      .reset_n(!sys_reset),
      .key_mode(key_mode_pressed),
      .buttons(buttons_pressed),
      .vga_hs(vga_hs),
      .vga_vs(vga_vs),
      .vga_r(vga_r),
      .vga_g(vga_g),
      .vga_b(vga_b),
      .pll_locked(pll_locked),
      .uart_rx(uart_rx),
      .uart_tx(uart_tx),
      .led_segment(led_segment),
      .led_digit(led_digit)
   );
  
   debouncer debounce_key_mode (
      .clk(clk50),
      .in(key_mode),
      .out(key_mode_pressed)
   );

   debouncer debounce_key_reset (
      .clk(clk50),
      .in(key_reset),
      .out(key_reset_pressed)
   );

   debouncer debounce_buttons_0 (
         .clk(clk50),
         .in(buttons[0]),
         .out(buttons_pressed[0])
   );
   debouncer debounce_buttons_1 (
         .clk(clk50),
         .in(buttons[1]),
         .out(buttons_pressed[1])
   );
   debouncer debounce_buttons_2 (
         .clk(clk50),
         .in(buttons[2]),
         .out(buttons_pressed[2])
   );
   debouncer debounce_buttons_3 (
         .clk(clk50),
         .in(buttons[3]),
         .out(buttons_pressed[3])
   );
   debouncer debounce_buttons_4 (
         .clk(clk50),
         .in(buttons[4]),
         .out(buttons_pressed[4])
   );

endmodule

