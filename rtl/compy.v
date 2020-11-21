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

	wire[10:0] rom_addr;
	wire[7:0]  rom_data;

	wire CLK_OUT1;
	wire CLK_OUT2;
	wire CLK_OUT3;
	wire CLK_OUT4;
	
	wire chroni_clock;
	assign chroni_clock = CLK_OUT2;

	rom rom_inst (
		.clock(chroni_clock),
		.address(rom_addr),
		.q(rom_data)
	);

	pll pll_inst (// Clock in ports
		.inclk0(clk),      // IN
		.c0(CLK_OUT1),     // 21.175Mhz for 640x480(60hz)
		.c1(CLK_OUT2),     // 40.0Mhz for 800x600(60hz)
		.c2(CLK_OUT3),     // 65.0Mhz for 1024x768(60hz)
		.c3(CLK_OUT4),     // 108.0Mhz for 1280x1024(60hz)
		.areset(1'b0),     // reset input 
		.locked(LOCKED)
	);        // OUT

	chroni chroni_inst (
		.vga_clk(chroni_clock),
		.reset_n(reset_n),
		.vga_hs(vga_hs),
		.vga_vs(vga_vs),
		.vga_r(vga_r),
		.vga_g(vga_g),
		.vga_b(vga_b),
		.addr_out(rom_addr),
		.data_in(rom_data)
	);
 
endmodule

