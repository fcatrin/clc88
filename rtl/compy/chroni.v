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
      input         cpu_wr_en
      );

   `include "chroni.vh"
   
   localparam PAL_WRITE_IDLE = 0;
   localparam PAL_WRITE_LO   = 1;
   localparam PAL_WRITE_HI   = 2;
   localparam PAL_WRITE      = 3;
   
   wire register_cs = cpu_addr[15:7] == 9'b100100000;
   reg[16:0] vram_address;
   reg[16:0] vram_address_aux;
   
   always @(posedge sys_clk) begin : register_write
      reg[1:0]  palette_write_state = PAL_WRITE_IDLE;
      reg[7:0]  palette_write_index;
      reg[15:0] palette_write_value;
      
      palette_wr_en <= 0;
      cpu_port_cs <= 0;
      cpu_port_wr_en <= 0;
      if (register_cs && cpu_wr_en) begin
         case (cpu_addr[6:0])
            7'h00:
               display_list_addr[8:1]  <= cpu_wr_data;
            7'h01:
               display_list_addr[16:9] <= cpu_wr_data;
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
               cpu_port_cs      <= 1;
               cpu_port_wr_en   <= 1;
               cpu_port_wr_data <= cpu_wr_data;
               cpu_port_addr    <= vram_address;
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
               cpu_port_cs      <= 1;
               cpu_port_wr_en   <= 1;
               cpu_port_wr_data <= cpu_wr_data;
               cpu_port_addr    <= vram_address_aux;
               vram_address_aux <= vram_address_aux + 1'b1;
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
               cpu_rd_data_reg <= display_list_addr[8:1];
            7'h01:
               cpu_rd_data_reg <= display_list_addr[16:9];
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
   reg[3:0]  font_decode_state;
   reg[7:0]  charset_base;
   reg[7:0]  pitch;

   // state machine to read char or font from rom
   always @(posedge sys_clk) begin : char_gen
      reg[16:0] data_memory_addr;
      reg[16:0] attr_memory_addr;
      reg[16:0] load_memory_addr;
      reg[16:0] load_attr_addr;
      reg[7:0]  text_attr;
      reg       vram_render_trigger_prev;
      reg[2:0]  font_scan;
      reg[6:0]  text_buffer_index;
      reg[6:0]  attr_buffer_index;
      reg[1:0]  mem_wait;
   
      text_buffer_we <= 0;
      attr_buffer_we <= 0;
      wr_en <= 0;
      if (!reset_n || vga_mode_changed || vga_frame_start) begin
         font_decode_state <= FD_IDLE;
         vram_render_trigger_prev <= 0;
         font_scan <= 0;
         pixel_buffer_index_in <= 0;
         wr_bitmap_bits <= 0;
      end else begin
         vram_render_trigger_prev <= vram_render_trigger;
         if (~vram_render_trigger_prev && vram_render_trigger) begin
            text_buffer_index <= 0;
            attr_buffer_index <= 0;
            pixel_buffer_index_in <= render_buffer ? 11'd640 : 11'd0;
            font_decode_state <= font_scan == 0 ? FD_TEXT_READ : FD_FONT_READ;
            mem_wait <= font_scan == 0 ? 2'd3 : 2'd2;
            if (lms_changed) begin
               load_memory_addr <= dl_lms;
               data_memory_addr <= dl_lms;
               
               load_attr_addr   <= dl_attr;
               attr_memory_addr <= dl_attr;
            end else begin
               data_memory_addr <= load_memory_addr;
               attr_memory_addr <= load_attr_addr;
            end
         end else begin
            case (font_decode_state)
               FD_TEXT_READ: // transfer line of text from vram to text_buffer
               begin
                  vram_char_addr <= data_memory_addr;
                  data_memory_addr <= data_memory_addr + 1'b1;
                  if (mem_wait == 0) begin
                     text_buffer_addr    <= text_buffer_index;
                     text_buffer_data_wr <= vram_chroni_rd_data;
                     text_buffer_we <= 1;
                     if (text_buffer_index == pitch-1) begin
                        text_buffer_index <= 0;
                        mem_wait <= 3;
                        font_decode_state <= FD_ATTR_READ;
                     end else begin
                        text_buffer_index <= text_buffer_index + 1'b1;
                     end
                  end else begin
                     mem_wait <= mem_wait - 1'b1;
                  end
               end
               FD_ATTR_READ: // transfer line of attrs from vram to attr_buffer
               begin
                  vram_char_addr   <= attr_memory_addr;
                  attr_memory_addr <= attr_memory_addr + 1'b1;
                  if (mem_wait == 0) begin
                     attr_buffer_addr    <= attr_buffer_index;
                     attr_buffer_data_wr <= vram_chroni_rd_data;
                     attr_buffer_we <= 1;
                     if (attr_buffer_index == pitch-1) begin
                        attr_buffer_index <= 0;
                        mem_wait <= 2;
                        font_decode_state <= FD_FONT_READ;
                     end else begin
                        attr_buffer_index <= attr_buffer_index + 1'b1;
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
                  vram_char_addr <= {charset_base[6:0] + text_buffer_data_rd[7], text_buffer_data_rd[6:0], font_scan};
                  text_attr <= attr_buffer_data_rd;
                  font_decode_state <= FD_FONT_WAIT;
                  mem_wait <= 2;
               end
               FD_FONT_WAIT:
               begin
                  if (mem_wait == 0) begin
                     pixel_out_next <= vram_chroni_rd_data;
                     font_decode_state <= FD_FONT_WRITE;
                  end
                  mem_wait <= mem_wait - 1'b1;
               end
               FD_FONT_WRITE:
               if (!wr_busy) begin
                  pixel_out <= pixel_out_next;
                  wr_en <= 1;
                  wr_bitmap_on   <= text_attr[3:0];
                  wr_bitmap_off  <= text_attr[7:4];
                  wr_bitmap_bits <= 4'd8;
                  font_decode_state <= FD_FONT_DONE;
               end
               FD_FONT_DONE:
               if (text_buffer_index == pitch+1) begin
                  font_decode_state <= FD_IDLE;
                  font_scan <= font_scan + 1'b1;
                  if (font_scan == 7) begin
                     load_memory_addr <= load_memory_addr + pitch;
                     load_attr_addr <= load_attr_addr + pitch;
                  end
               end else begin
                  font_decode_state <= FD_FONT_FETCH;
                  pixel_buffer_index_in <= pixel_buffer_index_in + 4'd8;
               end
            endcase
         end
      end      
   end         

   localparam DL_IDLE = 0;
   localparam DL_READ = 1;
   localparam DL_READ_WAIT = 2;
   localparam DL_LMS  = 3;
   localparam DL_LMS_READ = 4;
   localparam DL_EXEC = 5;
   localparam DL_WAIT = 6;
   reg[3:0] dlproc_state;
   
   reg[16:0] display_list_addr;
   reg[16:0] dl_lms;
   reg[16:0] dl_attr;
   reg[3:0]  dl_inst;
   reg[7:0]  dl_value;
   reg vram_render;
   reg vram_render_trigger;
   reg lms_changed;
   
   always @ (posedge sys_clk) begin : dlproc
      reg report_lms_changed;
      reg[16:0] display_list_ptr;
      reg      render_flag_prev;
      reg[1:0] mem_wait;
      reg[2:0] addr_part;
      reg[3:0] scanlines;
      
      render_flag_prev <= render_flag;
      vram_render_trigger <= 0;
      lms_changed <= 0;
      if (!reset_n || vga_mode_changed || vga_frame_start) begin
         display_list_ptr <= display_list_addr;
         render_flag_prev <= 0;
         vram_read_dl <= 0;
         dlproc_state <= DL_IDLE;
         dl_inst <= 0;
         scanlines <= 0;
         double_pixel <= 0;
      end else if (~render_flag_prev & render_flag) begin
         report_lms_changed <= 0;
         blank_scanline <= 1;
         if (scanlines == 0) begin
            dlproc_state <= dl_inst == 1 ? DL_IDLE : DL_READ;
         end else begin
            scanlines <= scanlines - 1'b1;
            vram_render_trigger <= vram_render;
            blank_scanline <= dl_inst == 0;
         end
      end else begin
            case(dlproc_state)
            DL_READ:
            begin
               vram_render  <= 0;
               vram_read_dl <= 1;
               vram_dl_addr     <= display_list_ptr;
               display_list_ptr <= display_list_ptr + 1'b1;
               
               mem_wait <= 2;
               dlproc_state <= DL_READ_WAIT;
            end
            DL_READ_WAIT:
            begin
               vram_read_dl <= 0;
               mem_wait <= mem_wait - 1'b1;
               if (mem_wait == 0) begin
                  dl_inst  <= vram_chroni_rd_data[3:0];
                  dl_value <= vram_chroni_rd_data;
                  dlproc_state <= 
                     vram_chroni_rd_data[3:0] == 0 ? DL_EXEC :
                     (vram_chroni_rd_data[6] ? (vram_chroni_rd_data[3:0] == 1 ? DL_IDLE : DL_LMS) : DL_EXEC);
               end
            end
            DL_LMS:
            begin
               vram_read_dl <= 1;
               vram_dl_addr     <= display_list_ptr;
               display_list_ptr <= display_list_ptr + 1'b1;
               mem_wait <= 2;
               addr_part <= 3;
               dlproc_state <= DL_LMS_READ;
            end
            DL_LMS_READ:
            begin
               vram_read_dl <= 1;
               mem_wait <= mem_wait - 1'b1;
               if (mem_wait == 0) begin
                  case(addr_part)
                     3: dl_lms[8:0]   <= {vram_chroni_rd_data, 1'b0};
                     2: dl_lms[16:9]  <= vram_chroni_rd_data;
                     1: dl_attr[8:0]  <= {vram_chroni_rd_data, 1'b0};
                     0: dl_attr[16:9] <= vram_chroni_rd_data;
                  endcase
                  
                  if (addr_part == 0) begin
                     report_lms_changed <= 1;
                     dlproc_state <= DL_EXEC;
                  end else begin
                     vram_dl_addr     <= display_list_ptr;
                     display_list_ptr <= display_list_ptr + 1'b1;
                     mem_wait <= 2;
                     addr_part <= addr_part - 1'b1;
                  end
               end
            end
            DL_EXEC:
            begin
               dlproc_state = DL_WAIT;
               vram_read_dl <= 0;
               vram_render_trigger <= 1;
               lms_changed <= report_lms_changed;
               blank_scanline <= 0;
               if (dl_inst == 2) begin
                  scanlines <= 7;
                  pitch <= 80;
                  double_pixel <= 0;
                  vram_render <= 1;
               end else if (dl_inst == 3) begin
                  scanlines <= 7;
                  pitch <= 40;
                  double_pixel <= 1;
                  vram_render <= 1;
               end else if (dl_inst == 0) begin
                  blank_scanline <= 1;
                  vram_render_trigger <= 0;
                  scanlines <= dl_value[6:4];
               end
            end
         endcase
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

   reg[2:0] vram_page = 0;
   
   reg        cpu_port_cs;
   reg        cpu_port_wr_en;
   reg[7:0]   cpu_port_wr_data;
   reg[16:0]  cpu_port_addr;
      
   wire[7:0]  vram_cpu_wr_data = cpu_port_cs ? cpu_port_wr_data : cpu_wr_data;
   wire       vram_cpu_wr_en   = cpu_port_wr_en || cpu_wr_en;
   wire[16:0] vram_cpu_addr    = cpu_port_cs ? cpu_port_addr : {vram_page, !cpu_addr[13], cpu_addr[12:0]};
   wire       vram_cs = cpu_addr[15:13] == 3'b101 || cpu_addr[15:13] == 3'b110 || cpu_port_cs;
   wire[7:0]  vram_chroni_rd_data;
   wire[7:0]  vram_cpu_rd_data;
   reg[16:0]  vram_char_addr;
   reg[16:0]  vram_dl_addr;
   
   reg vram_read_dl;
   
   wire[16:0] vram_chroni_addr = vram_read_dl ? vram_dl_addr : vram_char_addr;
   
   dpram_ab #(131072, 17, 8) vram (
         .clock(sys_clk),
         .address_en_a(vram_cs),
         .address_en_b(1'b1),
         .address_a(vram_cpu_addr),
         .address_b(vram_chroni_addr),
         .data_a(vram_cpu_wr_data),
         .data_b(0),
         .wren_a(vram_cpu_wr_en && vram_cs),
         .wren_b(0),
         .q_a(vram_cpu_rd_data),
         .q_b(vram_chroni_rd_data)
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
   
   reg[15:0]   border_color;
   
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
         .double_pixel(double_pixel)
      );

endmodule
