/*
   Cornet CPU

   This an absurdly simple 6502 based CPU just for doing testing before adding a real CPU
   
   This CPU implements a "just enough" instruction set to test the 
   integration of components as they are being created/connected
   
   Don't look unless you need a good laugh
*/

`timescale 1ns / 1ps

module cornet_cpu(
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
   reg[1:0]  pc_delta;
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
   localparam CPU_RESET        = 6;
   
   reg[2:0] cpu_fetch_state = CPU_WAIT;
   reg cpu_reset;
   
   always @ (posedge clk) begin : cpu_fetch
      cpu_reset <= 0;
      if (~reset_n) begin
         cpu_fetch_state <= CPU_WAIT;
         fetch_rd_req    <= 0;
      end else if (cpu_fetch_state == CPU_WAIT && reset_n) begin
         cpu_fetch_state <= CPU_RESET;
      end else begin 
         case(cpu_fetch_state)
            CPU_RESET:
            begin
               cpu_reset <= 1;
               cpu_fetch_state <= CPU_EXECUTE;
            end
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
            begin
               cpu_fetch_state <= CPU_EXECUTE_WAIT;
               cpu_reset <= 0;
            end
            CPU_EXECUTE_WAIT:
               if (cpu_inst_done) begin
                  pc <= pc_next;
                  cpu_fetch_state <= CPU_FETCH;
               end
         endcase
      end
   end
   
   localparam NOP       = 0;
   localparam RESET     = 1;
   localparam JMP       = 2;
   localparam LDA       = 3;
   localparam LDX       = 4;
   localparam LDA_ABS_X = 5;
   localparam INX       = 6;
   localparam BRANCH    = 7;
   localparam NO_BRANCH = 8;
   localparam LDA_ADDR  = 9;
   
   reg[4:0] cpu_inst_state = NOP;
   reg[4:0] cpu_next_op    = NOP;
   
   reg      cpu_inst_done;
   
   reg[15:0] op_addr;
   
   reg flag_z;
   
   always @ (posedge clk) begin : cpu_decode
      data_rd_word_req <= 0;
      data_rd_byte_req <= 0;
      if (~reset_n) begin
         cpu_inst_state <= NOP;
      end else begin
         if (cpu_reset) begin
            data_rd_word_req <= 1;
            data_rd_addr <= 16'hFFFC; 
            cpu_inst_state <= RESET;
         end else if (cpu_fetch_state == CPU_EXECUTE) begin
            case (reg_i)
               8'hA2: /* LDX # */
               begin
                  data_rd_byte_req <= 1;
                  data_rd_addr <= pc + 1'b1;
                  cpu_inst_state <= LDX;
                  pc_delta <= 2;
               end
               8'hA9: /* LDA # */
               begin
                  data_rd_byte_req <= 1;
                  data_rd_addr <= pc + 1'b1;
                  cpu_inst_state <= LDA;
                  pc_delta <= 2;
               end
               8'hBD: /* LDA $,X */
               begin
                  data_rd_word_req <= 1;
                  data_rd_addr <= pc + 1'b1; 
                  cpu_inst_state <= LDA_ABS_X;
                  pc_delta <= 2;
               end
               8'hE8: /* INX */
               begin
                  cpu_inst_state <= INX;
                  pc_delta <= 1;
               end
               8'h4C: /* JMP $ */
               begin
                  data_rd_word_req <= 1;
                  data_rd_addr <= pc + 1'b1; 
                  cpu_inst_state <= JMP;
                  pc_delta <= 0;
               end
               8'hD0: /* BNE */
               if (flag_z) begin
                  data_rd_byte_req <= 1;
                  data_rd_addr <= pc + 1'b1;
                  cpu_inst_state <= BRANCH;
                  pc_delta <= 0;
               end else begin
                  cpu_inst_state <= NO_BRANCH;
                  pc_delta <= 2;
               end
            endcase
         end else begin
            case (cpu_next_op)
               LDA_ADDR:
               begin
                  data_rd_byte_req <= 1;
                  data_rd_addr <= op_addr;
                  cpu_inst_state <= LDA;
               end
            endcase
         end
      end
   end
   
   always @ (posedge clk) begin : cpu_execute
      cpu_inst_done  <= 0;
      cpu_next_op    <= NOP;
      case (cpu_inst_state)
         RESET:
         if (bus_rd_ack) begin
            reg_a <= 0;
            reg_x <= 0;
            pc_next <= reg_word;
            cpu_inst_done <= 1;
         end
         INX:
         begin
            reg_x  <= reg_x + 1;
            flag_z <= reg_x == 8'hff;
            pc_next <= pc + pc_delta;
            cpu_inst_done <= 1;
         end
         LDA:
         if (bus_rd_ack) begin
            reg_a <= reg_byte;
            pc_next <= pc + pc_delta;
            cpu_inst_done <= 1;
         end
         LDX:
         if (bus_rd_ack) begin
            reg_x <= reg_byte;
            pc_next <= pc + pc_delta;
            cpu_inst_done <= 1;
         end
         LDA_ABS_X:
         if (bus_rd_ack) begin
            op_addr <= reg_word + reg_x;
            cpu_next_op <= LDA_ADDR;
         end
         JMP:
            if (bus_rd_ack) begin
               pc_next <= reg_word;
               cpu_inst_done <= 1;
            end
         NO_BRANCH:
         begin
            pc_next <= pc + pc_delta;
            cpu_inst_done <= 1;
         end
         BRANCH:
         if (bus_rd_ack) begin
            pc_next <= pc + 2 + (reg_byte[7] ? -(~reg_byte) : reg_byte);
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
            bus_rd_state <= bus_rd_byte_req ? BUS_RD_BYTE : BUS_RD_WORD_L;
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