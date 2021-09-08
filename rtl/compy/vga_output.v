`timescale 1ns / 1ps

module vga_output (
      input sys_clk,
      input vga_clk,
      input reset_n,
      input [1:0] sys_vga_mode,
      output vga_hs,
      output vga_vs,
      output [4:0] vga_r,
      output [5:0] vga_g,
      output [4:0] vga_b,
      output mode_changed,
      output frame_start,
      output render_start,
      output scanline_start,
      output reg[10:0] pixel_buffer_index_out,
      output pixel_scale,
      input read_text,
      input read_font,
      input  [15:0] pixel
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
   
   reg[11 : 0] y_cnt;
   reg[11 : 0] x_cnt;
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
   reg vga_frame_start;
   reg vga_scanline_end;
   
   wire vga_mode_change = vga_mode_in != vga_mode;
   
   always @ (posedge vga_clk) begin
      if (vga_frame_start && vga_mode_change && !mode_changed_busy) begin
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
         mode_changed_req <= 1;
      end else begin
         mode_changed_req <= 0;
      end
      pixel_scale_pipe <= vga_scale;
   end
   
   always @ (posedge vga_clk) begin
      vga_frame_start <= y_cnt == 1 && x_cnt == 1;
      vga_scanline_end <= x_cnt == (h_total - 1); // it'll be read on the next cycle
      
      // send signal to sys_clk
      if (!frame_start_busy && vga_frame_start) begin
         frame_start_req <= 1;
      end else if (frame_start_ack) begin
         frame_start_req <= 0;
      end

   end
   
   // x position counter  
   always @ (posedge vga_clk) begin
      if(~reset_n || vga_scanline_end || vga_mode_change) begin
         x_cnt <= 1;
      end else begin
         x_cnt <= x_cnt + 1'b1;
      end
   end
   
   // y position counter  
   always @ (posedge vga_clk) begin
      if(~reset_n || vga_mode_change) begin
         y_cnt <= 1;
      end else if (vga_scanline_end) begin
         if (y_cnt == v_total) begin
            y_cnt <= 1;
         end else begin
            y_cnt <= y_cnt + 1'b1;
         end
      end
   end
   
   // hsync / h display enable signals    
   always @ (posedge vga_clk) begin
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
      else if(x_cnt == h_pf_start-4) h_pf_pix <= 1'b1;
      else if(x_cnt == h_pf_end-4) h_pf_pix <= 1'b0;
      
      if (vga_scanline_end) begin
         if (!render_start_busy && y_cnt == v_pf_start - 2) begin
            render_start_req <= 1;
         end
         if (!scanline_start_busy) begin
            scanline_start_req <= 1;
         end
      end else begin
         if (render_start_ack) begin
            render_start_req <= 0;
         end
         if (scanline_start_ack) begin
            scanline_start_req <= 0;
         end
      end
         
   end
   
   // vsync / v display enable signals    
   always @ (posedge vga_clk)  begin
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
         pixel_x_dbl <= 0;
      end
   end

   // output line 
   reg output_buffer;
   always @ (posedge vga_clk) begin : output_block
      reg [3:0] output_state;
      if (!reset_n || vga_mode_change) begin
         output_state <= 15;
      end else if (vga_scanline_end) begin
         if (y_cnt == v_pf_end) begin
            output_state <= 15;
         end else if (y_cnt == v_pf_start - 1) begin
            output_state  <= 0;
            output_buffer <= 0;
         end else if (output_state != 15) begin
            if (vga_scale) begin
               output_state <= output_state == 4'd7 ? 4'd0 : (output_state + 1'b1);
               if (output_state == 7) begin
                  output_buffer <= 0;
               end else if (output_state == 3) begin
                  output_buffer <= 1;
               end
            end else begin
               output_state <= output_state == 4'd3 ? 4'd0 : (output_state + 1'b1);
               if (output_state == 3) begin
                  output_buffer <= 0;
               end else if (output_state == 1) begin
                  output_buffer <= 1;
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

   assign vga_r = (h_de & v_de) ? (read_text ? 5'b11111  : ((h_pf & v_pf) ? pixel[15:11] : border_color[15:11])) : 5'b00000;
   assign vga_g = (h_de & v_de) ? (read_font ? 6'b111111 : ((h_pf & v_pf) ? pixel[10:05] : border_color[10:05])) : 6'b000000;
   assign vga_b = (h_de & v_de) ? (                         (h_pf & v_pf) ? pixel[04:0]  : border_color[04:00])  : 5'b00000;
   
   
   wire mode_changed_busy;
   reg  mode_changed_req;
   wire mode_changed_ack;

   crossclock_handshake mode_changed_crossclock (
         .src_clk(vga_clk),
         .dst_clk(sys_clk),
         .src_req(mode_changed_req),
         .signal(mode_changed),
         .busy(mode_changed_busy),
         .ack(mode_changed_ack)
      );

   wire frame_start_busy;
   reg  frame_start_req;
   wire frame_start_ack;

   crossclock_handshake frame_start_crossclock (
         .src_clk(vga_clk),
         .dst_clk(sys_clk),
         .src_req(frame_start_req),
         .signal(frame_start),
         .busy(frame_start_busy),
         .ack(frame_start_ack)
      );

   wire render_start_busy;
   reg  render_start_req;
   wire render_start_ack;

   crossclock_handshake render_start_crossclock (
         .src_clk(vga_clk),
         .dst_clk(sys_clk),
         .src_req(render_start_req),
         .signal(render_start),
         .busy(render_start_busy),
         .ack(render_start_ack)
      );

   wire scanline_start_busy;
   reg  scanline_start_req;
   wire scanline_start_ack;

   crossclock_handshake scanline_start_crossclock (
         .src_clk(vga_clk),
         .dst_clk(sys_clk),
         .src_req(scanline_start_req),
         .signal(scanline_start),
         .busy(scanline_start_busy),
         .ack(scanline_start_ack)
      );

   reg  pixel_scale_pipe;
   crossclock_signal pixel_scale_crossclock (
         .dst_clk(sys_clk),
         .src_req(pixel_scale_pipe),
         .signal(pixel_scale)
      );

   wire[1:0] vga_mode_in;
   crossclock_signal #(2) vga_mode_crossclock (
         .dst_clk(vga_clk),
         .src_req(sys_vga_mode),
         .signal(vga_mode_in)
      );

   
endmodule
