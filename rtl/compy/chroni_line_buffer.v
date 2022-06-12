`timescale 1ns / 1ps

module chroni_line_buffer (
      input reset_n,
      input rd_clk,
      input wr_clk,
      
      input [10:0] rd_addr,
      input [10:0] wr_addr,
      
      output [7:0]  rd_data,
      input  [15:0] wr_data,
      
      input wr_en,
      input [7:0] wr_bitmap_on,
      input [7:0] wr_bitmap_off,
      
      input [3:0] wr_bitmap_bits,
      input [2:0] wr_tile_pixels,
      input [3:0] wr_tile_palette,
      output reg wr_busy
);

reg[7:0]  bitmap_data;
reg[10:0] bitmap_addr;
reg[3:0]  bitmap_bits;
reg[7:0]  bitmap_on;
reg[7:0]  bitmap_off;

reg[15:0] tile_data;
reg[2:0]  tile_pixels;
reg[3:0]  tile_palette;
reg[10:0] tile_addr;

   
always @ (posedge wr_clk) begin
   wr_busy <= 0;
   if (~reset_n) begin
      bitmap_bits <= 0;
      line_wr_en <= 0;
      tile_pixels <= 0;
   end else if (wr_en && wr_bitmap_bits != 0) begin
      bitmap_data <= wr_data[7:0];
      bitmap_bits <= wr_bitmap_bits;
      bitmap_on   <= wr_bitmap_on;
      bitmap_off  <= wr_bitmap_off;
      
      bitmap_addr <= wr_addr;
      
      wr_busy <= 1;
   end else if (bitmap_bits != 0) begin
      line_wr_data <= bitmap_data[bitmap_bits-1] ? bitmap_on : bitmap_off;
      line_wr_addr <= bitmap_addr;
      line_wr_en   <= 1;
      
      bitmap_addr <= bitmap_addr + 1'b1;
      bitmap_bits <= bitmap_bits - 1'b1;
      
      wr_busy <= bitmap_bits != 1;
   end else if (wr_en && wr_tile_pixels != 0) begin
      tile_data    <= wr_data;
      tile_pixels  <= wr_tile_pixels;
      tile_palette <= wr_tile_palette;
      tile_addr    <= wr_addr;

      wr_busy      <= 1;
   end else if (tile_pixels != 0) begin
      line_wr_data <= {tile_palette, tile_data[3:0]};
      line_wr_addr <= tile_addr;
      line_wr_en   <= 1;

      tile_addr    <= tile_addr   + 1'b1;
      tile_pixels  <= tile_pixels - 1'b1;

      tile_data    <= {4'b0, tile_data[15:4]};
      wr_busy      <= tile_pixels != 1;
   end else begin
      if (wr_en) begin
         line_wr_data <= wr_data[7:0];
         line_wr_addr <= wr_addr;
         line_wr_en <= 1;
      end else begin
         line_wr_en <= 0;
      end
   end
end

reg[7:0]  line_wr_data;
reg[10:0] line_wr_addr;
reg line_wr_en;

dpram #(1280, 11, 8) line_buffer (
      .data (line_wr_data),
      .rdaddress (rd_addr),
      .rdclock (rd_clk),
      .wraddress (line_wr_addr),
      .wrclock (wr_clk),
      .wren (line_wr_en),
      .q (rd_data)
   );

endmodule
    