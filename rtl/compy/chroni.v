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
      output reg [12:0] addr_out,
      input [7:0] data_in,
      output reg rd_req,
      input  rd_ack
      );

   `include "chroni.vh"
   `include "chroni_vga_modes.vh"

   reg[11:0] h_sync_pulse;
   reg[11:0] h_total;
   reg[11:0] h_de_start;
   reg[11:0] h_de_end;
   reg[11:0] h_pf_start;
   reg[11:0] h_pf_end;

   reg[11:0] v_sync_pulse;
   reg[11:0] v_total;
   reg[11:0] v_de_start;
   reg[11:0] v_de_end;
   reg[11:0] v_pf_start;
   reg[11:0] v_pf_end;

   reg[11 : 0] x_cnt;
   reg[11 : 0] y_cnt;
   reg[11 : 0] h_pf_cnt;
   reg[11 : 0] v_pf_cnt;
   reg hsync_r;
   reg vsync_r; 
   reg h_de;
   reg v_de;
   reg h_pf;
   reg v_pf;
   reg h_pf_pix;
   reg h_sync_p;
   reg v_sync_p;

   reg[1:0] vga_mode;
   reg vga_scale;

   wire vga_mode_change;
   assign vga_mode_change = vga_mode_in != vga_mode;

   always @ (posedge vga_clk) begin
      if (x_cnt == 1 && y_cnt == 1 && vga_mode_change) begin
         if (vga_mode_in == VGA_MODE_640x480) begin
            h_sync_pulse <= Mode1_H_SyncPulse;
            h_total      <= Mode1_H_Total;
            h_de_start   <= Mode1_H_DeStart;
            h_de_end     <= Mode1_H_DeEnd;
            h_pf_start   <= Mode1_H_PfStart;
            h_pf_end     <= Mode1_H_PfEnd;
            v_sync_pulse <= Mode1_V_SyncPulse;
            v_total      <= Mode1_V_Total;
            v_de_start   <= Mode1_V_DeStart;
            v_de_end     <= Mode1_V_DeEnd;
            v_pf_start   <= Mode1_V_PfStart;
            v_pf_end     <= Mode1_V_PfEnd;
            h_sync_p     <= Mode1_H_SyncP;
            v_sync_p     <= Mode1_V_SyncP;
            vga_scale    <= 0;
         end else if (vga_mode_in == VGA_MODE_800x600) begin
            h_sync_pulse <= Mode2_H_SyncPulse;
            h_total      <= Mode2_H_Total;
            h_de_start   <= Mode2_H_DeStart;
            h_de_end     <= Mode2_H_DeEnd;
            h_pf_start   <= Mode2_H_PfStart;
            h_pf_end     <= Mode2_H_PfEnd;
            v_sync_pulse <= Mode2_V_SyncPulse;
            v_total      <= Mode2_V_Total;
            v_de_start   <= Mode2_V_DeStart;
            v_de_end     <= Mode2_V_DeEnd;
            v_pf_start   <= Mode2_V_PfStart;
            v_pf_end     <= Mode2_V_PfEnd;
            h_sync_p     <= Mode2_H_SyncP;
            v_sync_p     <= Mode2_V_SyncP;
            vga_scale    <= 0;
         end else if (vga_mode_in == VGA_MODE_1920x1080) begin
            h_sync_pulse <= Mode3_H_SyncPulse;
            h_total      <= Mode3_H_Total;
            h_de_start   <= Mode3_H_DeStart;
            h_de_end     <= Mode3_H_DeEnd;
            h_pf_start   <= Mode3_H_PfStart;
            h_pf_end     <= Mode3_H_PfEnd;
            v_sync_pulse <= Mode3_V_SyncPulse;
            v_total      <= Mode3_V_Total;
            v_de_start   <= Mode3_V_DeStart;
            v_de_end     <= Mode3_V_DeEnd;
            v_pf_start   <= Mode3_V_PfStart;
            v_pf_end     <= Mode3_V_PfEnd;
            h_sync_p     <= Mode3_H_SyncP;
            v_sync_p     <= Mode3_V_SyncP;
            vga_scale    <= 1;
         end
         vga_mode <= vga_mode_in;
      end
   end

   // x position counter  
   always @ (posedge vga_clk) begin
      if(~reset_n || x_cnt == h_total || vga_mode_change) begin
         x_cnt <= 1;
      end else begin
         x_cnt <= x_cnt + 1'b1;
      end
   end

   // y position counter  
   always @ (posedge vga_clk) begin
      if(~reset_n || y_cnt == v_total || vga_mode_change) begin
         y_cnt <= 1;
      end else if(x_cnt == h_total) begin
         y_cnt <= y_cnt + 1'b1;
      end
   end


   // hsync / h display enable signals    
   always @ (posedge vga_clk)
   begin
      if(~reset_n) hsync_r <= 1'b1;
      else if(x_cnt == 1) hsync_r <= 1'b0;
      else if(x_cnt == h_sync_pulse) hsync_r <= 1'b1;
       
      if(~reset_n) h_de <= 1'b0;
      else if(x_cnt == h_de_start) h_de <= 1'b1;
      else if(x_cnt == h_de_end) h_de <= 1'b0;   
   
      if(~reset_n) h_pf <= 1'b0;
      else if(x_cnt == h_pf_start) h_pf <= 1'b1;
      else if(x_cnt == h_pf_end) h_pf <= 1'b0;
   
      if (~reset_n) h_pf_pix <= 1'b0;
      else if(x_cnt == h_pf_start-1) h_pf_pix <= 1'b1;
      else if(x_cnt == h_pf_end-1) h_pf_pix <= 1'b0;
   end

   // vsync / v display enable signals    
   always @ (posedge vga_clk)
   begin
      if(~reset_n) vsync_r <= 1'b1;
      else if(y_cnt == 1) vsync_r <= 1'b0;
      else if(y_cnt == v_sync_pulse) vsync_r <= 1'b1;

      if(~reset_n) v_de <= 1'b0;
      else if(y_cnt == v_de_start) v_de <= 1'b1;
      else if(y_cnt == v_de_end) v_de <= 1'b0;    
   
      if(~reset_n) v_pf <= 1'b0;
      else if(y_cnt == v_pf_start) v_pf <= 1'b1;
      else if(y_cnt == v_pf_end) v_pf <= 1'b0;
   
   end    

   localparam FD_IDLE       = 0;
   localparam FD_TEXT_READ  = 1;
   localparam FD_TEXT_WAIT  = 2;
   localparam FD_TEXT_DONE  = 3;
   localparam FD_FONT_READ  = 4;
   localparam FD_FONT_WAIT  = 5;
   localparam FD_FONT_WRITE = 6;
   localparam FD_FONT_DONE  = 7;
   reg[2:0]  font_decode_state;

   // state machine to read char or font from rom
   always @(posedge sys_clk) begin
      reg[10:0] text_rom_addr;
      reg       render_flag_prev;
      reg[2:0]  font_scan;
      reg[7:0]  text_buffer[79:0];
      reg[7:0]  text_buffer_index;
   
      if (!reset_n || vga_mode_change || y_cnt == 1) begin
         font_decode_state <= FD_IDLE;
         rd_req <= 0;
         wr_en <= 0;
         render_flag_prev <= 0;
         font_scan <= 0;
         text_rom_addr <= 1025;
         pixel_buffer_index_in <= 0;
         text_buffer_index <= 0;
         wr_bitmap_bits <= 0;
      end else begin
         render_flag_prev <= render_flag;
         if (~render_flag_prev && render_flag) begin
            text_buffer_index <= 0;
            pixel_buffer_index_in <=  render_buffer ? 11'd640 : 11'd0;
            rd_req <= 0;
            wr_en <= 0;
            font_decode_state <= font_scan == 0 ? FD_TEXT_READ : FD_FONT_READ; 
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
                  text_rom_addr <= text_rom_addr == 11'd1092 ? 11'd1025 : (text_rom_addr + 1'b1);

                  rd_req <= 1;
                  font_decode_state <= FD_TEXT_WAIT;
               end
               FD_TEXT_WAIT:
                  if (rd_ack) begin
                     rd_req <= 0;
                     font_decode_state <= FD_TEXT_DONE;
                  end
               FD_TEXT_DONE:
               begin
                  text_buffer[text_buffer_index] <= data_in;
                  if (text_buffer_index == 79) begin
                     text_buffer_index <= 0;
                     font_decode_state <= FD_FONT_READ;
                  end else begin
                     text_buffer_index <= text_buffer_index + 1'b1;
                     font_decode_state <= FD_TEXT_READ;
                  end
               end
               
               FD_FONT_READ:
               begin
                  addr_out <= {text_buffer[text_buffer_index], font_scan};
                  font_decode_state <= FD_FONT_WAIT;
                  rd_req <= 1;
               end
               FD_FONT_WAIT:
                  if (rd_ack) begin
                     rd_req <= 0;
                     font_decode_state <= FD_FONT_WRITE;
                  end
               FD_FONT_WRITE:
                  if (!wr_busy) begin
                     wr_en <= 1;
                     pixel_out <= data_in;
                     wr_bitmap_on   <= 8'b1;
                     wr_bitmap_off  <= 8'b0;
                     wr_bitmap_bits <= 4'd8;
                     font_decode_state <= FD_FONT_DONE;
                  end
               FD_FONT_DONE:
               begin
                  wr_en <= 0;
                  if (text_buffer_index == 79) begin
                     font_decode_state <= FD_IDLE;
                     font_scan <= font_scan + 1'b1;
                  end else begin
                     text_buffer_index     <= text_buffer_index + 1'b1;
                     pixel_buffer_index_in <= pixel_buffer_index_in + 4'd8;
                     font_decode_state     <= FD_FONT_READ;
                  end
               end
            endcase
         end
      end      
   end         

   // pixel x counter
   always @ (posedge vga_clk) begin
      reg[7:0] pixel_x_dbl;
      if (h_pf_pix && v_pf) begin
         if (vga_scale) begin
            if (pixel_x_dbl == 1) begin
               pixel_buffer_index_out <= pixel_buffer_index_out + 1'b1;
               pixel_x_dbl <= 0;
            end else 
               pixel_x_dbl <= pixel_x_dbl + 1'b1;
         end else begin
            pixel_buffer_index_out <= pixel_buffer_index_out + 1'b1;
         end
      end else begin
         pixel_buffer_index_out <= output_buffer ?  11'd640 : 11'd0;
         pixel_x_dbl <= 1;
      end
   end

   // output line 
   reg output_buffer;
   always @ (posedge vga_clk) begin : output_block
      reg [3:0] output_state;
      if (!reset_n || vga_mode_change) begin
         output_state <= 15;
      end else if (x_cnt == h_total) begin
         if (y_cnt == v_pf_end) begin
            output_state <= 15;
         end else if (y_cnt == v_pf_start - 1) begin
            output_state <= vga_scale ? 7 : 3;
         end else if (output_state != 15) begin
            if (vga_scale) begin
               output_state <= output_state == 7 ? 0 : (output_state + 1);
               if (output_state == 7) begin
                  output_buffer <= 0;
               end else if (output_state == 3) begin
                  output_buffer <= 1;
               end
            end else begin
               output_state <= output_state == 3 ? 0 : (output_state + 1);
               if (output_state == 3) begin
                  output_buffer <= 0;
               end else if (output_state == 1) begin
                  output_buffer <= 1;
               end
            end
         end
      end
   end

   // line render trigger
   reg render_buffer;
   reg render_flag;

   always @ (posedge vga_clk) begin : render_block
      reg[3:0] render_state;
      if (!reset_n || vga_mode_change) begin
         render_buffer <= 0;
         render_flag   <= 0;
         render_state  <= 15;
      end else begin
         if (x_cnt == h_total) begin
            if (y_cnt == 1 || y_cnt == v_pf_end - 2) begin
               render_state <= 15;
               render_flag  <= 0;
            end else if (y_cnt == v_pf_start - 3) begin
               render_state <= vga_scale ? 7 : 3;
            end else if (render_state != 15) begin
               if (vga_scale) begin
                  render_state  <= render_state == 7 ? 0 : (render_state + 1);
                  render_flag   <= render_state == 7 || render_state == 3;
                  render_buffer <= render_state == 7 ? 0 : 1;
               end else begin
                  render_state  <= render_state == 3 ? 0 : (render_state + 1);
                  render_flag   <= render_state[0];
                  render_buffer <= render_state == 3 ? 0 : 1;
               end
            end
         end
      end
   end

   parameter border_color = 16'h10A3;
   parameter text_background_color = 16'h29AC;
   parameter text_foreground_color = 16'hF75B;

   assign vga_hs = h_sync_p ? ~hsync_r : hsync_r;
   assign vga_vs = v_sync_p ? ~vsync_r : vsync_r;

   assign vga_r = (h_de & v_de) ? ((h_pf & v_pf) ? ((pixel || (font_decode_state == FD_FONT_DONE)) ? text_foreground_color[15:11] : text_background_color[15:11])  : border_color[15:11]) : 5'b00000;
   assign vga_g = (h_de & v_de) ? ((h_pf & v_pf) ? (pixel ? text_foreground_color[10:05] : text_background_color[10:05])  : border_color[10:05]) : 6'b000000;
   assign vga_b = (h_de & v_de) ? ((h_pf & v_pf) ? (pixel ? text_foreground_color[04:00] : text_background_color[04:00])  : border_color[04:00]) : 5'b00000;

   wire[7:0] pixel;
   reg[10:0] pixel_buffer_index_out;
   reg[10:0] pixel_buffer_index_in;
   reg wr_en = 0;
   reg[3:0] wr_bitmap_bits;
   reg[7:0] wr_bitmap_on;
   reg[7:0] wr_bitmap_off;
   reg[7:0] pixel_out;
   wire wr_busy;

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
      
endmodule
