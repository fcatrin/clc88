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
      input [6:0] cpu_addr,
      input [7:0] cpu_data_in,
      output reg [7:0] cpu_data_out,
      input cpu_we,
      input cpu_re,
      output reg [12:0] addr_out,
      output reg [7:0]  addr_out_page,
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
reg h_sync_p;
reg v_sync_p;

reg[8:0] scanline;
reg dbl_scan;
reg[4:0] tri_scan;
reg[1:0] vga_mode;

reg render_line;
reg v_render;

always @ (posedge vga_clk) begin
   if (x_cnt == 1 && y_cnt == 1 && vga_mode_in != vga_mode) begin
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
      end
      vga_mode <= vga_mode_in;
   end
end

// x position counter  
always @ (posedge vga_clk) begin
   if(~reset_n || x_cnt == h_total) begin
      x_cnt <= 1;
   end else begin
      x_cnt <= x_cnt + 1;
   end
end

// y position counter  
always @ (posedge vga_clk) begin
   if(~reset_n || y_cnt == v_total) begin
      y_cnt <= 1;
   end else if(x_cnt == h_total) begin
      y_cnt <= y_cnt + 1;
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
   
   if(~reset_n) v_render <= 1'b0;
   else if(y_cnt == v_pf_start - 1) v_render <= 1'b1;
   else if(y_cnt == v_pf_end   - 1) v_render <= 1'b0;
   
end    

reg[10:0] text_rom_addr;
reg[10:0] font_rom_addr;
reg[7:0] font_reg;
reg[7:0] font_reg_next;
reg[2:0] font_scan;

wire text_rom_read;
assign text_rom_read = 1;

reg[3:0] font_decode_state;
localparam FONT_DECODE_STATE_IDLE       = 0;
localparam FONT_DECODE_STATE_TEXT_READ  = 1;
localparam FONT_DECODE_STATE_TEXT_WAIT  = 2;
localparam FONT_DECODE_STATE_TEXT_DONE  = 3;
localparam FONT_DECODE_STATE_FONT_READ  = 4;
localparam FONT_DECODE_STATE_FONT_WAIT  = 5;

// state machine to read char or font from rom
always @(posedge sys_clk)
begin
   reg render_line_prev;

   if (!reset_n) begin
      font_decode_state <= FONT_DECODE_STATE_IDLE;
      addr_out <= 0;
      rd_req <= 0;
      pixel_row <= 0;
      render_line_prev <= 0;
      pixel_index <= 0;
   end else begin
      render_line_prev <= render_line;
      if (~render_line_prev && render_line) begin
         pixel_index       <= 0;
         pixel_row         <= ~pixel_row;
         text_rom_addr     <= 1025;
         font_decode_state <= FONT_DECODE_STATE_TEXT_READ;
         
      end else begin
         case (font_decode_state)
         FONT_DECODE_STATE_IDLE: 
            begin
               rd_req <= 0;
            end
         FONT_DECODE_STATE_TEXT_READ:
            begin
               addr_out <= text_rom_addr;
               rd_req <= 1;
               font_decode_state <= FONT_DECODE_STATE_TEXT_WAIT;
            end
         FONT_DECODE_STATE_TEXT_WAIT:
            if (rd_ack) begin
               rd_req <= 0;
               font_decode_state <= FONT_DECODE_STATE_TEXT_DONE;
            end
         FONT_DECODE_STATE_TEXT_DONE:
            begin
               addr_out <= {data_in, font_scan};
               font_decode_state <= FONT_DECODE_STATE_FONT_WAIT;
               rd_req <= 1;
            end
         FONT_DECODE_STATE_FONT_WAIT:
            if (rd_ack) begin
               rd_req <= 0;
               font_decode_state <= FONT_DECODE_STATE_FONT_READ;
            end
         FONT_DECODE_STATE_FONT_READ:
            begin
               pixels[pixel_index+0] <= data_in[7] ? 1 : 0;
               pixels[pixel_index+1] <= data_in[6] ? 1 : 0;
               pixels[pixel_index+2] <= data_in[5] ? 1 : 0;
               pixels[pixel_index+3] <= data_in[4] ? 1 : 0;
               pixels[pixel_index+4] <= data_in[3] ? 1 : 0;
               pixels[pixel_index+5] <= font_scan[2] ? 1 : 0;
               pixels[pixel_index+6] <= font_scan[1] ? 1 : 0;
               pixels[pixel_index+7] <= font_scan[0] ? 1 : 0;
               
               text_rom_addr <= text_rom_addr == 1092 ? 1025 : text_rom_addr + 1;
               if ((pixel_index == 640 - 8) || 
                   (pixel_index == 1280 -8 )) begin
                  font_decode_state <= FONT_DECODE_STATE_IDLE;
               end else begin
                  pixel_index       <= pixel_index + 8;
                  font_decode_state <= FONT_DECODE_STATE_TEXT_READ;
               end
            end
         endcase
      end
   end      
