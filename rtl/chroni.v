`timescale 1ns / 1ps

module chroni (
		input vga_clk,
		input reset_n,
		output vga_hs,
		output vga_vs,
		output [4:0] vga_r,
		output [5:0] vga_g,
		output [4:0] vga_b,
		output reg [10:0] addr_out,
		input [7:0] data_in
);

// Horizontal mode def
parameter H_ActivePix=640;
parameter H_FrontPorch=16;
parameter H_SyncPulse=96;
parameter H_BackPorch=48;
parameter LinePeriod =800;
parameter Hde_start=144;
parameter Hde_end=744;

// Hde_start = H_SyncPulse+H_BackPorch
// Hde_end   = H_SyncPulse+H_BackPorch + H_ActivePix
// LinePeriod = Hde_end + H_FrontPorch

// Vertical mode def
parameter V_ActivePix=480;
parameter V_FrontPorch=11;
parameter V_SyncPulse=2;
parameter V_BackPorch=31;
parameter FramePeriod =524;
parameter Vde_start=33;
parameter Vde_end=513;

reg[10 : 0] x_cnt;
reg[9 : 0]  y_cnt;
reg hsync_r;
reg vsync_r; 
reg h_de;
reg v_de;

// x position counter  
always @ (posedge vga_clk)
	 if(~reset_n)    x_cnt <= 1;
	 else if(x_cnt == LinePeriod) x_cnt <= 1;
	 else x_cnt <= x_cnt+ 1;

// y position counter  
always @ (posedge vga_clk)
	if(~reset_n) y_cnt <= 1;
	else if(y_cnt == FramePeriod) y_cnt <= 1;
	else if(x_cnt == LinePeriod) y_cnt <= y_cnt+1;

// hsync / h display enable signals	 
always @ (posedge vga_clk)
begin
	if(~reset_n) hsync_r <= 1'b1;
	else if(x_cnt == 1) hsync_r <= 1'b0;
	else if(x_cnt == H_SyncPulse) hsync_r <= 1'b1;
		 
	if(~reset_n) h_de <= 1'b0;
	else if(x_cnt == Hde_start) h_de <= 1'b1;
	else if(x_cnt == Hde_end) h_de <= 1'b0;	
end

// vsync / v display enable signals	 
always @ (posedge vga_clk)
begin
	if(~reset_n) vsync_r <= 1'b1;
	else if(y_cnt == 1) vsync_r <= 1'b0;
	else if(y_cnt == V_SyncPulse) vsync_r <= 1'b1;

	if(~reset_n) v_de <= 1'b0;
	else if(y_cnt == Vde_start) v_de <= 1'b1;
	else if(y_cnt == Vde_end) v_de <= 1'b0;	 
end	 

//----------------------------------------------------------------
////////// ROM读字地址产生模块
//----------------------------------------------------------------

parameter state_read_text_a = 0;
parameter state_read_font_a = 2;
parameter state_write_font_a = 4;
parameter state_read_text_b = 8;
parameter state_read_font_b = 10;
parameter state_write_font_b = 12;

parameter state_read_text_end = 15;

reg[10:0] text_rom_addr;
reg[10:0] font_rom_addr;
reg[7:0]  font_reg;

reg[3:0] read_rom_state;
reg[2:0] font_scan;

wire text_rom_read;
assign text_rom_read = (x_cnt >= Hde_start-4 && x_cnt < Hde_end && v_de) ? 1'b1 : 1'b0;

// state machine to read char or font from rom
always @(posedge vga_clk)
begin
	if (~reset_n) begin
		read_rom_state <= state_read_text_a;
	end
	if (hsync_r == 1'b0) begin
		read_rom_state <= state_read_text_a;
	end
	if(text_rom_read) begin
		if (read_rom_state == state_read_text_a || read_rom_state == state_read_text_b)
			addr_out <= text_rom_addr;
		else if (read_rom_state == state_read_font_a || read_rom_state == state_read_font_b)
			addr_out <= {data_in, font_scan};
		else if (read_rom_state == state_write_font_a || read_rom_state == state_write_font_b)
			font_reg <= data_in;
		
		read_rom_state <= read_rom_state == state_read_text_end ? 0 : read_rom_state + 1;
	end
end

// bit and char address to read
reg[4:0] font_bit;
always @(posedge vga_clk)
begin
	if (~reset_n) begin
		font_bit <= 3;
		text_rom_addr <= 1024;
	end
	else begin
		if (hsync_r == 1'b0) begin
			text_rom_addr <= 1024;
			font_bit <= 3;
		end
		if (text_rom_read) begin
			if (font_bit == 0) begin
				text_rom_addr <= text_rom_addr == 1092 ? 1024 : text_rom_addr + 1;
				font_bit <= 7;
			end
			else begin
				font_bit <= font_bit - 1;
			end
		end
	end
end 

// current scanline relative to start of display
always @(posedge vga_clk)
begin
	if (~reset_n) begin
		font_scan <= 0;
	end
	if(v_de && x_cnt == LinePeriod) begin
		font_scan <= font_scan == 7 ? 0 : font_scan + 1;
	end
end

// read font to set bit to display on/off
wire font_bit_on;
assign font_bit_on = font_reg[font_bit];
	
assign vga_hs = hsync_r;
assign vga_vs = vsync_r;  
assign vga_r = (h_de & v_de) ? (font_bit_on ? 5'b10011  : 5'b00000)  : 5'b00000;
assign vga_g = (h_de & v_de) ? (font_bit_on ? 6'b100111 : 6'b000111) : 6'b000000;
assign vga_b = (h_de & v_de) ? (font_bit_on ? 5'b10011  : 5'b01011)  : 5'b00000;

endmodule
	 