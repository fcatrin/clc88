`timescale 1ns / 1ps

module chroni_line_buffer (
      input reset_n,
      input rd_clk,
      input wr_clk,
      
      input [10:0] rd_addr,
      input [10:0] wr_addr,
      
      output [7:0] rd_data,
      input  [7:0] wr_data,
      
      input wr_en,
      input [7:0] wr_bitmap_on,
      input [7:0] wr_bitmap_off,
      
      input [3:0] wr_bitmap_bits,
      output reg wr_busy
);

reg[7:0]  bitmap_data;
reg[10:0] bitmap_addr;
reg[3:0]  bitmap_bits;
reg[7:0]  bitmap_on;
reg[7:0]  bitmap_off;
   
always @ (posedge wr_clk) begin
   wr_busy <= 0;
   if (~reset_n) begin
      bitmap_bits <= 0;
      line_wr_en <= 0;
   end else if (wr_en && wr_bitmap_bits != 0) begin
      bitmap_data <= wr_data;
      bitmap_bits <= wr_bitmap_bits;
      bitmap_on   <= wr_bitmap_on;
      bitmap_off  <= wr_bitmap_off;
      
      bitmap_addr <= wr_addr;
      
      wr_busy <= 1;
   end else if (bitmap_bits != 0) begin
      line_wr_data <= bitmap_data[bitmap_bits-1] ? bitmap_on : bitmap_off;
      line_wr_addr <= bitmap_addr;
      line_wr_en <= 1;
      
      bitmap_addr <= bitmap_addr + 1'b1;
      bitmap_bits <= bitmap_bits - 1'b1;
      
      wr_busy <= bitmap_bits != 1;
   end else begin
      if (wr_en) begin
         line_wr_data <= wr_data;
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
    