end         


reg[7:0]  pixels [1279:0]; // two lines of 640 pixels
reg[10:0] pixel_index;
reg[10:0] pixel_index_out;
reg       pixel_row;

// pixel x counter
always @ (posedge vga_clk) begin
   reg      pixel_x_dbl;
   reg[7:0] pixel_x_tri;

   if (~reset_n || x_cnt == 1) begin
      pixel_index_out <= 0;
      pixel_x_dbl <= 0;
      pixel_x_tri <= 0;
   end else begin
      if (h_pf && v_pf) begin
         case(vga_mode)
            VGA_MODE_640x480, VGA_MODE_800x600:
            begin
               if (pixel_x_dbl) pixel_index_out <= pixel_index_out + 1;
               pixel_x_dbl <= ~pixel_x_dbl;
            end
            VGA_MODE_1920x1080:
               if (pixel_x_tri == 15) begin
                  pixel_index_out <= pixel_index_out + 1;
                  pixel_x_tri <= 0;
               end else 
                  pixel_x_tri <= pixel_x_tri + 1;
         endcase
      end
   end
end

// pixel y counter  
always @ (posedge vga_clk) begin
   if (~reset_n || y_cnt == v_total) begin
      scanline <= 0;
      dbl_scan <= 0;
      tri_scan <= 0;
      render_line <= 0;
      font_scan <= 0;
   end else if (x_cnt == h_total && v_render) begin
      case(vga_mode)
         VGA_MODE_640x480, VGA_MODE_800x600:
         begin
            render_line = ~dbl_scan;
            if (render_line) begin
               scanline <= scanline + 1;
               font_scan <= font_scan + 1;
            end
            dbl_scan <= ~dbl_scan;
         end
         VGA_MODE_1920x1080:
         begin
            render_line = tri_scan == 17; 
            if (render_line) begin
               tri_scan <= 0;
               scanline <= scanline + 1;
               font_scan <= font_scan + 1;
            end else
               tri_scan <= tri_scan + 1;
         end
      endcase
   end
end

parameter border_r = 5'b00100;
parameter border_g = 6'b001000;
parameter border_b = 5'b00110;

assign vga_hs = h_sync_p ? ~hsync_r : hsync_r;
assign vga_vs = v_sync_p ? ~vsync_r : vsync_r;

assign pixel = pixels[pixel_index_out];

// assign vga_r = (h_de & v_de) ? ((h_pf & v_pf) ? (pixels[pixel_index_out] ? 5'b10011  : 5'b00000)  : border_r) : 5'b00000;
/*
assign vga_r = (h_de & v_de) & (rd_req || pixels[pixel_index_out]) ? 5'b10011  : 5'b00000;
assign vga_g = (h_de & v_de) ? ((h_pf & v_pf) ? (pixels[pixel_index_out] ? 6'b100111 : 6'b000000) : border_g) : 6'b000000;
assign vga_b = (h_de & v_de) ? ((h_pf & v_pf) ? (pixels[pixel_index_out] ? 5'b10011  : 5'b00000)  : border_b) : 5'b00000;
*/

assign vga_r = (h_de & v_de) ? (rd_req ? 5'b10011  : ((h_pf & v_pf) ? 5'b00000 : border_r)) : 5'b00000;
assign vga_g = (h_de & v_de) ? (rd_ack ? 6'b100111 : ((h_pf & v_pf) ? 6'b000000 : border_b)) : 6'b000000;
assign vga_b = (h_de & v_de) ? ((h_pf & v_pf) ? (pixel ? 5'b10011  : 5'b00000)  : border_b) : 5'b00000;


endmodule
    