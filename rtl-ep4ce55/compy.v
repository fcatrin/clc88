`timescale 1ns / 1ps

module compy (
   input clk50,
   input key_reset,
   input key_mode,
   output vga_hs,
   output vga_vs,
   output [4:0] vga_r,
   output [5:0] vga_g,
   output [4:0] vga_b
);
   
   wire pll_locked;
   wire sys_reset;

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

   // handle user requested reset with debounce
   always @ (posedge clk50) begin
      reg [4:0] counter = 5'd0;
      if (!key_reset && pll_locked) begin
         counter <= counter + 1'b1;
         if (counter == 5'b11111) begin 
            user_reset <= 1;
         end
      end else begin
         counter <= 0;
         user_reset <= 0;
      end
   end

   system system_inst (
      .clk(clk50),
      .reset_n(!sys_reset),
      .key_mode(key_mode),
      .vga_hs(vga_hs),
      .vga_vs(vga_vs),
      .vga_r(vga_r),
      .vga_g(vga_g),
      .vga_b(vga_b),
      .pll_locked(pll_locked)
   );
  
   
endmodule

