`timescale 1ns / 1ps

module compy (
	input clk,
	input reset_n,
	output vga_hs,
	output vga_vs,
	output [4:0] vga_r,
	output [5:0] vga_g,
	output [4:0] vga_b
);

`include "chroni.vh"

	wire[10:0] rom_addr;
	wire[7:0]  rom_data;
	
	wire[2:0] vga_mode;
	assign vga_mode = VGA_MODE_1280x720;

	wire CLK_OUT1;
	wire CLK_OUT2;
	wire CLK_OUT3;
	wire CLK_OUT4;
	
   wire system_clock;
	reg  chroni_clock;
	
	assign system_clock = 
		 vga_mode == VGA_MODE_640x480 ? CLK_OUT1 : 
		(vga_mode == VGA_MODE_800x600 ? CLK_OUT2 : CLK_OUT3);

	always @(posedge system_clock)
	begin
	  chroni_clock <= !chroni_clock;
	end

	
	rom rom_inst (
		.clock(system_clock),
		.address(rom_addr),
		.q(rom_data)
	);

	pll pll_inst (// Clock in ports
		.inclk0(clk),      // IN
		.c0(CLK_OUT1),     // 25.17Mhz *2  (640x480)
		.c1(CLK_OUT2),     // 40Mhz    *2  (800x600)
		.c2(CLK_OUT3),     // 74.48Mhz *2  (1280x720)
		.areset(1'b0),     // reset input 
		.locked(LOCKED)
	);        // OUT

	chroni chroni_inst (
		.vga_clk(chroni_clock),
		.reset_n(reset_n),
		.vga_mode(vga_mode),
		.vga_hs(vga_hs),
		.vga_vs(vga_vs),
		.vga_r(vga_r),
		.vga_g(vga_g),
		.vga_b(vga_b),
		.addr_out(rom_addr),
		.data_in(rom_data)
	);
 
endmodule

