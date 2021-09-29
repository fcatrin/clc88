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
      output [15:0] addr,
      input  [7:0]  rd_data,
      output [7:0]  wr_data,
      output wr_en,
      output rd_req,
      input  ready
);

   reg[15:0] pc = 1092;
   reg[15:0] pc_next;
   reg[1:0]  pc_delta;
   reg[7:0]  reg_i;
   reg[7:0]  reg_a;
   reg[7:0]  reg_x;
   reg[7:0]  reg_y;
   reg[7:0]  reg_m;
   reg[7:0]  reg_sp;
   reg[15:0] reg_tmp;

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
   reg hold_fetch_addr;
   
   always @ (posedge clk) begin : cpu_fetch
      cpu_reset <= 0;
      fetch_rd_req <= 0;
      hold_fetch_addr <= 0;
      if (~reset_n) begin
         cpu_fetch_state <= CPU_WAIT;
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
                  cpu_fetch_state <= CPU_LOAD_INST;
                  hold_fetch_addr <= 1;
               end
            CPU_LOAD_INST:
            begin
               hold_fetch_addr <= 1;
               if (ready && !fetch_rd_req) begin
                  reg_i <= rd_data;
                  cpu_fetch_state <= CPU_EXECUTE;
               end
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
   localparam DONE      = 29;
   localparam JMP       = 2;
   localparam BRANCH    = 3;
   localparam NO_BRANCH = 4;
   localparam LDA       = 5;
   localparam LDX       = 6;
   localparam LDY       = 7;
   localparam LDA_Z     = 28;
   localparam LDA_Z_Y   = 8;
   localparam LDA_ABS   = 9;
   localparam LDA_ABS_X = 10;
   localparam LDA_ABS_Y = 11;
   localparam LDA_ADDR  = 12;
   localparam INX       = 13;
   localparam INY       = 14;
   localparam DEX       = 37;
   localparam DEY       = 38;
   localparam CMP       = 15;
   localparam CPX       = 16;
   localparam CPY       = 17;
   localparam STA       = 18;
   localparam STA_Z     = 19;
   localparam STA_ABS   = 20;
   localparam STA_ABS_X = 21;
   localparam STA_ADDR  = 22;
   localparam STM       = 23;
   localparam STM_ADDR  = 24;
   localparam INC_Z     = 25;
   localparam INC_ABS   = 26;
   localparam INC_ADDR  = 27;
   localparam PUSH      = 30;
   localparam POP       = 31;
   localparam JSR0      = 32;
   localparam JSR1      = 33;
   localparam RTS0      = 34;
   localparam RTS1      = 35;
   localparam RTS2      = 36;
   localparam AND       = 39;
   localparam ORA       = 40;
   
   reg[5:0] cpu_inst_state = NOP;
   reg[5:0] cpu_next_op    = NOP;
   reg[5:0] cpu_back_state = NOP;
   
   reg      cpu_inst_done;
   
   reg[15:0] op_addr;
   
   reg flag_z;
   
   always @ (posedge clk) begin : cpu_decode
      data_rd_word_req <= 0;
      data_rd_byte_req <= 0;
      data_wr_en <= 0;
      if (~reset_n) begin
         cpu_inst_state <= NOP;
         reg_sp <= 8'hff;
      end else begin
         if (cpu_reset) begin
            data_rd_word_req <= 1;
            data_rd_addr <= 16'hFFFC; 
            cpu_inst_state <= RESET;
         end else if (cpu_fetch_state == CPU_EXECUTE) begin
            pc_delta <= 0;
            case (reg_i)
               8'h09: /* ORA # */
                  cpu_inst_state <= ORA;
               8'h20: /* JSR $ */
               begin
                  cpu_inst_state <= JSR0;
                  data_rd_word_req <= 1;
               end
               8'h29: /* AND # */
                  cpu_inst_state <= AND;
               8'h4C: /* JMP $ */
               begin
                  cpu_inst_state <= JMP;
                  data_rd_word_req <= 1;
               end
               8'h60: /* RTS */
                  cpu_inst_state <= RTS0;
               8'h88: /* RTS */
                  cpu_inst_state <= DEY;
               8'hA0: /* LDY # */
                  cpu_inst_state <= LDY;
               8'hA2: /* LDX # */
                  cpu_inst_state <= LDX;
               8'hA5: /* LDA # */
                  cpu_inst_state <= LDA_Z;
               8'hA9: /* LDA # */
                  cpu_inst_state <= LDA;
               8'h85: /* STA Z */
                  cpu_inst_state <= STA_Z;
               8'h8D: /* STA $ */
                  cpu_inst_state <= STA_ABS;
               8'h9D: /* STA $,X */
                  cpu_inst_state <= STA_ABS_X;
               8'hAD: /* LDA $ */
                  cpu_inst_state <= LDA_ABS;
               8'hB1: /* LDA (Z),Y */
                  cpu_inst_state <= LDA_Z_Y;
               8'hBD: /* LDA $,X */
                  cpu_inst_state <= LDA_ABS_X;
               8'hBE: /* LDA $,Y */
                  cpu_inst_state <= LDA_ABS_Y;
               8'hC0: /* CPY # */
                  cpu_inst_state <= CPY;
               8'hC8: /* INY */
                  cpu_inst_state <= INY;
               8'hC9: /* CMP # */
                  cpu_inst_state <= CMP;
               8'hCA: /* DEX */
                  cpu_inst_state <= DEX;
               8'hE0: /* CPX # */
                  cpu_inst_state <= CPX;
               8'hE6: /* INC Z */
                  cpu_inst_state <= INC_Z;
               8'hE8: /* INX */
                  cpu_inst_state <= INX;
               8'hEE: /* INC_ABS */
                  cpu_inst_state <= INC_ABS;
               8'hD0: /* BNE */
               if (!flag_z) begin
                  data_rd_byte_req <= 1;
                  cpu_inst_state <= BRANCH;
                  pc_delta <= 0;
               end else begin
                  cpu_inst_state <= NO_BRANCH;
                  pc_delta <= 2;
               end
               8'hF0: /* BEQ */
               if (flag_z) begin
                  data_rd_byte_req <= 1;
                  cpu_inst_state <= BRANCH;
                  pc_delta <= 0;
               end else begin
                  cpu_inst_state <= NO_BRANCH;
                  pc_delta <= 2;
               end
            endcase
            
            // apply bit level logic for tese cases when instruction set is complete
            case(reg_i)
               8'h09,
               8'h29,
               8'hA0, 8'hA2, 8'hA5,
               8'hA9, 8'h85, 8'hB1,
               8'hC0, 8'hC9, 8'hE0,
               8'hE6:
               begin
                  data_rd_byte_req <= 1;
                  pc_delta <= 2;
               end
                  
               8'h8D, 8'h9D, 8'hAD,
               8'hBD, 8'hBE, 8'hEE:
               begin
                  data_rd_word_req <= 1;
                  pc_delta <= 3;
               end
            endcase
            
            case(reg_i)
               8'h88, 8'hC8, 8'hCA, 8'hE8, 8'h60:
                  pc_delta <= 1;
            endcase
            
            data_rd_addr <= pc + 1'b1;
         end else if (cpu_fetch_state == CPU_FETCH) begin
            cpu_inst_state <= NOP;
         end else begin
            case (cpu_next_op)
               LDA_Z_Y:
               begin
                  data_rd_word_req <= 1;
                  data_rd_addr <= op_addr;
                  cpu_inst_state <= LDA_ABS_Y;
               end
               LDA_ADDR:
               begin
                  data_rd_byte_req <= 1;
                  data_rd_addr <= op_addr;
                  cpu_inst_state <= LDA;
               end
               STA_ADDR:
               begin
                  data_wr_addr <= op_addr; 
                  data_wr_data <= reg_a;
                  data_wr_en   <= 1;
                  cpu_inst_state <= STA;
               end
               INC_ADDR:
               begin
                  data_rd_byte_req <= 1;
                  data_rd_addr <= op_addr;
                  cpu_inst_state <= INC_ADDR;
               end
               STM_ADDR:
               begin
                  data_wr_addr <= op_addr; 
                  data_wr_data <= reg_m;
                  data_wr_en   <= 1;
                  cpu_inst_state <= STM;
               end
               PUSH:
               begin
                  data_wr_addr <= {8'h01, reg_sp};
                  data_wr_data <= reg_tmp[7:0];
                  data_wr_en   <= 1;
                  cpu_inst_state <= cpu_back_state;
                  reg_sp <= reg_sp - 1'b1;
               end
               POP:
               begin
                  data_rd_byte_req <= 1;
                  data_rd_addr <= {8'h01, reg_sp + 1'b1};
                  cpu_inst_state <= cpu_back_state;
                  reg_sp <= reg_sp + 1'b1;
               end
            endcase
         end
      end
   end
   
   always @ (posedge clk) begin : cpu_execute
      cpu_inst_done  <= 0;
      cpu_next_op    <= NOP;
      if (cpu_inst_done == 0 && cpu_fetch_state == CPU_EXECUTE_WAIT) begin
         case (cpu_inst_state)
            INX:
            begin
               reg_x  <= reg_x + 1'b1;
               flag_z <= reg_x == 8'hff;
               pc_next <= pc + pc_delta;
               cpu_inst_done <= 1;
            end
            INY:
            begin
               reg_y  <= reg_y + 1'b1;
               flag_z <= reg_y == 8'hff;
               pc_next <= pc + pc_delta;
               cpu_inst_done <= 1;
            end
            DEX:
            begin
               reg_x  <= reg_x - 1'b1;
               flag_z <= reg_x == 1;
               pc_next <= pc + pc_delta;
               cpu_inst_done <= 1;
            end
            DEY:
            begin
               reg_y  <= reg_y - 1'b1;
               flag_z <= reg_y == 1;
               pc_next <= pc + pc_delta;
               cpu_inst_done <= 1;
            end
            STA, STM:
            begin
               pc_next <= pc + pc_delta;
               cpu_inst_done <= 1;
            end
            JSR1:
            begin
               reg_tmp <= {8'd0, reg_tmp[15:8]};
               cpu_next_op <= PUSH;
               cpu_back_state <= DONE;
            end
            RTS0:
            begin
               cpu_next_op <= POP;
               cpu_back_state <= RTS1;
            end
            NO_BRANCH:
            begin
               pc_next <= pc + pc_delta;
               cpu_inst_done <= 1;
            end
            DONE:
               cpu_inst_done <= 1;
         endcase

         if (bus_rd_ack) begin
            case (cpu_inst_state)
               RESET:
               begin
                  reg_a <= 0;
                  reg_x <= 0;
                  pc_next <= reg_word;
                  cpu_inst_done <= 1;
               end
               LDA:
               begin
                  reg_a <= reg_byte;
                  flag_z <= reg_byte == 0;
                  pc_next <= pc + pc_delta;
                  cpu_inst_done <= 1;
               end
               LDX:
               begin
                  reg_x <= reg_byte;
                  pc_next <= pc + pc_delta;
                  cpu_inst_done <= 1;
               end
               AND:
               begin
                  reg_a  <=  reg_a & reg_byte;
                  flag_z <= (reg_a & reg_byte) == 0;
                  pc_next <= pc + pc_delta;
                  cpu_inst_done <= 1;
               end
               ORA:
               begin
                  reg_a  <=  reg_a | reg_byte;
                  flag_z <= (reg_a | reg_byte) == 0;
                  pc_next <= pc + pc_delta;
                  cpu_inst_done <= 1;
               end
               CMP:
               begin
                  flag_z <= reg_a == reg_byte;
                  pc_next <= pc + pc_delta;
                  cpu_inst_done <= 1;
               end
               CPX:
               begin
                  flag_z <= reg_x == reg_byte;
                  pc_next <= pc + pc_delta;
                  cpu_inst_done <= 1;
               end
               CPY:
               begin
                  flag_z <= reg_y == reg_byte;
                  pc_next <= pc + pc_delta;
                  cpu_inst_done <= 1;
               end
               LDY:
               begin
                  reg_y <= reg_byte;
                  pc_next <= pc + pc_delta;
                  cpu_inst_done <= 1;
               end
               INC_Z:
               begin
                  op_addr <= {8'd0, reg_byte};
                  cpu_next_op <= INC_ADDR;
               end
               INC_ABS:
               begin
                  op_addr <= reg_word;
                  cpu_next_op <= INC_ADDR;
               end
               INC_ADDR:
               begin
                  reg_m <= reg_byte + 1'b1;
                  flag_z <= reg_byte == 8'hff;
                  cpu_next_op <= STM_ADDR;
               end
               LDA_Z_Y:
               begin
                  op_addr <= {8'd0, reg_byte};
                  cpu_next_op <= LDA_Z_Y;
               end
               LDA_Z:
               begin
                  op_addr <= {8'd0, reg_byte};
                  cpu_next_op <= LDA_ADDR;
               end
               LDA_ABS:
               begin
                  op_addr <= reg_word;
                  cpu_next_op <= LDA_ADDR;
               end
               LDA_ABS_Y:
               begin
                  op_addr <= reg_word + reg_y;
                  cpu_next_op <= LDA_ADDR;
               end
               LDA_ABS_X:
               begin
                  op_addr <= reg_word + reg_x;
                  cpu_next_op <= LDA_ADDR;
               end
               STA_Z:
               begin
                  op_addr <= {8'd0, reg_byte};
                  cpu_next_op <= STA_ADDR;
               end
               STA_ABS:
               begin
                  op_addr <= reg_word;
                  cpu_next_op <= STA_ADDR;
               end
               STA_ABS_X:
               begin
                  op_addr <= reg_word + reg_x;
                  cpu_next_op <= STA_ADDR;
               end
               JMP:
               begin
                  pc_next <= reg_word;
                  cpu_inst_done <= 1;
               end
               JSR0:
               begin
                  pc_next <= reg_word;
                  reg_tmp <= pc + 3;
                  cpu_next_op <= PUSH;
                  cpu_back_state <= JSR1;
               end
               RTS1:
               begin
                  pc_next[15:8] <= reg_byte;
                  cpu_next_op <= POP;
                  cpu_back_state <= RTS2;
               end
               RTS2:
               begin
                  pc_next[7:0] <= reg_byte;
                  cpu_inst_done <= 1;
               end
               BRANCH:
               begin
                  pc_next <= (pc + $signed(reg_byte)) + 2'd2;
                  cpu_inst_done <= 1;
               end
            endcase
         end
      end
   end
   
   reg[15:0] bus_addr;
   reg bus_rd_req;
   reg bus_rd_ack;
   reg bus_wr_en;


   assign wr_en  = bus_wr_en;
   assign rd_req = fetch_rd_req | bus_rd_req;
   assign addr   = hold_fetch_addr ? fetch_rd_addr : bus_addr;

   reg[15:0] data_rd_addr;
   reg[15:0] fetch_rd_addr;
   reg       fetch_rd_req;

   reg[7:0] bus_wr_data;
   assign wr_data = bus_wr_data;
      
   wire bus_rd_data = data_rd_word_req | data_rd_byte_req;
   
   reg[15:0] data_wr_addr; 
   reg[7:0]  data_wr_data;
   reg       data_wr_en;
   
   reg data_rd_word_req;
   reg data_rd_byte_req;
   
   localparam BUS_RD_IDLE   = 0;
   localparam BUS_RD_BYTE   = 1;
   localparam BUS_RD_WORD_L = 2;
   localparam BUS_RD_WORD_H = 3;
   localparam BUS_WR_BYTE   = 4;
   reg[3:0] bus_rd_state = BUS_RD_IDLE;

   always @ (posedge clk) begin : bus_access
      bus_rd_ack <= 0;
      bus_wr_en  <= 0;
      bus_rd_req <= 0;
      if (~reset_n) begin
         bus_rd_state <= BUS_RD_IDLE;
      end else begin
         if (bus_rd_data) begin
            bus_addr     <= data_rd_addr;
            bus_rd_req   <= 1;
            bus_rd_state <= data_rd_byte_req ? BUS_RD_BYTE : BUS_RD_WORD_L;
         end else if (data_wr_en) begin
            bus_addr     <= data_wr_addr;
            bus_wr_data  <= data_wr_data;
            bus_wr_en    <= data_wr_en;
            bus_rd_state <= BUS_RD_IDLE;
         end else if (ready && !bus_rd_req) begin
            case(bus_rd_state)
               BUS_RD_BYTE:
                  begin
                     reg_byte <= rd_data;
                     bus_rd_ack <= 1;
                     bus_rd_state <= BUS_RD_IDLE;
                  end
               BUS_RD_WORD_L:
                  begin
                     reg_word[7:0] <= rd_data;
                     bus_addr      <= data_rd_addr + 1'b1;
                     bus_rd_req    <= 1;
                     bus_rd_state  <= BUS_RD_WORD_H;
                  end
               BUS_RD_WORD_H:
                  begin
                     reg_word[15:8] <= rd_data;
                     bus_rd_ack <= 1;
                     bus_rd_state <= BUS_RD_IDLE;
                  end
            endcase
         end
      end
   end      
   
endmodule