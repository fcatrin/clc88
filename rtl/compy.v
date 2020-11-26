`timescale 1ns / 1ps

module compy (
	input clk,
	input reset_n,
	input key_mode,
	output vga_hs,
	output vga_vs,
	output [4:0] vga_r,
	output [5:0] vga_g,
	output [4:0] vga_b,
	
	output        S_CLK,  //sdram clock
	output        S_CKE,  //sdram clock enable
	output        S_NCS,  //sdram chip select
	output        S_NWE,  //sdram write enable
	output        S_NCAS, //sdram column address strobe
	output        S_NRAS, //sdram row address strobe
	output  [1:0] S_DQM,  //sdram data enable 
	output  [1:0] S_BA,   //sdram bank address
	output [12:0] S_A,    //sdram address
	inout  [15:0] S_DB    //sdram data	
);

`include "chroni.vh"
	
	// global bus
	wire[15:0] addr;
	wire[7:0]  data;
	
	wire[7:0]  chroni_page;
	wire[13:0] chroni_addr;
	
	wire[10:0] rom_addr = addr[10:0];
	wire[16:0] vga_addr = {chroni_page, 9'b000000000} + chroni_addr;
	wire[7:0]  rom_data;

	wire[7:0]  vram_dbr_o;
	
	assign vram_dbr_o = rom_data;
	assign addr = vga_addr[15:0];
	
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
		.addr_out(chroni_addr),
		.addr_out_page(chroni_page),
		.data_in(vram_dbr_o)
	);
	
	sdram_top		u_sdramtop (
		//global clock
		.clk				   (clk_ref),			//sdram reference clock
		.rst_n				(sys_rst_n),			//global reset

		//internal interface	
		.sdram_wr_req		(sdram_wr_req), 	//sdram write request
		.sdram_rd_req		(sdram_rd_req), 	//sdram write ack
		.sdram_wr_ack		(sdram_wr_ack), 	//sdram read request
		.sdram_rd_ack		(sdram_rd_ack),	//sdram read ack
		.sys_wraddr			(sdram_wraddr), 	//sdram write address 
		.sys_rdaddr			(sdram_rdaddr), 	//sdram read address
		.sys_data_in		(sdram_din),    	//fifo 2 sdram data input
		.sys_data_out		(sdram_dout),   	//sdram 2 fifo data input
		.sdram_init_done	(sdram_init_done),	//sdram init done

		//burst length
		.sdwr_byte			(wr_length),		//sdram write burst length
		.sdrd_byte			(rd_length),		//sdram read burst length

		//sdram interface
		//	.sdram_clk			(sdram_clk),		//sdram clock	
		.sdram_cke			(S_CKE),		//sdram clock enable	
		.sdram_cs_n			(S_NCS),		//sdram chip select	
		.sdram_we_n			(S_NWE),		//sdram write enable	
		.sdram_ras_n		(S_NRAS),		//sdram column address strobe	
		.sdram_cas_n		(S_NCAS),		//sdram row address strobe	
		.sdram_ba			(S_BA),			//sdram data enable (H:8)    
		.sdram_addr			(S_A),		//sdram data enable (L:8)	
		.sdram_data			(S_DB)		//sdram bank address	
		//	.sdram_udqm			(sdram_udqm),		//sdram address	
		//	.sdram_ldqm			(sdram_ldqm)		//sdram data	
	);
 
endmodule

