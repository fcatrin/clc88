`timescale 1ns / 1ps

module chroni (
      input vga_clk,
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

reg[10:0] h_sync_pulse;
reg[10:0] h_total;
reg[10:0] h_de_start;
reg[10:0] h_de_end;
reg[10:0] h_pf_start;
reg[10:0] h_pf_end;

reg[10:0] v_sync_pulse;
reg[10:0] v_total;
reg[10:0] v_de_start;
reg[10:0] v_de_end;
reg[10:0] v_pf_start;
reg[10:0] v_pf_end;

reg[10 : 0] x_cnt;
reg[9 : 0]  y_cnt;
reg[10 : 0] h_pf_cnt;
reg[9 : 0]  v_pf_cnt;
reg hsync_r;
reg vsync_r; 
reg h_de;
reg v_de;
reg h_pf;
reg v_pf;


reg[8:0] scanline;
reg dbl_scan;
reg[1:0] tri_scan;
reg[1:0] vga_mode;

always @ (posedge vga_clk) begin
   if(x_cnt <= 1 && y_cnt <= 1 && vga_mode_in != vga_mode) begin
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
      end else if (vga_mode_in == VGA_MODE_1280x720) begin
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
      end
      vga_mode <= vga_mode_in;
   end
end

// x position counter  
always @ (posedge vga_clk)
    if(~reset_n)    x_cnt <= 1;
    else if(x_cnt == h_total) x_cnt <= 1;
    else x_cnt <= x_cnt+ 1;

// y position counter  
always @ (posedge vga_clk) begin
   if(~reset_n) y_cnt <= 1;
   else if(y_cnt == v_total) begin
      y_cnt <= 1;
      scanline <= 0;
      dbl_scan <= 0;
      tri_scan <= 0;
   end else if(x_cnt == h_total) begin
      y_cnt <= y_cnt+1;
      if (vga_mode == VGA_MODE_1280x720) begin
         if (tri_scan == 2) begin
            tri_scan <= 0;
            scanline <= scanline + 1;
         end else
            tri_scan <= tri_scan + 1;
      end else if (y_cnt >= v_pf_start) begin
         if (~dbl_scan) scanline <= scanline + 1;
         dbl_scan = ~dbl_scan;
      end
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
end    

reg[10:0] text_rom_addr;
reg[10:0] font_rom_addr;
reg[7:0] font_reg;
reg[7:0] font_reg_next;
reg[2:0] font_scan;

wire text_rom_read;
assign text_rom_read = (x_cnt >= h_pf_start-8 && x_cnt < h_pf_end && v_pf) ? 1'b1 : 1'b0;

reg[2:0] font_bit;
reg[3:0] font_decode_state;
localparam FONT_DECODE_STATE_IDLE       = 0;
localparam FONT_DECODE_STATE_TEXT_READ  = 1;
localparam FONT_DECODE_STATE_TEXT_WAIT  = 2;
localparam FONT_DECODE_STATE_FONT_READ  = 3;
localparam FONT_DECODE_STATE_FONT_WAIT  = 4;
localparam FONT_DECODE_STATE_FONT_SHIFT = 5;

reg[7:0] pixels [639:0]; // two lines of 320 pixels
reg[9:0] pixel_index;
reg      pixel_row;

// state machine to read char or font from rom
always @(posedge vga_clk)
begin
   if (!reset_n) begin
      font_decode_state <= FONT_DECODE_STATE_IDLE;
      rd_req <= 0;
      pixel_row <= 0;
   end
   if (text_rom_read) begin
      if (x_cnt == 1) begin
         pixel_index       <= pixel_row ? 0 : 320;
         pixel_row         <= ~pixel_row;
         font_bit <= 7;
         text_rom_addr <= 1025;
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
               addr_out <= {data_in, font_scan};
               font_decode_state <= FONT_DECODE_STATE_FONT_READ;
            end 
         FONT_DECODE_STATE_FONT_READ:
            if (rd_ack) begin
               rd_req <= 0;
               font_reg_next <= data_in;
               font_decode_state <= FONT_DECODE_STATE_FONT_SHIFT;
            end
            FONT_DECODE_STATE_FONT_SHIFT:
            if (pixel_index == 320 || pixel_index == 640) begin
               font_decode_state <= FONT_DECODE_STATE_IDLE;
            end else if (font_bit == 0) begin
               font_decode_state <= FONT_DECODE_STATE_TEXT_READ;
               text_rom_addr <= text_rom_addr == 1092 ? 1025 : text_rom_addr + 1;
            end else begin
               pixels[pixel_index] <= font_reg_next[font_bit] ? 1 : 0;
               font_bit    <= font_bit - 1;
               pixel_index <= pixel_index + 1;
            end
         endcase
      end
   end      
end         


// current scanline relative to start of display
always @(posedge vga_clk)
begin
   if (~reset_n) begin
      font_scan <= 0;
   end
   if(v_pf && x_cnt == h_total) begin
      font_scan <= scanline[2:0];
   end
end

// read font to set bit to display on/off
wire font_bit_on;
assign font_bit_on = font_reg[font_bit];

reg[1:0] bg_color;
wire[4:0] bg_b = bg_color == 0 ? 5'b01011 : (bg_color == 1 ? 5'b10000 : 5'b00000);
wire[5:0] bg_g = bg_color == 0 ? 5'b010110 : (bg_color == 1 ? 6'b100000 : 6'b000000);

parameter border_r = 5'b00100;
parameter border_g = 6'b001000;
parameter border_b = 5'b00110;
   
assign vga_hs = hsync_r;
assign vga_vs = vsync_r;  
assign vga_r = (h_de & v_de) ? ((h_pf & v_pf) ? (font_bit_on ? 5'b10011  : 5'b00000)  : border_r) : 5'b00000;
assign vga_g = (h_de & v_de) ? ((h_pf & v_pf) ? (font_bit_on ? 6'b100111 : bg_g) : border_g) : 6'b000000;
assign vga_b = (h_de & v_de) ? ((h_pf & v_pf) ? (font_bit_on ? 5'b10011  : bg_b)  : border_b) : 5'b00000;

endmodule
    