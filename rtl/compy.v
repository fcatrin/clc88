`timescale 1ns / 1ps

module compy (
	input clk,
	input reset_n,
	input key_mode,
	output vga_hs,
	output vga_vs,
	output [4:0] vga_r,
	output [5:0] vga_g,
	output [4:0] vga_b
);

`include "chroni.vh"
	
	// global bus
	wire[15:0] addr;
	wire[7:0]  data;
	
	wire[10:0] rom_addr;
	wire[7:0]  rom_data;
	
	wire[1:0] vga_mode;
	assign vga_mode = VGA_MODE_1280x720;

	wire CLK_OUT1;
	wire CLK_OUT2;
	wire CLK_OUT3;
	wire CLK_OUT4;

   wire system_clock;
	
	assign system_clock = 
		 vga_mode == VGA_MODE_640x480 ? CLK_OUT1 : 
		(vga_mode == VGA_MODE_800x600 ? CLK_OUT2 : CLK_OUT3);
		
		
	wire rom_s, ram_s, vram_s, chroni_s, storage_s, keyb_s, pokey_s;
	
	assign rom_s     = addr[15:13] ==  3'b111;                           // 0xE000 - 0xFFFF
	assign ram_s     = addr[15:15] ==  1'b0   || addr[15:12] == 4'b1000; // 0x0000 - 0x8FFF
	assign vram_s    = addr[15:13] ==  3'b101 || addr[15:13] == 3'b110;  // 0xA000 - 0xDFFF
	assign chroni_s  = addr[15:7]  ==  9'b100100000;                     // 0x9000 - 0x907F
	assign storage_s = addr[15:4]  == 12'b100100001000;                  // 0x9080 - 0x908F
	assign keyb_s    = addr[15:4]  == 12'b100100001001;                  // 0x9090 - 0x909F
	assign pokey_s   = addr[15:5]  == 11'b10010001000;                   // 0x9100 - 0x911F
	
	reg rom_cs, ram_cs, vram_cs, chroni_cs, storage_cs, keyb_cs, pokey_cs;
	
	always @ (posedge system_clock) begin
		if (~reset_n) begin
			rom_cs     <= 0;
			ram_cs     <= 0;
			vram_cs    <= 0;
			chroni_cs  <= 0;
			storage_cs <= 0;
			keyb_cs    <= 0;
			pokey_cs   <= 0;
		end else	begin
			rom_cs     <= rom_s;
			ram_cs     <= ram_s;
			vram_cs    <= vram_s;
			chroni_cs  <= chroni_s;
			storage_cs <= storage_s;
			keyb_cs    <= keyb_s;
			pokey_cs   <= pokey_s;
		end
	end	
	
	rom rom_inst (
		.clock(CLK_200),
		.address(rom_addr),
		.q(rom_data)
	);

	pll pll_inst (// Clock in ports
		.inclk0(clk),      // IN
		.c0(CLK_OUT1),     // 25.17Mhz  (640x480)
		.c1(CLK_OUT2),     // 40Mhz     (800x600)
		.c2(CLK_OUT3),     // 74.48Mhz  (1280x720)
		.c3(CLK_200),      // 200Mhz (ROM)
		.areset(1'b0),     // reset input 
		.locked(LOCKED)
	);        // OUT

	chroni chroni_inst (
		.vga_clk(system_clock),
		.reset_n(reset_n),
		.vga_mode_in(vga_mode),
		.vga_hs(vga_hs),
		.vga_vs(vga_vs),
		.vga_r(vga_r),
		.vga_g(vga_g),
		.vga_b(vga_b),
		.addr_out(rom_addr),
		.data_in(rom_data)
	);
 
endmodule

