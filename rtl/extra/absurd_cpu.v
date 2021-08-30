/*
   Absurd CPU

   This is a 6502 based CPU just for doing testing before adding a real CPU
   
   This CPU implements a "just enough" instruction set to test the 
   integration of components as they are being created/connected
   
*/

`timescale 1ns / 1ps

module absurd_cpu(
      input clk,
      input reset_n,
      output reg[15:0] bus_addr,
      input [7:0]  rd_data,
      output[7:0]  wr_data,
      output wr_enable,
      output rd_req,
      input  rd_ack
);

   reg[15:0] pc = 1092;
   reg[15:0] pc_next;
   reg[7:0]  reg_i;
   reg[7:0]  reg_a;
   reg[7:0]  reg_x;
   reg[7:0]  reg_y;
   reg[15:0] reg_w;

   reg[7:0]  reg_byte;
   reg[15:0] reg_word;

   localparam CPU_WAIT         = 0;
   localparam CPU_FETCH        = 1;
   localparam CPU_DECODE_WAIT  = 2;
   localparam CPU_LOAD_INST    = 3;
   localparam CPU_EXECUTE      = 4;
   localparam CPU_EXECUTE_WAIT = 5;
   
   reg[2:0] cpu_fetch_state = CPU_WAIT;
   
   always @ (posedge clk) begin : cpu_fetch
      if (~reset_n) begin
         cpu_fetch_state <= CPU_WAIT;
         pc <= 1092;
         fetch_rd_req    <= 0;
      end else if (cpu_fetch_state == CPU_WAIT && reset_n) begin
         cpu_fetch_state <= CPU_FETCH;
         fetch_rd_req    <= 0;
      end else begin 
         case(cpu_fetch_state)
            CPU_FETCH: 
               begin
                  fetch_rd_addr <= pc;
                  fetch_rd_req  <= 1;
                  cpu_fetch_state <= CPU_DECODE_WAIT;
               end
            CPU_DECODE_WAIT:
               if (rd_ack) begin
                  fetch_rd_req <= 0;
                  cpu_fetch_state <= CPU_LOAD_INST;
               end
            CPU_LOAD_INST:
               begin
                  reg_i <= rd_data;
                  cpu_fetch_state <= CPU_EXECUTE;
               end
            CPU_EXECUTE:
               cpu_fetch_state <= CPU_EXECUTE_WAIT;
            CPU_EXECUTE_WAIT:
               if (cpu_inst_done) begin
                  pc <= pc_next;
                  cpu_fetch_state <= CPU_FETCH;
               end
         endcase
      end
   end
   
   localparam NOP   = 0;
   localparam IMM_A = 1;
   localparam JMP   = 2;
   
   reg[4:0] cpu_inst_state = NOP;
   reg      cpu_inst_done;
   
   reg[15:0] mem_rd_addr;
   
   always @ (posedge clk) begin : cpu_decode
      data_rd_word_req <= 0;
      data_rd_byte_req <= 0;
      if (~reset_n) begin
         cpu_inst_state <= NOP;
      end else begin
         if (cpu_fetch_state == CPU_EXECUTE) begin
            case (reg_i)
               8'hA9: /* LDA # */
               begin
                  data_rd_byte_req <= 1;
                  data_rd_addr <= pc + 1'b1;
                  cpu_inst_state <= IMM_A;
               end
               8'h4C: /* JMP $ */
               begin
                  data_rd_word_req <= 1;
                  data_rd_addr <= pc + 1'b1; 
                  cpu_inst_state <= JMP;
               end
            endcase
         end
      end
   end
   
   always @ (posedge clk) begin : cpu_execute
      cpu_inst_done  <= 0;
      case (cpu_inst_state)
         IMM_A:
         if (bus_rd_ack) begin
            reg_a <= reg_byte;
            pc_next <= pc + 2'd2;
            cpu_inst_done <= 1;
         end
         JMP:
         if (bus_rd_ack) begin
            pc_next <= reg_word;
            cpu_inst_done <= 1;
         end
      endcase
   end
   
   reg bus_rd_req;
   reg bus_rd_ack;
   
   assign rd_req   = bus_rd_req;
   
   wire bus_rd_word_req = data_rd_word_req;
   wire bus_rd_byte_req = data_rd_byte_req | fetch_rd_req;
   wire bus_rd_data = bus_rd_word_req | bus_rd_byte_req;
   
   reg[15:0] data_rd_addr;
   reg[15:0] fetch_rd_addr;
   
   reg fetch_rd_req;
   
   reg data_rd_word_req;
   reg data_rd_byte_req;
   
   wire[15:0] bus_rd_addr = fetch_rd_req ? fetch_rd_addr : data_rd_addr;

   localparam BUS_RD_IDLE = 0;
   localparam BUS_RD_BYTE = 1;
   localparam BUS_RD_WORD_L = 2;
   localparam BUS_RD_WORD_H = 3;
   reg[3:0] bus_rd_state = BUS_RD_IDLE;

   always @ (posedge clk) begin : bus_read
      reg bus_rd_data_prev;
      
      bus_rd_ack <= 0;
      if (~reset_n) begin
         bus_rd_req <= 0;
         bus_rd_data_prev <= 0;
      end else begin
         bus_rd_data_prev <= bus_rd_data;
         if (!bus_rd_data_prev && bus_rd_data) begin
            bus_addr   <= bus_rd_addr;
            bus_rd_req <= 1;
            bus_rd_state <= data_rd_byte_req ? BUS_RD_BYTE : BUS_RD_WORD_L;
         end else begin
            case(bus_rd_state)
               BUS_RD_BYTE:
                  if (rd_ack) begin
                     reg_byte <= rd_data;
                     bus_rd_req <= 0;
                     bus_rd_ack <= 1;
                     bus_rd_state <= BUS_RD_IDLE;
                  end
               BUS_RD_WORD_L:
                  if (rd_ack) begin
                     reg_word[7:0] <= rd_data;
                     bus_addr   <= bus_rd_addr+1;
                     bus_rd_req <= 1;
                     bus_rd_state <= BUS_RD_WORD_H;
                  end
               BUS_RD_WORD_H:
                  if (rd_ack) begin
                     reg_word[15:8] <= rd_data;
                     bus_rd_req <= 0;
                     bus_rd_ack <= 1;
                     bus_rd_state <= BUS_RD_IDLE;
                  end
            endcase
         end
      end
   end      
   
endmodule