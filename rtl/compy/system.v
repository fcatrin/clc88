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
   output pll_locked,
   input [4:0] buttons
);

`include "chroni.vh"
   
   wire sys_clk;
   
   // global bus
   wire[7:0]  data = chroni_cs ? chroni_rd_data : (ram_cs ? ram_rd_data : (io_cs ? io_rd_data : rom_rd_data));
   wire rom_s    = cpu_addr[15:14] == 2'b11;  // 0xc000 and above
   wire ram_s    = cpu_addr[15:12] == 4'b1000 || !cpu_addr[15]; // 0x0000 -> 0x8fff
   wire io_s     = cpu_addr[15:8]  == 8'b10010010;  // 0x92XX
   wire chroni_s = cpu_addr[15:7]  == 9'b100100000; // 0x90XX 
   wire sys_s    = cpu_addr[15:8]  == 8'b10010011;  // 0x93XX
   
   reg rom_cs;
   reg ram_cs;
   reg io_cs;
   reg chroni_cs;
   reg sys_cs;
   
   wire[15:0] cpu_addr;
   wire       cpu_rd_req;
   reg        cpu_ready;
   
   localparam BUS_IDLE = 4'd0;
   localparam BUS_READ = 4'd1;
   localparam BUS_DONE = 4'd2;

   always @ (posedge sys_clk) begin
      reg[3:0] bus_state;
      reg cpu_rd_req_prev;

      cpu_ready <= 1;
      if (~reset_n) begin
         bus_state  <= BUS_IDLE;
         rom_cs <= 0;
         ram_cs <= 0;
         io_cs  <= 0;
         chroni_cs <= 0;
         sys_cs <= 0;
      end else begin
         cpu_rd_req_prev <= cpu_rd_req;
         if ((!cpu_rd_req_prev & cpu_rd_req) | cpu_wr_en) begin
            if ((!cpu_rd_req_prev & cpu_rd_req)) begin
               bus_state  <= BUS_READ;
               cpu_ready  <= 0;
            end
            rom_cs    <= rom_s;
            ram_cs    <= ram_s;
            io_cs     <= io_s;
            chroni_cs <= chroni_s;
            sys_cs    <= sys_s;
         end else case (bus_state)
            BUS_IDLE: 
               bus_state <= bus_state;
            BUS_READ:
               bus_state <= BUS_IDLE;
         endcase
      end
   end
   
   wire[12:0] rom_addr = cpu_addr[12:0]; 
   wire[7:0]  rom_rd_data;
   
   rom rom_inst (
      .clock(sys_clk),
      .address(rom_addr),
      .q(rom_rd_data)
   );
   
   // use block ram for testing only
   // it will be replaced by sram in the future
   
   wire[15:0] ram_addr = cpu_addr[15:0];
   wire[7:0]  ram_rd_data;
   wire[7:0]  ram_wr_data = cpu_wr_data;
   wire       ram_wr_en = cpu_wr_en;
   
   spram #(65536, 16, 8) ram (
         .address(ram_addr),
         .clock(sys_clk),
         .data(ram_wr_data),
         .wren(ram_wr_en && ram_s),
         .q(ram_rd_data)
      );
         

   assign pll_locked = pll1_locked & pll2_locked;
   wire pll1_locked;
   wire pll2_locked;
   
   pll1 pll1_inst (
      .inclk0(clk),      // IN
      .c0(sys_clk),      // 100Mhz    (system)
      .c1(CLK_OUT1),     // 25.17Mhz  (640x480)
      .c2(CLK_OUT2),     // 40Mhz     (800x600)
      .areset(1'b0), 
      .locked(pll1_locked)
   );
   
   pll2 pll2_inst (
      .inclk0(clk),
      .c0(CLK_OUT3),     // 148.5Mhz  (1920x1080)
      .areset (1'b0),
      .locked (pll2_locked)
   );

   reg[1:0] vga_mode;

   wire CLK_OUT1;
   wire CLK_OUT2;
   wire CLK_OUT3;
   wire CLK_OUT4;
   wire CLK_OUT3_OLD;

   wire vga_clock = 
      vga_mode == VGA_MODE_640x480 ? CLK_OUT1 : 
      (vga_mode == VGA_MODE_800x600 ? CLK_OUT2 : CLK_OUT3);
   
   always @ (posedge sys_clk) begin
      reg key_mode_prev;
      reg key_mode_current;

      if (!vga_mode)
         vga_mode <= VGA_MODE_1920x1080;
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
   
   always @ (posedge sys_clk) begin : sys_ctl
      reg [2:0] cpu_speed;
      reg cpu_clk_en_signal_prev;
      
      if (cpu_wr_en & sys_s) begin
         case(cpu_addr[7:0])
            7'h00 : cpu_speed <= cpu_wr_data[2:0];
         endcase
      end
      
      cpu_clk_100 <= 0;
      cpu_clk_50  <= 0;
      cpu_clk_25  <= 0;
      cpu_clk_12  <= 0;
      cpu_clk_6   <= 0;
      cpu_clk_3   <= 0;
      
      case(cpu_speed)
         3'd0 : cpu_clk_100 <= 1;
         3'd1 : cpu_clk_50 <= 1;
         3'd2 : cpu_clk_25 <= 1;
         3'd3 : cpu_clk_12 <= 1;
         3'd4 : cpu_clk_6  <= 1;
         default : cpu_clk_3  <= 1;
      endcase
      
      cpu_clk_en_signal_prev <= cpu_clk_en_signal;
      cpu_clk_en <= cpu_clk_100 | (!cpu_clk_en_signal_prev & cpu_clk_en_signal);

   end

   wire[7:0] chroni_rd_data;
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
      .cpu_rd_data(chroni_rd_data),
      .cpu_wr_data(cpu_wr_data),
      .cpu_wr_en(cpu_wr_en & chroni_s),
      .cpu_addr(cpu_addr)
   );
   
   wire[7:0] cpu_wr_data;
   wire      cpu_wr_en;
   
   reg cpu_clk_en;
   wire cpu_clk_en_signal =
      cpu_clk_100 ? cpu_clk_en_100 :
      cpu_clk_50 ? cpu_clk_en_50 :
      cpu_clk_25 ? cpu_clk_en_25 :
      cpu_clk_12 ? cpu_clk_en_12 :
      cpu_clk_6  ? cpu_clk_en_6  : cpu_clk_en_3;
   
   reg  cpu_clk_en_100;
   reg  cpu_clk_en_50;
   reg  cpu_clk_en_25;
   reg  cpu_clk_en_12;
   reg  cpu_clk_en_6;
   reg  cpu_clk_en_3;
   reg  cpu_clk_100;
   reg  cpu_clk_50;
   reg  cpu_clk_25;
   reg  cpu_clk_12;
   reg  cpu_clk_6;
   reg  cpu_clk_3;
   
   always @ (posedge sys_clk) begin : cpu_throttle
      reg[4:0] counter;
      
      if (!reset_n) begin
         counter <= 0;
      end else begin
         counter <= counter + 1'b1;
      end
      
      cpu_clk_en_50 <= !counter[0]; // all negated to align them all with the rising edge
      cpu_clk_en_25 <= !counter[1];
      cpu_clk_en_12 <= !counter[2];
      cpu_clk_en_6  <= !counter[3];
      cpu_clk_en_3  <= !counter[4];
   end
   
   // cornet_cpu cornet_cpu_inst (
   m6502_cpu cpu_6502_main (
         .clk(sys_clk),
         .clk_en(cpu_clk_en),
         .reset_n(reset_n),
         .bus_addr(cpu_addr),
         .bus_rd_data(data),
         .bus_wr_data(cpu_wr_data),
         .bus_wr_en(cpu_wr_en),
         .bus_rd_req(cpu_rd_req),
         .ready(cpu_ready),
         .nmi_n(1'b1),
         .irq_n(1'b1)
      );
      

   wire[3:0] io_addr = cpu_addr[3:0];
   wire[7:0] io_rd_data;
   wire[7:0] io_wr_data = cpu_wr_data;
   wire      io_wr_en = cpu_wr_en;

   qmtech_board io (
         .clk(sys_clk),
         .reset_n(reset_n),
         .addr(io_addr),
         .rd_data(io_rd_data),
         .wr_data(io_wr_data),
         .wr_en(io_wr_en && io_cs),
         .buttons(buttons)
   );
endmodule

