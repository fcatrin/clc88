`timescale 1ns / 1ps

module system (
   input clk,
   input reset_n,
   input key_mode,
   output vga_hs,
   output vga_vs,
   output [4:0] vga_r,
   output [5:0] vga_g,
   output [4:0] vga_b,
   output pll_locked
);

`include "chroni.vh"
   
   wire sys_clk;
   
   // global bus
   wire[7:0]  data = rom_data;
   
   reg[15:0]  dram_data_wr;
   reg[15:0]  dram_data_rd;
   
   reg[10:0]  rom_addr;
   wire[7:0]  rom_data;
   
   wire[13:0] chroni_addr;
   wire       chroni_rd_req;
   reg        chroni_rd_ack;
   
   reg[1:0] vga_mode;

   wire CLK_OUT1;
   wire CLK_OUT2;
   wire CLK_OUT3;
   wire CLK_OUT4;

   wire vga_clock = 
       vga_mode == VGA_MODE_640x480 ? CLK_OUT1 : 
      (vga_mode == VGA_MODE_800x600 ? CLK_OUT2 : CLK_OUT3);
   
   reg[3:0] bus_state;
   
   localparam BUS_STATE_INIT = 4'd0;
   localparam BUS_STATE_READY = 4'd1;
   localparam BUS_STATE_CHRONI_READ_REQ  = 4'd2;
   localparam BUS_STATE_WAIT = 4'd3;
   
   always @ (posedge sys_clk) begin
      reg key_mode_prev;
      reg key_mode_current;

      if (!vga_mode)
         vga_mode <= VGA_MODE_800x600;
      else begin
         key_mode_current <= key_mode;
         key_mode_prev    <= key_mode_current;
         if (key_mode_prev & ~key_mode_current) begin
            case (vga_mode)
               VGA_MODE_640x480:
                  vga_mode <= VGA_MODE_800x600;
               VGA_MODE_800x600:
                  vga_mode <= VGA_MODE_1920x1080;
               VGA_MODE_1920x1080:
                  vga_mode <= VGA_MODE_640x480;
            endcase
         end
      end
   end
   
   always @ (posedge sys_clk) begin
      if (~reset_n) begin
         bus_state  <= BUS_STATE_INIT;
         
         chroni_rd_ack <= 0;
         rom_addr <= 0;
      end else   begin
         chroni_rd_ack <= 0;
         case (bus_state)
            BUS_STATE_INIT : 
               bus_state <= BUS_STATE_READY;
            BUS_STATE_READY :
               begin
                  if (chroni_rd_req) begin
                     chroni_rd_ack <= 1;
                     bus_state <= BUS_STATE_CHRONI_READ_REQ;
                  end
               end
            BUS_STATE_CHRONI_READ_REQ :
               begin
                  bus_state <= BUS_STATE_READY;
               end
         endcase
      end
   end
   
   wire[10:0] bus_addr = chroni_addr;
   
   rom rom_inst (
      .clock(sys_clk),
      .address(bus_addr),
      .q(rom_data)
   );

   pll pll_inst (// Clock in ports
      .inclk0(clk),      // IN
      .c0(CLK_OUT1),     // 25.17Mhz  (640x480)
      .c1(CLK_OUT2),     // 40Mhz     (800x600)
      .c2(CLK_OUT3),     // 150Mhz    (1920x1080)
      .c3(sys_clk),      // 100Mhz (system)
      .areset(1'b0),     // reset input 
      .locked(pll_locked)
   );        // OUT

   reg[7:0] chroni_wr_data = 0;
   reg[3:0] chroni_wr_addr = 0;
   reg      chroni_wr_en = 0;
   
   chroni chroni_inst (
      .vga_clk(vga_clock),
      .sys_clk(sys_clk),
      .reset_n(reset_n),
      .vga_mode_in(vga_mode),
      .vga_hs(vga_hs),
      .vga_vs(vga_vs),
      .vga_r(vga_r),
      .vga_g(vga_g),
      .vga_b(vga_b),
      .addr_out(chroni_addr),
      .data_in(data),
      .rd_req(chroni_rd_req),
      .rd_ack(chroni_rd_ack),
      .cpu_wr_data(chroni_wr_data),
      .cpu_wr_addr(chroni_wr_addr),
      .cpu_wr_en(chroni_wr_en)
   );
   
endmodule

