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
	
	reg chroni_clock;

	always @(posedge CLK_OUT3)
	begin
	  chroni_clock <= !chroni_clock;
	end

	
	rom rom_inst (
		.clock(CLK_OUT3),
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
		.vga_hs(vga_hs),
		.vga_vs(vga_vs),
		.vga_r(vga_r),
		.vga_g(vga_g),
		.vga_b(vga_b),
		.addr_out(rom_addr),
		.data_in(rom_data)
	);
 
endmodule

