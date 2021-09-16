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
      input [7:0]  cpu_wr_data,
      input [15:0] cpu_addr,
      input cpu_wr_en
      );

   `include "chroni.vh"
   
   localparam PAL_WRITE_IDLE = 0;
   localparam PAL_WRITE_LO   = 1;
   localparam PAL_WRITE_HI   = 2;
   localparam PAL_WRITE      = 3;
   
   wire register_cs = cpu_addr[15:4] == 12'b100100000000;
   
   always @(posedge sys_clk) begin : register_write
      reg[1:0]  palette_write_state = PAL_WRITE_IDLE;
      reg[7:0]  palette_write_index;
      reg[15:0] palette_write_value;
      reg[16:0] vram_write_address;
      
      palette_wr_en <= 0;
      cpu_port_cs <= 0;
      cpu_port_wr_en <= 0;
      if (register_cs && cpu_wr_en) begin
         case (cpu_addr[3:0])
            4'h0:
               display_list_addr[8:1]  <= cpu_wr_data;
            4'h1:
               display_list_addr[16:9] <= cpu_wr_data;
            4'h4:
            begin
               palette_write_index <= cpu_wr_data;
               palette_write_state <= PAL_WRITE_LO;
            end
            4'h5:
               if (palette_write_state == PAL_WRITE_LO) begin
                  palette_write_value[7:0]  <= cpu_wr_data;
                  palette_write_state   <= PAL_WRITE_HI;
               end else begin
                  palette_write_value[15:8] <= cpu_wr_data;
                  palette_write_state   <= PAL_WRITE;
               end
            4'h6:
               vram_write_address[7:0]  <= cpu_wr_data;
            4'h7:
               vram_write_address[15:8] <= cpu_wr_data;
            4'h8:
               vram_write_address[16] <= cpu_wr_data[0];
            4'h9:
            begin
               cpu_port_cs      <= 1;
               cpu_port_wr_en   <= 1;
               cpu_port_wr_data <= cpu_wr_data;
               cpu_port_addr    <= vram_write_address;
               vram_write_address <= vram_write_address + 1'b1;
            end
            4'hc:
               border_color[7:0]  <= cpu_wr_data;
            4'hd:
               border_color[15:8] <= cpu_wr_data;
         endcase
      end else if (palette_write_state == PAL_WRITE) begin
         palette_wr_en   <= 1;
         palette_wr_addr <= palette_write_index;
         palette_wr_data <= palette_write_value;
         
         palette_write_state <= PAL_WRITE_LO;
         palette_write_index <= palette_write_index + 1'b1; // autoincrement palette index
      end
   end

   localparam FD_IDLE       = 0;
   localparam FD_TEXT_START = 1;
   localparam FD_TEXT_READ  = 2;
   localparam FD_FONT_READ  = 6; 
   localparam FD_FONT_FETCH = 9;
   localparam FD_FONT_WAIT  = 10;
   localparam FD_FONT_WRITE = 13;
   localparam FD_FONT_DONE  = 14;
   reg[3:0]  font_decode_state;

   // state machine to read char or font from rom
   always @(posedge sys_clk) begin : char_gen
      reg[16:0] data_memory_addr;
      reg[16:0] load_memory_addr;
      reg[6:0]  scan_size;
      reg[6:0]  last_char;
      reg       vram_render_prev;
      reg[2:0]  font_scan;
      reg[6:0]  text_buffer_index;
      reg[1:0]  mem_wait;
   
      text_buffer_we <= 0;
      wr_en <= 0;
      if (!reset_n || vga_mode_changed || vga_frame_start) begin
         font_decode_state <= FD_IDLE;
         vram_render_prev <= 0;
         font_scan <= 0;
         load_memory_addr <= dl_lms;
         scan_size <= 80;
         last_char <= 79;
         pixel_buffer_index_in <= 0;
         text_buffer_index <= 0;
         wr_bitmap_bits <= 0;
      end else begin
         vram_render_prev <= vram_render;
         if (~vram_render_prev && vram_render) begin
            text_buffer_index <= 0;
            pixel_buffer_index_in <= render_buffer ? 11'd640 : 11'd0;
            font_decode_state <= font_scan == 0 ? FD_TEXT_START : FD_FONT_READ;
            if (lms_changed) load_memory_addr <= dl_lms; 
         end else begin
            case (font_decode_state)
               FD_TEXT_START:
               begin
                  vram_char_addr   <= load_memory_addr;
                  data_memory_addr <= load_memory_addr + 1'b1;
                  mem_wait <= 2;
                  font_decode_state <= FD_TEXT_READ;
               end
               FD_TEXT_READ: // transfer line of text from vram to text_buffer
               begin
                  vram_char_addr <= data_memory_addr;
                  data_memory_addr <= data_memory_addr + 1'b1;
                  if (mem_wait == 0) begin
                     text_buffer_addr    <= text_buffer_index;
                     text_buffer_data_wr <= vram_chroni_rd_data;
                     text_buffer_we <= 1;
                     if (text_buffer_index == last_char) begin
                        text_buffer_index <= 0;
                        mem_wait <= 2;
                        font_decode_state <= FD_FONT_READ;
                     end else begin
                        text_buffer_index <= text_buffer_index + 1'b1;
                     end
                  end else begin
                     mem_wait <= mem_wait - 1;
                  end
               end
               FD_FONT_READ: // read font data from each char on text_buffer
               begin
                  if (mem_wait == 2) begin
                     text_buffer_addr  <= text_buffer_index;
                     text_buffer_index <= text_buffer_index + 1;
                  end else if (mem_wait == 0) begin
                     font_decode_state <= FD_FONT_FETCH;
                  end
                  mem_wait <= mem_wait - 1;
               end
               FD_FONT_FETCH:
               begin
                  // read next char in advance
                  text_buffer_addr  <= text_buffer_index;
                  text_buffer_index <= text_buffer_index + 1;

                  // fetch font data
                  vram_char_addr <= {text_buffer_data_rd, font_scan};
                  font_decode_state <= FD_FONT_WAIT;
                  mem_wait <= 2;
               end
               FD_FONT_WAIT:
               begin
                  if (mem_wait == 0) begin
                     pixel_out_next <= vram_chroni_rd_data;
                     font_decode_state <= FD_FONT_WRITE;
                  end
                  mem_wait <= mem_wait - 1;
               end
               FD_FONT_WRITE:
               if (!wr_busy) begin
                  pixel_out <= pixel_out_next;
                  wr_en <= 1;
                  wr_bitmap_on   <= 8'b1;
                  wr_bitmap_off  <= 8'b0;
                  wr_bitmap_bits <= 4'd8;
                  font_decode_state <= FD_FONT_DONE;
               end
               FD_FONT_DONE:
               if (text_buffer_index == last_char+2) begin
                  font_decode_state <= FD_IDLE;
                  font_scan <= font_scan + 1'b1;
                  if (font_scan == 7) begin
                     load_memory_addr <= load_memory_addr + scan_size;
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
   reg[3:0]  dl_inst;
   reg vram_render;
   reg lms_changed;
   
   always @ (posedge sys_clk) begin : dlproc
      reg report_lms_changed;
      reg[16:0] display_list_ptr;
      reg      render_flag_prev;
      reg[1:0] mem_wait;
      reg[1:0] addr_part;
      reg[3:0] scanlines;
      
      render_flag_prev <= render_flag;
      vram_render <= 0;
      lms_changed <= 0;
      if (!reset_n || vga_mode_changed || vga_frame_start) begin
         display_list_ptr <= display_list_addr;
         render_flag_prev <= 0;
         vram_read_dl <= 0;
         dlproc_state <= DL_IDLE;
         dl_inst <= 0;
         scanlines <= 0;
      end else if (~render_flag_prev & render_flag) begin
         report_lms_changed <= 0;
         if (scanlines == 0) begin
            dlproc_state <= dl_inst == 1 ? DL_IDLE : DL_READ;
         end else begin
            scanlines <= scanlines - 1;
            vram_render <= 1;
         end
      end else begin
            case(dlproc_state)
            DL_READ:
            begin
               vram_read_dl <= 1;
               vram_dl_addr     <= display_list_ptr;
               display_list_ptr <= display_list_ptr + 1;
               
               mem_wait <= 2;
               dlproc_state <= DL_READ_WAIT;
            end
            DL_READ_WAIT:
            begin
               vram_read_dl <= 0;
               mem_wait <= mem_wait - 1;
               if (mem_wait == 0) begin
                  dl_inst <= vram_chroni_rd_data[3:0];
                  dlproc_state <= vram_chroni_rd_data[6] ? (vram_chroni_rd_data[3:0] == 1 ? DL_IDLE : DL_LMS) : DL_EXEC;
               end
            end
            DL_LMS:
            begin
               vram_read_dl <= 1;
               vram_dl_addr     <= display_list_ptr;
               display_list_ptr <= display_list_ptr + 1;
               mem_wait <= 2;
               addr_part <= 2;
               dlproc_state <= DL_LMS_READ;
            end
            DL_LMS_READ:
            begin
               vram_read_dl <= 1;
               mem_wait <= mem_wait - 1;
               if (mem_wait == 0) begin
                  
                  dl_lms <= addr_part == 0 ? 
                     {vram_chroni_rd_data[0], dl_lms[15:0]} : 
                     {vram_chroni_rd_data, dl_lms[15:8]};
                  
                  vram_dl_addr     <= display_list_ptr;
                  display_list_ptr <= display_list_ptr + 1;
                  mem_wait <= 2;
                  if (addr_part == 0) begin
                     report_lms_changed <= 1;
                     dlproc_state <= DL_EXEC;
                  end
                  addr_part <= addr_part -1 ;
               end
            end
            DL_EXEC:
            begin
               dlproc_state = DL_WAIT;
               scanlines <= 8;
               vram_render <= 1;
               vram_read_dl <= 0;
               lms_changed <= report_lms_changed;
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
         .border_color(border_color)
      );

endmodule
