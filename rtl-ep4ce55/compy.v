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
   /*
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
   */   
);

`include "chroni.vh"
   
   // global bus
   wire[15:0] addr;
   wire[7:0]  data;
   assign data = rom_data;
   
   wire[18:0] dram_addr;
   reg[15:0]  dram_data_wr;
   reg[15:0]  dram_data_rd;
   
   reg[10:0]  rom_addr;
   wire[7:0]  rom_data;
   
   assign dram_addr = ram_s ? addr : (vram_s ? {4'b001, vga_addr} : 19'b0);

   wire[7:0]  chroni_page;
   wire[13:0] chroni_addr;
   wire       chroni_rd_req;
   reg        chroni_rd_ack;
   
   wire[16:0] vga_addr = {chroni_page, 9'b000000000} + chroni_addr;

   assign vram_dbr_o = rom_data;
   assign addr = vga_addr[15:0];
   
   reg[1:0] vga_mode;

   wire CLK_OUT1;
   wire CLK_OUT2;
   wire CLK_OUT3;
   wire CLK_OUT4;

   wire vga_clock;
   reg  sdram_clock;
   
   assign vga_clock = 
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
   
   reg[3:0] bus_state;
   
   localparam BUS_STATE_INIT = 4'd0;
   localparam BUS_STATE_READY = 4'd1;
   localparam BUS_STATE_CHRONI_READ_REQ  = 4'd2;
   localparam BUS_STATE_CHRONI_READ_REQ2 = 4'd3;
   localparam BUS_STATE_WAIT = 4'd4;
   
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
      reg chroni_rd_req_prev;
      if (~reset_n) begin
         rom_cs     <= 0;
         ram_cs     <= 0;
         vram_cs    <= 0;
         chroni_cs  <= 0;
         storage_cs <= 0;
         keyb_cs    <= 0;
         pokey_cs   <= 0;
         bus_state  <= BUS_STATE_INIT;
         sdram_bus_rd_req <= 0;
         sdram_bus_wr_req <= 0;
         
         chroni_rd_ack <= 0;
         rom_addr <= 0;
         
      end else   begin
         rom_cs     <= rom_s;
         ram_cs     <= ram_s;
         vram_cs    <= vram_s;
         chroni_cs  <= chroni_s;
         storage_cs <= storage_s;
         keyb_cs    <= keyb_s;
         pokey_cs   <= pokey_s;
         
         case (bus_state)
            BUS_STATE_INIT : 
               if (sdram_state != SDRAM_STATE_INIT) begin
                  bus_state <= BUS_STATE_READY;
               end
            BUS_STATE_READY :
               begin
                  if (chroni_rd_req) begin
                     rom_addr <= chroni_addr[10:0];
                     bus_state <= BUS_STATE_CHRONI_READ_REQ;
                  end
               end
            BUS_STATE_CHRONI_READ_REQ :
               begin
                  chroni_rd_ack <= 1;
                  bus_state <= BUS_STATE_CHRONI_READ_REQ2;
               end
            BUS_STATE_CHRONI_READ_REQ2 :
               begin
                  bus_state <= BUS_STATE_READY;
                  chroni_rd_ack <= 0;
               end
         endcase
      end
      
      sdram_clock = ~sdram_clock;
   end
   
   localparam SDRAM_STATE_INIT  = 4'd0;
   localparam SDRAM_STATE_READY = 4'd1;
   localparam SDRAM_STATE_WAIT_ACK_WRITE = 4'd2;
   localparam SDRAM_STATE_WAIT_ACK_READ  = 4'd3;
   
   reg   [3:0] sdram_state;
   reg         sdram_wr_req;
   reg         sdram_rd_req;
   wire        sdram_wr_ack;
   wire        sdram_rd_ack;
   reg   [8:0] wr_length;
   reg   [8:0] rd_length;
   reg  [22:0] wr_addr;
   reg  [22:0] rd_addr;
   reg  [15:0] sdram_din;
   wire [15:0] sdram_dout;
   wire        sdram_init_done;
   
   reg sdram_bus_rd_req;
   reg sdram_bus_wr_req;
   reg sdram_bus_rd_ack;
   reg sdram_bus_wr_ack;

   // SDRAM interface
   always @ (posedge sdram_clock) begin
      if (~reset_n) begin
         sdram_state <= SDRAM_STATE_INIT;
         wr_length <= 9'd0;
         rd_length <= 9'd0;
         sdram_wr_req <= 1'b0;
         sdram_rd_req <= 1'b0;
         wr_addr <= 23'd0;
         rd_addr <= 23'd0;
         sdram_din <= 16'd0;
         sdram_bus_rd_ack <= 0;
         sdram_bus_wr_ack <= 0;
      end else begin
         case (sdram_state)
            SDRAM_STATE_INIT:
               if (sdram_init_done) sdram_state <= SDRAM_STATE_READY;
            SDRAM_STATE_READY:
               if (sdram_bus_wr_req) begin
                  sdram_bus_wr_ack <= 0;
                  sdram_wr_req <= 1;
                  wr_addr <= dram_addr;
                  sdram_din <= dram_data_wr;
                  sdram_state = SDRAM_STATE_WAIT_ACK_WRITE;
               end else if (sdram_bus_rd_req) begin
                  sdram_bus_rd_ack <= 0;
                  sdram_rd_req <= 1;
                  rd_addr <= dram_addr;
                  sdram_state = SDRAM_STATE_WAIT_ACK_READ;
               end
            SDRAM_STATE_WAIT_ACK_WRITE:
               if (sdram_wr_ack) begin
                  sdram_state = SDRAM_STATE_READY;
                  sdram_bus_wr_ack <= 1;
               end
            SDRAM_STATE_WAIT_ACK_READ:
               if (sdram_rd_ack) begin
                  dram_data_rd <= sdram_dout;
                  sdram_state = SDRAM_STATE_READY;
                  sdram_bus_rd_ack <= 1;
               end
         endcase
      end
   end

   
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
      .c3(sys_clk),      // 200Mhz (ROM)
      .areset(1'b0),     // reset input 
      .locked(LOCKED)
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
      .addr_out(chroni_addr),
      .addr_out_page(chroni_page),
      .data_in(data),
      .rd_req(chroni_rd_req),
      .rd_ack(chroni_rd_ack)
   );
   
   /*
    
   sdram_top      u_sdramtop (
      //global clock
      .clk               (sdram_clock),      //sdram reference clock
      .rst_n             (reset_n),         //global reset

      //internal interface   
      .sdram_wr_req      (sdram_wr_req),    //sdram write request
      .sdram_rd_req      (sdram_rd_req),    //sdram write ack
      .sdram_wr_ack      (sdram_wr_ack),    //sdram read request
      .sdram_rd_ack      (sdram_rd_ack),   //sdram read ack
      .sys_wraddr        (sdram_wraddr),    //sdram write address 
      .sys_rdaddr        (sdram_rdaddr),    //sdram read address
      .sys_data_in       (sdram_din),       //fifo 2 sdram data input
      .sys_data_out      (sdram_dout),      //sdram 2 fifo data input
      .sdram_init_done   (sdram_init_done),   //sdram init done

      //burst length
      .sdwr_byte         (wr_length),      //sdram write burst length
      .sdrd_byte         (rd_length),      //sdram read burst length

      //sdram interface
      //   .sdram_clk         (sdram_clk),      //sdram clock   
      .sdram_cke         (S_CKE),      //sdram clock enable   
      .sdram_cs_n        (S_NCS),      //sdram chip select   
      .sdram_we_n        (S_NWE),      //sdram write enable   
      .sdram_ras_n       (S_NRAS),      //sdram column address strobe   
      .sdram_cas_n       (S_NCAS),      //sdram row address strobe   
      .sdram_ba          (S_BA),         //sdram data enable (H:8)    
      .sdram_addr        (S_A),      //sdram data enable (L:8)   
      .sdram_data        (S_DB)      //sdram bank address   
      //   .sdram_udqm         (sdram_udqm),      //sdram address   
      //   .sdram_ldqm         (sdram_ldqm)      //sdram data   
   );
 */
endmodule

