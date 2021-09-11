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
   
   wire[7:0]  rom_data;
   
   wire[15:0] cpu_addr;
   wire       cpu_rd_req;
   reg        cpu_rd_ack;
   
   reg[1:0] vga_mode;

   wire CLK_OUT1;
   wire CLK_OUT2;
   wire CLK_OUT3;
   wire CLK_OUT4;

   wire vga_clock = 
       vga_mode == VGA_MODE_640x480 ? CLK_OUT1 : 
      (vga_mode == VGA_MODE_800x600 ? CLK_OUT2 : CLK_OUT3);
   
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

   localparam BUS_IDLE = 4'd0;
   localparam BUS_READ = 4'd1;
   localparam BUS_DONE = 4'd2;

   always @ (posedge sys_clk) begin
      reg[3:0] bus_state;

      cpu_rd_ack    <= 0;
      if (~reset_n) begin
         bus_state  <= BUS_IDLE;
      end else   begin
         case (bus_state)
            BUS_IDLE: 
            begin
               bus_state <= BUS_READ;
            end
            BUS_READ:
               begin
                  if (cpu_rd_req) begin
                     bus_state <= BUS_DONE;
                  end
               end
            BUS_DONE:
            begin
               cpu_rd_ack <= 1;
               bus_state <= BUS_IDLE;
            end
         endcase
      end
   end
   
   wire[12:0] rom_addr = cpu_addr[12:0]; 
   
   rom rom_inst (
      .clock(sys_clk),
      .address(rom_addr),
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
      .cpu_wr_data(cpu_wr_data),
      .cpu_wr_en(cpu_wr_en),
      .cpu_addr(cpu_addr)
   );
   
   wire[7:0] cpu_wr_data;
   wire      cpu_wr_en;
   
   cornet_cpu cornet_cpu_inst (
         .clk(sys_clk),
         .reset_n(reset_n),
         .bus_addr(cpu_addr),
         .rd_data(data),
         .wr_data(cpu_wr_data),
         .wr_en(cpu_wr_en),
         .rd_req(cpu_rd_req),
         .rd_ack(cpu_rd_ack)
      );
   
endmodule

