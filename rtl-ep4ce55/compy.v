`timescale 1ns / 1ps

module compy (
   input clk,
   input reset_n,
   input key_mode,
   output vga_hs,
   output vga_vs,
   output [4:0] vga_r,
   output [5:0] vga_g,
   output [4:0] vga_b
);
   
   wire pll_locked;
   
   system system_inst (
      .clk(clk),
      .reset_n(reset_n),
      .key_mode(key_mode),
      .vga_hs(vga_hs),
      .vga_vs(vga_vs),
      .vga_r(vga_r),
      .vga_g(vga_g),
      .vga_b(vga_b),
      .pll_locked(pll_locked)
   );
  
   
endmodule

