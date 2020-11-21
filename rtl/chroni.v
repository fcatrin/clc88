`timescale 1ns / 1ps

module chroni (
		input clock,
		input reset_n,
		output vga_hs,
		output vga_vs,
		output [4:0] vga_r,
		output [5:0] vga_g,
		output [4:0] vga_b,
		output reg [10:0] addr_out,
		input [7:0] data_in
);

// 800*600 VGA

// Horizontal mode def
parameter LinePeriod =1056;
parameter H_SyncPulse=128;
parameter H_BackPorch=88;
parameter H_ActivePix=800;
parameter H_FrontPorch=40;
parameter Hde_start=216;
parameter Hde_end=1016;

// Hde_start = H_SyncPulse+H_BackPorch
// Hde_end   = H_SyncPulse+H_BackPorch + H_ActivePix
// LinePeriod = Hde_end + H_FrontPorch

// Vertical mode def
parameter FramePeriod =628;
parameter V_SyncPulse=4;
parameter V_BackPorch=23;
parameter V_ActivePix=600;
parameter V_FrontPorch=1;
parameter Vde_start=27;
parameter Vde_end=627;

reg[10 : 0] x_cnt;
reg[9 : 0]  y_cnt;
reg hsync_r;
reg vsync_r; 
reg h_de;
reg v_de;

wire vga_clk;

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
parameter state_write_font_a = 5;
parameter state_read_text_b = 8;
parameter state_read_font_b = 10;
parameter state_write_font_b = 13;
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
			addr_out <= {1'b1, font_scan};
		else if (read_rom_state == state_write_font_a || read_rom_state == state_write_font_b)
			font_reg <= data_in;
		
		if (read_rom_state == state_read_text_end)
			read_rom_state <= 0;
		else 
			read_rom_state <= read_rom_state + 1;
	end
end

// bit and char address to read
reg[4:0] font_bit;
always @(posedge vga_clk)
begin
	if (~reset_n) begin
		font_bit <= 3;
		text_rom_addr <= 16;
	end
	else begin
		if (hsync_r == 1'b0) begin
			text_rom_addr <= 16;
			font_bit <= 3;
		end
		if (text_rom_read) begin
			if (font_bit == 0) begin
				if (text_rom_addr == 31)
					text_rom_addr <= 16;
				else
					text_rom_addr <= text_rom_addr + 1;
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
		if (font_scan == 7)
			font_scan <= 0;
		else
			font_scan <= font_scan + 1'b1;
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
assign vga_clk = clock;
 
endmodule
	 