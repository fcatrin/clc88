`timescale 1ns / 1ps

module chroni (
      input vga_clk,
      input sys_clk,
      input reset_n,
      input [1:0] vga_mode_in,
      output vga_hs,
      output vga_vs,
      output [4:0] vga_r,
      output [5:0] vga_g,
      output [4:0] vga_b,
      input  [15:0] cpu_addr,
      output [7:0]  cpu_rd_data,
      input  [7:0]  cpu_wr_data,
      input         cpu_wr_en,
      output        irq
      );

   `include "chroni.vh"
   
   localparam PAL_WRITE_IDLE = 0;
   localparam PAL_WRITE_LO   = 1;
   localparam PAL_WRITE_HI   = 2;
   localparam PAL_WRITE      = 3;
   
   wire register_cs = cpu_addr[15:7] == 9'b100100000;
   reg[16:0] vram_address;
   reg[16:0] vram_address_aux;
   reg[1:0]  vram_cpu_byte_en;
   
   always @(posedge sys_clk) begin : register_write
      reg[1:0]  palette_write_state = PAL_WRITE_IDLE;
      reg[7:0]  palette_write_index;
      reg[15:0] palette_write_value;
      
      palette_wr_en <= 0;
      vram_cpu_wr_en <= 0;
      vram_cpu_byte_en <= 0;

      if (!reset_n) begin
         status_chroni_enabled  <= 1;
         status_irq_enabled     <= 0;
         status_sprites_enabled <= 1;
      end
      
      if (register_cs & cpu_wr_en_rising) begin
         case (cpu_addr[6:0])
            7'h00:
               display_list_addr[7:0]  <= cpu_wr_data;
            7'h01:
               display_list_addr[15:8] <= cpu_wr_data;
            7'h02:
               charset_base <= cpu_wr_data;
            7'h04:
            begin
               palette_write_index <= cpu_wr_data;
               palette_write_state <= PAL_WRITE_LO;
            end
            7'h05:
               if (palette_write_state == PAL_WRITE_LO) begin
                  palette_write_value[7:0]  <= cpu_wr_data;
                  palette_write_state   <= PAL_WRITE_HI;
               end else begin
                  palette_write_value[15:8] <= cpu_wr_data;
                  palette_write_state   <= PAL_WRITE;
               end
            7'h06:
               vram_address[7:0]  <= cpu_wr_data;
            7'h07:
               vram_address[15:8] <= cpu_wr_data;
            7'h08:
               vram_address[16] <= cpu_wr_data[0];
            7'h09:
            begin
               vram_cpu_wr_en   <= 1;
               vram_cpu_wr_data <= {cpu_wr_data, cpu_wr_data};
               vram_cpu_addr    <= vram_address[16:1];
               vram_cpu_byte_en <= vram_address[0] ? 2'b10 : 2'b11;
               vram_address     <= vram_address + 1'b1;
            end
            7'h0a:
               vram_address_aux[7:0]  <= cpu_wr_data;
            7'h0b:
               vram_address_aux[15:8] <= cpu_wr_data;
            7'h0c:
               vram_address_aux[16]   <= cpu_wr_data[0];
            7'h0d:
            begin
               vram_cpu_wr_en   <= 1;
               vram_cpu_wr_data <= {cpu_wr_data, cpu_wr_data};
               vram_cpu_addr    <= vram_address_aux[16:1];
               vram_cpu_byte_en <= vram_address_aux[0] ? 2'b10 : 2'b11;
               vram_address_aux <= vram_address_aux + 1'b1;
            end
            7'h12:
            begin
                status_chroni_enabled  <= cpu_wr_data[4];
                status_sprites_enabled <= cpu_wr_data[3];
                status_irq_enabled     <= cpu_wr_data[2];
            end
            7'h1a:
               border_color[7:0]  <= cpu_wr_data;
            7'h1b:
               border_color[15:8] <= cpu_wr_data;
            7'h26:
               vram_address[8:0] <= {cpu_wr_data, 1'b0};
            7'h27:
               vram_address[16:9] <= cpu_wr_data;
            7'h28:
               vram_address_aux[8:0] <= {cpu_wr_data, 1'b0};
            7'h29:
               vram_address_aux[16:9] <= cpu_wr_data;
         endcase
      end else if (palette_write_state == PAL_WRITE) begin
         palette_wr_en   <= 1;
         palette_wr_addr <= palette_write_index;
         palette_wr_data <= palette_write_value;
         
         palette_write_state <= PAL_WRITE_LO;
         palette_write_index <= palette_write_index + 1'b1; // autoincrement palette index
      end
   end
   
   assign cpu_rd_data = cpu_rd_data_reg;
   reg[7:0] cpu_rd_data_reg;
   
   always @(posedge sys_clk) begin : register_read
      if (register_cs) begin
         case (cpu_addr[6:0])
            7'h00:
               cpu_rd_data_reg <= display_list_addr[7:0];
            7'h01:
               cpu_rd_data_reg <= display_list_addr[15:8];
            7'h02:
               cpu_rd_data_reg <= charset_base;
            7'h06:
               cpu_rd_data_reg <= vram_address[7:0];
            7'h07:
               cpu_rd_data_reg <= vram_address[15:8];
            7'h08:
               cpu_rd_data_reg <= vram_address[16];
            7'h0a:
               cpu_rd_data_reg <= vram_address_aux[7:0];
            7'h0b:
               cpu_rd_data_reg <= vram_address_aux[15:8];
            7'h0c:
               cpu_rd_data_reg <= vram_address_aux[16];
            7'h12:
               cpu_rd_data_reg <= {vertical_irq_fired,
                                   scanline_irq_fired, 1'b0,
                                   status_chroni_enabled,
                                   status_sprites_enabled,
                                   status_irq_enabled, 2'b0};
            7'h1a:
               cpu_rd_data_reg <= border_color[7:0];
            7'h1b:
               cpu_rd_data_reg <= border_color[15:8];
            7'h26:
               cpu_rd_data_reg <= vram_address[8:1];
            7'h27:
               cpu_rd_data_reg <= vram_address[16:9];
            7'h28:
               cpu_rd_data_reg <= vram_address_aux[8:1];
            7'h29:
               cpu_rd_data_reg <= vram_address_aux[16:9];
         endcase
      end
   end

   localparam FD_IDLE       = 0;
   localparam FD_TEXT_START = 1;
   localparam FD_TEXT_READ  = 2;
   localparam FD_ATTR_READ  = 3;
   localparam FD_FONT_READ  = 6; 
   localparam FD_FONT_FETCH = 9;
   localparam FD_FONT_WAIT  = 10;
   localparam FD_FONT_WRITE = 13;
   localparam FD_FONT_DONE  = 14;
   reg[7:0]  charset_base;

   // state machine to read char or font from rom
   always @(posedge sys_clk) begin : char_gen
      reg[3:0]  font_decode_state;
      reg[16:0] data_memory_addr;
      reg[16:0] attr_memory_addr;
      reg[16:0] load_memory_addr;
      reg[16:0] load_attr_addr;
      reg[16:0] text_origin;
      reg[16:0] attr_origin;
      reg[7:0]  dl_mode_scanline;
      reg[7:0]  text_attr;
      reg[6:0]  text_buffer_index;
      reg[6:0]  attr_buffer_index;
      reg[1:0]  mem_wait;
      reg[7:0]  line_wrap;
      reg[7:0]  char_line_wrap;
      reg[7:0]  attr_line_wrap;
      reg[3:0]  bit_first;
      reg[3:0]  bit_last;
   
      text_buffer_we <= 0;
      attr_buffer_we <= 0;
      text_line_buffer_wr_en <= 0;
      if (!reset_n || vga_mode_changed || vga_frame_start) begin
         font_decode_state <= FD_IDLE;
         dl_mode_scanline <= 0;
         text_line_buffer_index_in <= 0;
         wr_bitmap_first <= 0;
         wr_bitmap_last  <= 0;
      end else begin
         if (vram_render_trigger_rising && is_text_mode) begin
            text_buffer_index <= 0;
            attr_buffer_index <= 0;
            text_line_buffer_index_in <= render_buffer ? 11'd640 : 11'd0;
            font_decode_state <= (dl_mode_scanline == 0 || lms_changed) ? FD_TEXT_READ : FD_FONT_READ;
            mem_wait <= (dl_mode_scanline == 0 || lms_changed) ? 2'd3 : 2'd2;
            bit_first <= 4'd8 - dl_scroll_fine_x;
            bit_last  <= 0;
            if (lms_changed) begin
               text_origin      <= {dl_lms, 1'b0};
               load_memory_addr <= {dl_lms, 1'b0}  + dl_scroll_left;
               data_memory_addr <= {dl_lms, 1'b0}  + dl_scroll_left;

               attr_origin      <= {dl_attr, 1'b0};
               load_attr_addr   <= {dl_attr, 1'b0} + dl_scroll_left;
               attr_memory_addr <= {dl_attr, 1'b0} + dl_scroll_left;

               dl_mode_scanline <= 0;
            end else begin
               data_memory_addr <= load_memory_addr;
               attr_memory_addr <= load_attr_addr;
            end
            line_wrap = dl_scroll ? (dl_scroll_width - dl_scroll_left - 1) : 8'hff;
            char_line_wrap = line_wrap;
            attr_line_wrap = line_wrap;
         end else begin
            case (font_decode_state)
               FD_TEXT_READ: // transfer line of text from vram to text_buffer
               begin
                  vram_char_addr    <= data_memory_addr;
                  data_memory_addr  <= data_memory_addr + 1'b1;

                  char_line_wrap    <= char_line_wrap - 1'b1;
                  if (char_line_wrap == 0) begin
                     data_memory_addr <= text_origin;
                     char_line_wrap   <= 8'hff;
                  end
                  if (mem_wait == 0) begin
                     text_buffer_addr    <= text_buffer_index;
                     text_buffer_data_wr <= vram_chroni_rd_byte;
                     text_buffer_we <= 1;

                     text_buffer_index <= text_buffer_index + 1'b1;
                     if (text_buffer_index == dl_mode_cols-1) begin
                        text_buffer_index <= 0;
                        mem_wait <= 3;
                        font_decode_state <= FD_ATTR_READ;
                     end
                  end else begin
                     mem_wait <= mem_wait - 1'b1;
                  end
               end
               FD_ATTR_READ: // transfer line of attrs from vram to attr_buffer
               begin
                  vram_char_addr    <= attr_memory_addr;
                  attr_memory_addr  <= attr_memory_addr + 1'b1;

                  attr_line_wrap    <= attr_line_wrap - 1'b1;
                  if (attr_line_wrap == 0) begin
                     attr_memory_addr <= attr_origin;
                     attr_line_wrap   <= 8'hff;
                  end

                  if (mem_wait == 0) begin
                     attr_buffer_addr    <= attr_buffer_index;
                     attr_buffer_data_wr <= vram_chroni_rd_byte;
                     attr_buffer_we <= 1;
                     attr_buffer_index <= attr_buffer_index + 1'b1;
                     if (attr_buffer_index == dl_mode_cols-1) begin
                        attr_buffer_index <= 0;
                        mem_wait <= 2;
                        font_decode_state <= FD_FONT_READ;
                     end
                  end else begin
                     mem_wait <= mem_wait - 1'b1;
                  end
               end
               FD_FONT_READ: // read font data from each char on text_buffer
               begin
                  if (mem_wait == 2) begin
                     text_buffer_addr  <= text_buffer_index;
                     text_buffer_index <= text_buffer_index + 1'b1;
                     attr_buffer_addr  <= attr_buffer_index;
                     attr_buffer_index <= attr_buffer_index + 1'b1;
                  end else if (mem_wait == 0) begin
                     font_decode_state <= FD_FONT_FETCH;
                  end
                  mem_wait <= mem_wait - 1'b1;
               end
               FD_FONT_FETCH:
               begin
                  // read next char in advance
                  text_buffer_addr  <= text_buffer_index;
                  text_buffer_index <= text_buffer_index + 1'b1;
                  attr_buffer_addr  <= attr_buffer_index;
                  attr_buffer_index <= attr_buffer_index + 1'b1;

                  // fetch font data
                  vram_char_addr  <= {charset_base[6:0] + text_buffer_data_rd[7], text_buffer_data_rd[6:0], dl_mode_scanline[2:0]};
                  text_attr <= attr_buffer_data_rd;
                  font_decode_state <= FD_FONT_WAIT;
                  mem_wait <= 2;
               end
               FD_FONT_WAIT:
               begin
                  if (mem_wait == 0) begin
                     text_pixel_out_next <= vram_chroni_rd_byte;
                     font_decode_state <= FD_FONT_WRITE;
                  end
                  mem_wait <= mem_wait - 1'b1;
               end
               FD_FONT_WRITE:
               if (!wr_busy) begin
                  text_pixel_out <= text_pixel_out_next;
                  text_line_buffer_wr_en <= 1;
                  wr_bitmap_on    <= text_attr[3:0];
                  wr_bitmap_off   <= text_attr[7:4];
                  wr_bitmap_first <= bit_first;
                  wr_bitmap_last  <= bit_last;
                  font_decode_state <= FD_FONT_DONE;
               end
               FD_FONT_DONE:
               if (text_buffer_index == dl_mode_cols+1) begin
                  font_decode_state <= FD_IDLE;
                  dl_mode_scanline <= dl_mode_scanline + 1'b1;
                  if (dl_mode_scanline == dl_mode_scanlines) begin
                     load_memory_addr <= load_memory_addr + dl_mode_pitch;
                     load_attr_addr <= load_attr_addr + dl_mode_pitch;
                     text_origin <= text_origin + dl_mode_pitch;
                     attr_origin <= attr_origin + dl_mode_pitch;
                     dl_mode_scanline <= 0;
                  end
               end else begin
                  font_decode_state <= FD_FONT_FETCH;
                  text_line_buffer_index_in <= text_line_buffer_index_in + bit_first;
                  bit_first <= 4'd8;
                  bit_last  <= text_buffer_index != dl_mode_cols || dl_scroll_fine_x == 0 ?
                               0 : (4'd8 - dl_scroll_fine_x);
               end
            endcase
         end
      end      
   end         

   localparam TL_IDLE        = 0;
   localparam TL_SCREEN_READ = 1;
   localparam TL_TILE_READ   = 2;
   localparam TL_TILE_FETCH  = 3;
   localparam TL_TILE_WAIT   = 4;
   localparam TL_TILE_WRITE  = 5;
   localparam TL_TILE_NEXT   = 6;
   localparam TL_TILE_DONE   = 7;

   // state machine to read tiles
   always @(posedge sys_clk) begin : tile_gen
      reg[2:0]  tile_decode_state;
      reg[15:0] data_memory_addr;
      reg[15:0] load_memory_addr;
      reg[7:0]  dl_mode_scanline;
      reg[5:0]  tile_buffer_index;
      reg[3:0]  tile_palette;
      reg       tile_pixel_index;
      reg[1:0]  mem_wait;

      tile_buffer_we <= 0;
      tile_line_buffer_wr_en <= 0;
      if (!reset_n || vga_mode_changed || vga_frame_start) begin
         tile_decode_state <= TL_IDLE;
         dl_mode_scanline <= 0;
         tile_line_buffer_index_in <= 0;
         wr_tile_pixels <= 0;
      end else begin
         if (vram_render_trigger_rising && !is_text_mode) begin
            tile_buffer_index <= 0;
            tile_line_buffer_index_in <= render_buffer ? 11'd640 : 11'd0;
            tile_decode_state <= (dl_mode_scanline == 0 || lms_changed) ? TL_SCREEN_READ : TL_TILE_READ;
            mem_wait <= (dl_mode_scanline == 0 || lms_changed) ? 2'd3 : 2'd2;
            if (lms_changed) begin
               load_memory_addr <= dl_lms;
               data_memory_addr <= dl_lms;

               dl_mode_scanline <= 0;
            end else begin
               data_memory_addr <= load_memory_addr;
            end
         end else begin
            case (tile_decode_state)
               TL_SCREEN_READ: // transfer line of text from vram to tile_buffer
               begin
                  vram_tile_addr    <= data_memory_addr;
                  data_memory_addr  <= data_memory_addr + 1'b1;
                  if (mem_wait == 0) begin
                     tile_buffer_addr    <= tile_buffer_index;
                     tile_buffer_data_wr <= vram_chroni_rd_word;
                     tile_buffer_we <= 1;
                     if (tile_buffer_index == dl_mode_pitch-1) begin
                        tile_buffer_index <= 0;
                        mem_wait <= 3;
                        tile_decode_state <= TL_TILE_READ;
                     end else begin
                        tile_buffer_index <= tile_buffer_index + 1'b1;
                     end
                  end else begin
                     mem_wait <= mem_wait - 1'b1;
                  end
               end
               TL_TILE_READ: // read font data from each char on text_buffer
               begin
                  if (mem_wait == 2) begin
                     tile_buffer_addr  <= tile_buffer_index;
                     tile_buffer_index <= tile_buffer_index + 1'b1;
                  end else if (mem_wait == 0) begin
                     tile_pixel_index  <= 0;
                     tile_decode_state <= TL_TILE_FETCH;
                  end
                  mem_wait <= mem_wait - 1'b1;
               end
               TL_TILE_FETCH:
               begin
                  // fetch tile data
                  tile_palette      <= tile_buffer_data_rd[15:12];
                  vram_tile_addr    <= {tile_buffer_data_rd[11:0], dl_mode_scanline[2:0], tile_pixel_index};
                  tile_decode_state <= TL_TILE_WAIT;
                  mem_wait <= 2;
               end
               TL_TILE_WAIT:
               begin
                  if (mem_wait == 0) begin
                     tile_pixel_out_next <= vram_chroni_rd_word;
                     tile_decode_state   <= TL_TILE_WRITE;
                  end
                  mem_wait <= mem_wait - 1'b1;
               end
               TL_TILE_WRITE:
               if (!wr_busy) begin
                  tile_pixel_out         <= tile_pixel_out_next;
                  wr_tile_palette        <= tile_palette;
                  tile_line_buffer_wr_en <= 1;
                  wr_tile_pixels         <= 3'd4;
                  tile_decode_state      <= TL_TILE_NEXT;
               end
               TL_TILE_NEXT:
               begin
                  tile_line_buffer_index_in <= tile_line_buffer_index_in + 4'd4;
                  if (tile_pixel_index == 0) begin
                     tile_decode_state  <= TL_TILE_FETCH;
                     tile_pixel_index   <= 1;
                  end else begin
                     tile_decode_state <= TL_TILE_DONE;
                  end
               end
               TL_TILE_DONE:
               if (tile_buffer_index == dl_mode_pitch+1) begin
                  tile_decode_state <= TL_IDLE;
                  dl_mode_scanline <= dl_mode_scanline + 1'b1;
                  if (dl_mode_scanline == dl_mode_scanlines) begin
                     load_memory_addr <= load_memory_addr + dl_mode_pitch;
                     dl_mode_scanline <= 0;
                  end
               end else begin
                  tile_decode_state         <= TL_TILE_READ;
                  tile_pixel_index          <= 0;
               end
            endcase
         end
      end
   end

   localparam DL_IDLE        = 0;
   localparam DL_READ        = 1;
   localparam DL_READ_WAIT   = 2;
   localparam DL_LMS         = 3;
   localparam DL_LMS_READ    = 4;
   localparam DL_SCROLL      = 5;
   localparam DL_SCROLL_READ = 6;
   localparam DL_EXEC        = 7;
   localparam DL_WAIT        = 8;
   reg[3:0] dlproc_state;
   
   reg[15:0] display_list_addr;
   reg[15:0] dl_lms;
   reg[15:0] dl_attr;
   reg[3:0]  dl_mode;
   reg[7:0]  dl_mode_pitch;
   reg[7:0]  dl_mode_cols;
   reg[7:0]  dl_mode_scanlines;
   reg       dl_narrow;
   reg       dl_scroll;
   reg[7:0]  dl_scanlines;

   reg[7:0] dl_scroll_width;
   reg[7:0] dl_scroll_height;
   reg[7:0] dl_scroll_left;
   reg[7:0] dl_scroll_top;
   reg[2:0] dl_scroll_fine_x;
   reg[2:0] dl_scroll_fine_y;

   reg vram_render;
   reg vram_render_trigger;
   reg lms_changed;
   
   always @ (posedge sys_clk) begin : dlproc
      reg report_lms_changed;
      reg[15:0] display_list_ptr;
      reg[1:0] mem_wait;
      reg[1:0] addr_part;
      reg[1:0] scroll_part;

      vram_render_trigger <= 0;
      lms_changed <= 0;
      if (!reset_n || vga_mode_changed || vga_frame_start) begin
         display_list_ptr <= display_list_addr;
         vram_read_dl <= 0;
         dlproc_state <= DL_IDLE;
         dl_mode <= 0;
         dl_scanlines <= 0;
         double_pixel <= 0;
         scanline_out <= 0;
      end else if (render_flag_rising) begin
         report_lms_changed <= 0;
         blank_scanline <= 1;
         if (dl_mode == 4'hf) begin
            dlproc_state <= DL_IDLE;
         end else if (dl_scanlines == 0) begin
            dlproc_state <= DL_READ;
         end else begin
            dl_scanlines <= dl_scanlines - 1'b1;
            vram_render_trigger <= vram_render;
            blank_scanline <= dl_mode == 0;
            scanline_out <= scanline_out + 1'b1;
         end
      end else begin
            case(dlproc_state)
            DL_READ:
            begin
               vram_render      <= 0;
               vram_read_dl     <= 1;
               vram_dl_addr     <= display_list_ptr;
               display_list_ptr <= display_list_ptr + 1'b1;
               
               mem_wait <= 2;
               dlproc_state <= DL_READ_WAIT;
            end
            DL_READ_WAIT:
            begin
               mem_wait <= mem_wait - 1'b1;
               if (mem_wait == 0) begin
                  dl_scroll    = vram_chroni_rd_word[13];
                  dl_narrow    = vram_chroni_rd_word[12];
                  dl_mode      = vram_chroni_rd_word[11:8];
                  dl_scanlines = vram_chroni_rd_word[7:0] - 1'b1;
                  dlproc_state <=
                     ((dl_mode == 0) ? DL_EXEC :
                      (dl_mode == 4'hf ? DL_IDLE : DL_LMS));
               end
            end
            DL_LMS:
            begin
               vram_dl_addr     <= display_list_ptr;
               display_list_ptr <= display_list_ptr + 1'b1;
               mem_wait <= 2;
               addr_part <= 1;
               dlproc_state <= DL_LMS_READ;
            end
            DL_LMS_READ:
            begin
               mem_wait <= mem_wait - 1'b1;
               if (mem_wait == 0) begin
                  case(addr_part)
                     1: dl_lms  <= vram_chroni_rd_word;
                     0: dl_attr <= vram_chroni_rd_word;
                  endcase
                  
                  if (addr_part == 0 || dl_mode == 3) begin
                     report_lms_changed <= 1;
                     scroll_part = 2'b0;
                     dlproc_state <= dl_scroll ? DL_SCROLL : DL_EXEC;
                  end else begin
                     vram_dl_addr     <= display_list_ptr;
                     display_list_ptr <= display_list_ptr + 1'b1;
                     mem_wait <= 2;
                     addr_part <= addr_part - 1'b1;
                  end
               end
            end
            DL_SCROLL:
            begin
                vram_dl_addr     <= display_list_ptr;
                display_list_ptr <= display_list_ptr + 1'b1;
                mem_wait <= 2;
                dlproc_state <= DL_SCROLL_READ;
            end
            DL_SCROLL_READ:
            begin
                mem_wait <= mem_wait - 1'b1;
                if (mem_wait == 0) begin
                    case (scroll_part)
                        2'd0 : begin
                            dl_scroll_width  = vram_chroni_rd_word[7:0];
                            dl_scroll_height = vram_chroni_rd_word[15:8];
                        end
                        2'd1 : begin
                            dl_scroll_left = vram_chroni_rd_word[7:0];
                            dl_scroll_top  = vram_chroni_rd_word[15:8];
                        end
                        2'd2 : begin
                            dl_scroll_fine_x = vram_chroni_rd_word[2:0];
                            dl_scroll_fine_y = vram_chroni_rd_word[10:8];
                        end
                    endcase
                    scroll_part  <= scroll_part + 1'b1;
                    dlproc_state <= scroll_part == 2 ? DL_EXEC : DL_SCROLL;
                end
            end
            DL_EXEC:
            begin
               dlproc_state = DL_WAIT;
               vram_read_dl <= 0;
               vram_render_trigger <= 1;
               lms_changed <= report_lms_changed;
               blank_scanline <= 0;
               if (dl_mode == 1) begin
                  dl_mode_scanlines <= 7;
                  dl_mode_cols = (dl_narrow ? 8'd64 : 8'd80) + (dl_scroll_fine_x!=0 ? 1 : 0);
                  dl_mode_pitch <= dl_scroll ? dl_scroll_width : dl_mode_cols;
                  double_pixel <= 0;
                  vram_render <= 1;
               end else if (dl_mode == 2) begin
                  dl_mode_scanlines <= 7;
                  dl_mode_cols = (dl_narrow ? 8'd32 : 8'd40) + (dl_scroll_fine_x!=0 ? 1 : 0);
                  dl_mode_pitch <= dl_scroll ? dl_scroll_width : dl_mode_cols;
                  double_pixel <= 1;
                  vram_render <= 1;
               end else if (dl_mode == 3) begin
                  dl_mode_scanlines <= 7;
                  dl_mode_cols = dl_narrow ? 8'd32 : 8'd40;
                  dl_mode_pitch <= dl_scroll ? dl_scroll_width : dl_mode_cols;
                  double_pixel <=1;
                  vram_render <= 1;
               end else if (dl_mode == 0) begin
                  blank_scanline <= 1;
                  vram_render_trigger <= 0;
               end
            end
         endcase
      end
   end
   
   always @ (posedge sys_clk) begin : render_block
      reg[3:0] render_state;
      if (!reset_n || vga_mode_changed || vga_frame_start) begin
         render_buffer <= 0;
         render_flag   <= 0;
         render_state  <= 15;
      end else begin
         if (vga_render_start | vga_scanline_start_rising) begin
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

   reg status_chroni_enabled;
   reg status_irq_enabled;
   reg status_sprites_enabled;

   reg[7:0] scanline_irq;
   reg[7:0] scanline_out;

   wire v_blank;
   wire h_blank;
   reg scanline_irq_fired;
   reg vertical_irq_fired;
   assign irq = status_irq_enabled && (scanline_irq_fired || vertical_irq_fired);

   always @ (posedge sys_clk) begin : irq_block
       if (!reset_n) begin
           scanline_irq_fired <= 0;
           vertical_irq_fired <= 0;
       end else begin
           scanline_irq_fired <= h_blank && (scanline_out + 1'b1) == scanline_irq;
           vertical_irq_fired <= v_blank;
       end
   end

   // line render trigger
   reg render_buffer;
   reg render_flag  = 0;

   reg [6:0] text_buffer_addr;
   reg       text_buffer_we;
   reg [7:0] text_buffer_data_wr;
   wire[7:0] text_buffer_data_rd;
   spram #(80, 7, 8) text_buffer (
         .address(text_buffer_addr),
         .clock(sys_clk),
         .data(text_buffer_data_wr),
         .wren(text_buffer_we),
         .q(text_buffer_data_rd)
      );

   reg [5:0]  tile_buffer_addr;
   reg        tile_buffer_we;
   reg [15:0] tile_buffer_data_wr;
   wire[15:0] tile_buffer_data_rd;
   spram #(40, 6, 16) tile_buffer (
         .address(tile_buffer_addr),
         .clock(sys_clk),
         .data(tile_buffer_data_wr),
         .wren(tile_buffer_we),
         .q(tile_buffer_data_rd)
      );

   reg[6:0] attr_buffer_addr;
   reg attr_buffer_we;
   reg[7:0] attr_buffer_data_wr;
   wire[7:0] attr_buffer_data_rd;

   spram #(80, 7, 8) attr_buffer (
         .address(attr_buffer_addr),
         .clock(sys_clk),
         .data(attr_buffer_data_wr),
         .wren(attr_buffer_we),
         .q(attr_buffer_data_rd)
      );

   
   reg[15:0]  palette_wr_data;
   reg[7:0]   palette_wr_addr;
   reg        palette_wr_en;
   
   wire[7:0]  palette_rd_addr = pixel;
   wire[15:0] palette_rd_data;
   
   dpram #(256, 8, 16) palette (
         .data (palette_wr_data),
         .rdaddress (palette_rd_addr),
         .rdclock (vga_clk),
         .wraddress (palette_wr_addr),
         .wrclock (sys_clk),
         .wren (palette_wr_en),
         .q (palette_rd_data)
      );

   reg        vram_cpu_wr_en;
   reg[15:0]  vram_cpu_wr_data;
   reg[15:0]  vram_cpu_addr;

   wire[7:0]  vram_chroni_rd_byte = vram_read_byte_en ? vram_chroni_rd_word[15:8] : vram_chroni_rd_word[7:0];
   wire[15:0] vram_chroni_rd_word;
   wire[15:0] vram_cpu_rd_word;
   reg[16:0]  vram_char_addr;
   reg[15:0]  vram_dl_addr;
   reg[15:0]  vram_tile_addr;
   
   reg vram_read_dl;

   wire       is_text_mode = dl_mode < 3;
   wire[15:0] vram_chroni_addr  = vram_read_dl ? vram_dl_addr : (is_text_mode ? vram_char_addr[16:1] : vram_tile_addr);
   wire       vram_read_byte_en = vram_char_addr[0];

   vram16_dp vram (
        .clock_a (sys_clk),
        .clock_b (sys_clk),
        .address_a ( vram_cpu_addr ),
        .address_b ( vram_chroni_addr ),
        .byteena_a ( vram_cpu_byte_en ),
        .data_a ( vram_cpu_wr_data ),
        .data_b ( 16'b0 ),
        .wren_a ( vram_cpu_wr_en),
        .wren_b ( 1'b0 ),
        .q_a ( vram_cpu_rd_word ),
        .q_b ( vram_chroni_rd_word )
    );

   reg[3:0]   wr_bitmap_first;
   reg[3:0]   wr_bitmap_last;
   reg[7:0]   wr_bitmap_on;
   reg[7:0]   wr_bitmap_off;
   reg[7:0]   text_pixel_out;
   reg[7:0]   text_pixel_out_next;
   reg[15:0]  tile_pixel_out;
   reg[15:0]  tile_pixel_out_next;
   reg[2:0]   wr_tile_pixels;
   reg[3:0]   wr_tile_palette;
   wire wr_busy;

   reg[10:0] text_line_buffer_index_in;
   reg[10:0] tile_line_buffer_index_in;
   reg       text_line_buffer_wr_en;
   reg       tile_line_buffer_wr_en;

   wire[15:0] pixel_out            = is_text_mode ? {8'b0, text_pixel_out} : tile_pixel_out;
   wire       line_buffer_wr_en    = is_text_mode ? text_line_buffer_wr_en : tile_line_buffer_wr_en;
   wire[10:0] line_buffer_index_in = is_text_mode ? text_line_buffer_index_in : tile_line_buffer_index_in;
   chroni_line_buffer chroni_line_buffer_inst (
         .reset_n(reset_n),
         .rd_clk(vga_clk),
         .wr_clk(sys_clk),
         .rd_addr(pixel_buffer_index_out),
         .wr_addr(line_buffer_index_in),
         .rd_data(pixel),
         .wr_data(pixel_out),
         .wr_en(line_buffer_wr_en),
         .wr_bitmap_on(wr_bitmap_on),
         .wr_bitmap_off(wr_bitmap_off),
         .wr_bitmap_first(wr_bitmap_first),
         .wr_bitmap_last(wr_bitmap_last),
         .wr_tile_pixels(wr_tile_pixels),
         .wr_tile_palette(wr_tile_palette),
         .wr_busy(wr_busy)
      );

   reg[15:0]   border_color = 0;
   
   wire [10:0] pixel_buffer_index_out;
   wire [7:0]  pixel;
   
   wire vga_scale;
   wire vga_mode_changed;
   wire vga_frame_start;
   wire vga_render_start;
   wire vga_scanline_start;
   
   reg blank_scanline;
   reg double_pixel;
   
   wire read_text = 0; // font_decode_state == FD_TEXT_READ || font_decode_state == FD_FONT_READ || font_decode_state == FD_FONT_FETCH;
   wire read_font = 0; // font_decode_state == FD_FONT_WRITE;
   
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
         .pixel(palette_rd_data),
         .pixel_scale(vga_scale),
         .read_text(read_text),
         .read_font(read_font),
         .blank_scanline(blank_scanline),
         .border_color(border_color),
         .double_pixel(double_pixel),
         .narrow(dl_narrow),
         .v_blank(v_blank),
         .h_blank(h_blank)
      );

   wire cpu_wr_en_rising;
   edge_detector edge_cpu_wr_en (
         .clk(sys_clk),
         .reset_n(reset_n),
         .in(cpu_wr_en),
         .rising(cpu_wr_en_rising)
      );

   wire vram_render_trigger_rising;
   edge_detector edge_vram_render_trigge (
         .clk(sys_clk),
         .reset_n(reset_n),
         .in(vram_render_trigger),
         .rising(vram_render_trigger_rising)
      );
   
   wire render_flag_rising;
   edge_detector edge_render_flag (
         .clk(sys_clk),
         .reset_n(reset_n),
         .in(render_flag),
         .rising(render_flag_rising)
      );
   
   wire vga_scanline_start_rising;
   edge_detector edge_vga_scanline_start (
         .clk(sys_clk),
         .reset_n(reset_n),
         .in(vga_scanline_start),
         .rising(vga_scanline_start_rising)
      );
   
endmodule
