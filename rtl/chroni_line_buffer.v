`timescale 1ns / 1ps

module chroni_line_buffer (
      input reset_n,
      input rd_clk,
      input wr_clk,
      
      input [10:0] rd_addr,
      input [10:0] wr_addr,
      
      output reg [7:0] rd_data,
      input  [7:0] wr_data,
      
      input wr_en,
      input [7:0] wr_bitmap_on,
      input [7:0] wr_bitmap_off,
      
      input [3:0] wr_bitmap_bits,
      output reg wr_busy
);

reg[7:0]  pixels [1279:0]; // two lines of 640 pixels
reg[7:0]  bitmap_data;
reg[10:0] bitmap_addr;
reg[3:0]  bitmap_bits;
reg[7:0]  bitmap_on;
reg[7:0]  bitmap_off;
   
always @ (posedge rd_clk) begin
   rd_data <= pixels[rd_addr];
end

always @ (posedge wr_clk) begin
   if (~reset_n) begin
      bitmap_bits <= 0;
      wr_busy <= 0;
   end else if (wr_en && wr_bitmap_bits != 0) begin
      bitmap_data <= wr_data;
      bitmap_addr <= wr_addr;
      bitmap_bits <= wr_bitmap_bits;
      bitmap_on   <= wr_bitmap_on;
      bitmap_off  <= wr_bitmap_off;
      wr_busy <= 1;
   end else if (bitmap_bits != 0) begin
      pixels[bitmap_addr+0] <= bitmap_data[7] ? bitmap_on : bitmap_off;
      pixels[bitmap_addr+1] <= bitmap_data[6] ? bitmap_on : bitmap_off;
      pixels[bitmap_addr+2] <= bitmap_data[5] ? bitmap_on : bitmap_off;
      pixels[bitmap_addr+3] <= bitmap_data[4] ? bitmap_on : bitmap_off;
      pixels[bitmap_addr+4] <= bitmap_data[3] ? bitmap_on : bitmap_off;
      pixels[bitmap_addr+5] <= bitmap_data[2] ? bitmap_on : bitmap_off;
      pixels[bitmap_addr+6] <= bitmap_data[1] ? bitmap_on : bitmap_off;
      pixels[bitmap_addr+7] <= bitmap_data[0] ? bitmap_on : bitmap_off;
      bitmap_bits <= 0;
   end else begin
      if (wr_en) pixels[wr_addr] = wr_data;
      wr_busy <= 0;
   end
end

endmodule
    