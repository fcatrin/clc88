`timescale 1ns / 1ps

module chroni (
      input vga_clk,
      input sys_clk,
      input reset_n,
      input cs,
      input [1:0] vga_mode_in,
      output vga_hs,
      output vga_vs,
      output [4:0] vga_r,
      output [5:0] vga_g,
      output [4:0] vga_b,
      output reg [12:0] addr_out,
      input [7:0] data_in,
      output reg rd_req,
      input  rd_ack,
      input [7:0] cpu_wr_data,
      input [3:0] cpu_wr_addr,
      input cpu_wr_en,
      output reg dma_req
      );

   `include "chroni.vh"
   
   localparam PAL_WRITE_IDLE = 0;
   localparam PAL_WRITE_LO   = 1;
   localparam PAL_WRITE_HI   = 2;
   localparam PAL_WRITE      = 3;
   
   always @(posedge sys_clk) begin : register_write
      reg[1:0] palette_write_state = PAL_WRITE_IDLE;
      
      palette_wr_en <= 0;
      if (cs && cpu_wr_en) begin
         case (cpu_wr_addr)
            4'd4:
            begin
               palette_wr_addr  <= cpu_wr_data;
               palette_write_state <= PAL_WRITE_LO;
            end
            4'd5:
               if (palette_write_state == PAL_WRITE_LO) begin
                  palette_wr_data[7:0]  <= cpu_wr_data;
                  palette_write_state   <= PAL_WRITE_HI;
               end else begin
                  palette_wr_data[15:8] <= cpu_wr_data;
                  palette_write_state   <= PAL_WRITE;
               end
         endcase
      end else if (palette_write_state == PAL_WRITE) begin
         palette_wr_en <= 1;
         palette_wr_addr <= palette_wr_addr + 1'b1;  // autoincrement palette index
         palette_write_state <= PAL_WRITE_IDLE;
         
         font_base = palette_wr_data[1:0];
      end
   end

   localparam FD_IDLE       = 0;
   localparam FD_TEXT_READ  = 1;
   localparam FD_TEXT_WAIT  = 2;
   localparam FD_TEXT_DONE  = 3;
   localparam FD_FONT_READ_REQ = 4; 
   localparam FD_FONT_READ_REQ_WAIT1 = 5;
   localparam FD_FONT_READ_REQ_WAIT2 = 6;
   localparam FD_FONT_READ  = 7;
   localparam FD_FONT_WAIT  = 8;
   localparam FD_FONT_WRITE = 9;
   localparam FD_FONT_DONE  = 10;
   reg[3:0]  font_decode_state;

   reg[1:0]  font_base;

   // state machine to read char or font from rom
   always @(posedge sys_clk) begin : char_gen
      reg[12:0] text_rom_addr;
      reg       render_flag_prev;
      reg[2:0]  font_scan;
      reg[6:0]  text_buffer_index;
   
      text_buffer_we <= 0;
      if (!reset_n || vga_mode_changed || vga_frame_start) begin
         font_decode_state <= FD_IDLE;
         rd_req <= 0;
         wr_en <= 0;
         render_flag_prev <= 0;
         font_scan <= 0;
         text_rom_addr <= 13'h1e00;
         pixel_buffer_index_in <= 0;
         text_buffer_index <= 0;
         wr_bitmap_bits <= 0;
         dma_req <= 0;
      end else begin
         render_flag_prev <= render_flag;
         if (~render_flag_prev && render_flag) begin
            text_buffer_index <= 0;
            pixel_buffer_index_in <=  render_buffer ? 11'd640 : 11'd0;
            rd_req <= 0;
            wr_en <= 0;
            font_decode_state <= font_scan == 0 ? FD_TEXT_READ : FD_FONT_READ_REQ;
            dma_req <= 1;
         end else begin
            case (font_decode_state)
               FD_IDLE: 
               begin
                  rd_req <= 0;
                  wr_en <= 0;
               end
               FD_TEXT_READ:
               begin
                  addr_out <= text_rom_addr;
                  text_rom_addr <= text_rom_addr == 13'h1e14 ? 13'h1e00 : (text_rom_addr + 1'b1);

                  rd_req <= 1;
                  font_decode_state <= FD_TEXT_WAIT;
               end
               FD_TEXT_WAIT:
               if (rd_ack) begin
                  rd_req <= 0;
                  text_buffer_addr    <= text_buffer_index;
                  text_buffer_data_wr <= data_in;
                  text_buffer_we <= 1;
                  if (text_buffer_index == 79) begin
                     text_buffer_index <= 0;
                     font_decode_state <= FD_FONT_READ_REQ;
                  end else begin
                     text_buffer_index <= text_buffer_index + 1'b1;
                     font_decode_state <= FD_TEXT_READ;
                  end
               end
               FD_FONT_READ_REQ:
               begin
                  text_buffer_addr  <= text_buffer_index;
                  font_decode_state <= FD_FONT_READ_REQ_WAIT1;
               end
               FD_FONT_READ_REQ_WAIT1:
               begin
                  font_decode_state <= FD_FONT_READ_REQ_WAIT2;
               end
               FD_FONT_READ_REQ_WAIT2:
               begin
                  font_decode_state <= FD_FONT_READ;
               end
               FD_FONT_READ:
               begin
                  addr_out <= {font_base, text_buffer_data_rd[6:0], font_scan};
                  font_decode_state <= FD_FONT_WAIT;
                  rd_req <= 1;
               end
               FD_FONT_WAIT:
                  if (rd_ack) begin
                     rd_req <= 0;
                     pixel_out_next <= data_in;
                     font_decode_state <= FD_FONT_WRITE;
                  end
               FD_FONT_WRITE:
                  if (!wr_busy) begin
                     pixel_out <= pixel_out_next;
                     wr_en <= 1;
                     wr_bitmap_on   <= 8'b1;
                     wr_bitmap_off  <= 8'b0;
                     wr_bitmap_bits <= 4'd8;
                     font_decode_state <= FD_FONT_DONE;
                     
                     text_buffer_index <= text_buffer_index + 1'b1;
                  end
               FD_FONT_DONE:
               begin
                  wr_en <= 0;
                  if (text_buffer_index == 80) begin
                     font_decode_state <= FD_IDLE;
                     font_scan <= font_scan + 1'b1;
                     dma_req <= 0;
                  end else begin
                     font_decode_state <= FD_FONT_READ_REQ_WAIT1;
                     text_buffer_addr  <= text_buffer_index;
                     pixel_buffer_index_in <= pixel_buffer_index_in + 4'd8;
                  end
               end
            endcase
         end
      end      
   end         

   always @ (posedge sys_clk) begin : render_block
      reg[3:0] render_state;
      reg vga_scanline_start_prev;
      if (!reset_n || vga_mode_changed || vga_frame_start) begin
         render_buffer <= 0;
         render_flag   <= 0;
         render_state  <= 15;
      end else begin
         vga_scanline_start_prev <= vga_scanline_start;
         if (!vga_scanline_start_prev && vga_scanline_start) begin
            if (vga_render_start) begin
               render_state  <= 0;
               render_flag   <= 1;
            end else if (render_state != 15) begin
               if (vga_scale) begin
                  render_state  <= render_state == 7 ? 4'd0 : (render_state + 1'b1);
                  render_flag   <= render_state == 7 || render_state == 3;
                  render_buffer <= render_state == 7 ? 1'b0 : 1'b1;
               end else begin
                  render_state  <= render_state == 3 ? 4'd0 : (render_state + 1'b1);
                  render_flag   <= render_state[0];
                  render_buffer <= render_state == 3 ? 1'b0 : 1'b1;
               end
            end
         end
      end
   end
   
   // line render trigger
   reg render_buffer;
   reg render_flag  = 0;

   reg[10:0] pixel_buffer_index_in;
   reg wr_en = 0;
   reg[3:0] wr_bitmap_bits;
   reg[7:0] wr_bitmap_on;
   reg[7:0] wr_bitmap_off;
   reg[7:0] pixel_out;
   reg[7:0] pixel_out_next;
   wire wr_busy;

   reg[6:0] text_buffer_addr;
   reg text_buffer_we;
   reg[7:0] text_buffer_data_wr;
   wire[7:0] text_buffer_data_rd;
   
   spram #(80, 7, 8) text_buffer (
         .address(text_buffer_addr),
         .clock(sys_clk),
         .data(text_buffer_data_wr),
         .wren(text_buffer_we),
         .q(text_buffer_data_rd)
      );
   
   
   reg[15:0]  palette_wr_data;
   reg[7:0]   palette_wr_addr;
   reg        palette_wr_en;
   wire[15:0] palette_rd_addr;
   wire[7:0]  palette_rd_data;
   
   dpram #(256, 8, 18) palette (
         .data (palette_wr_data),
         .rdaddress (palette_rd_addr),
         .rdclock (vga_clk),
         .wraddress (palette_wr_addr),
         .wrclock (sys_clk),
         .wren (palette_wr_en),
         .q (palette_rd_data)
      );
   
   chroni_line_buffer chroni_line_buffer_inst (
         .reset_n(reset_n),
         .rd_clk(vga_clk),
         .wr_clk(sys_clk),
         .rd_addr(pixel_buffer_index_out),
         .wr_addr(pixel_buffer_index_in),
         .rd_data(pixel),
         .wr_data(pixel_out),
         .wr_en(wr_en),
         .wr_bitmap_on(wr_bitmap_on),
         .wr_bitmap_off(wr_bitmap_off),
         .wr_bitmap_bits(wr_bitmap_bits),
         .wr_busy(wr_busy)
      );
   
   wire [10:0] pixel_buffer_index_out;
   wire [7:0]pixel;
   wire vga_scale;
   wire vga_mode_changed;
   wire vga_frame_start;
   wire vga_render_start;
   wire vga_scanline_start;
   
   wire read_text = 0; // font_decode_state == FD_TEXT_READ || font_decode_state == FD_TEXT_WAIT;
   wire read_font = 0; // font_decode_state == FD_FONT_READ_REQ || font_decode_state == FD_FONT_READ_REQ_WAIT1 || font_decode_state == FD_FONT_READ_REQ_WAIT2;
   
   vga_output vga_output_inst (
         .sys_clk(sys_clk),
         .vga_clk(vga_clk),
         .reset_n(reset_n),
         .sys_vga_mode(vga_mode_in),
         .vga_hs(vga_hs),
         .vga_vs(vga_vs),
         .vga_r(vga_r),
         .vga_g(vga_g),
         .vga_b(vga_b),
         .mode_changed(vga_mode_changed),
         .frame_start(vga_frame_start),
         .render_start(vga_render_start),
         .scanline_start(vga_scanline_start),
         .pixel_buffer_index_out(pixel_buffer_index_out),
         .pixel(pixel),
         .pixel_scale(vga_scale),
         .read_text(read_text),
         .read_font(read_font),
         .palette_rd_addr(palette_rd_addr),
         .palette_rd_data(palette_rd_data)
      );

endmodule
