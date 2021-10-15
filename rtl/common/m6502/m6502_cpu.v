/*
 * MOS 6502 (based con cornet_cpu draft) 
 * 
 * Instruction reference and decoding tips
 * https://www.masswerk.at/6502/6502_instruction_set.html
 * 
 * Also got some ideas from 
 * https://github.com/dmsc/my6502/blob/master/rtl/cpu.v
 * 
 */

module m6502_cpu (
      input clk,
      input reset_n,
      output [15:0] addr,
      input  [7:0]  rd_data,
      output [7:0]  wr_data,
      output wr_en,
      output rd_req,
      input  ready
      );

   `include "m6502_alu_ops.vh"
   
   reg[15:0] pc;
   reg[15:0] pc_op;
   reg[1:0]  pc_delta;
   reg[7:0]  reg_i;
   reg[7:0]  reg_a;
   reg[7:0]  reg_x;
   reg[7:0]  reg_y;
   reg[7:0]  reg_sp;
   reg[7:0]  reg_m;
   reg[7:0]  reg_write;
   reg[7:0]  reg_ndx;
   reg[7:0]  reg_ndx_pre;
   reg[7:0]  reg_ndx_post;
   reg[15:0] reg_word;
   
   wire[2:0] aaa = reg_i[7:5];
   wire[2:0] bbb = reg_i[4:2];
   wire[2:0] cc  = reg_i[1:0];

   reg flag_i;

   localparam CPU_WAIT         = 0;
   localparam CPU_FETCH        = 1;
   localparam CPU_EXECUTE      = 2;
   localparam CPU_EXECUTE_WAIT = 3;
   localparam CPU_RESET        = 4;
   
   reg[2:0] cpu_fetch_state = CPU_WAIT;
   reg cpu_reset;
   reg cpu_inst_done;
   reg cpu_inst_state;
   reg cpu_inst_single;
   reg[2:0] cpu_branch;
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
                  fetch_rd_addr <= pc;
                  fetch_rd_req  <= 1;
                  pc_op <= pc + 1;
                  cpu_fetch_state <= CPU_FETCH;
                  hold_fetch_addr <= 1;
               end
         endcase
      end
   end
   
   always @ (posedge clk) begin : cpu_decode
      reg wait_for_reset;
      
      address_mode_prepare <= MODE_IDLE;
      cpu_inst_done <= 0;
      if (~reset_n) begin
         wait_for_reset <= 0;
      end else if (cpu_fetch_state == CPU_EXECUTE) begin
         do_load_store <= DO_NOTHING;
         address_mode_prepare <= MODE_SINGLE;
         cpu_inst_single <= 0;
         cpu_op <= CPU_OP_NOP;
         if (cpu_reset) begin
            reg_a <= 0;
            reg_x <= 0;
            reg_y <= 0;
            address_mode_prepare <= MODE_RESET;
            wait_for_reset <= 1;
         end else case (cc)  // reg_i format aaabbbcc. Check cc first
            2'b00:
               if (bbb == 4) begin /* BRANCH */
                  cpu_op <= CPU_OP_BRANCH;
                  cpu_branch <= aaa;
                  address_mode_prepare <= MODE_IMM;
               end else if (bbb == 6) begin
                  cpu_inst_single <= aaa != 4;
                  case (aaa)
                     0: cpu_op <= CPU_OP_CLC;
                     1: cpu_op <= CPU_OP_SEC;
                     2: cpu_op <= CPU_OP_CLI;
                     3: cpu_op <= CPU_OP_SEI;
                     4: cpu_op <= CPU_OP_TYA;
                     5: cpu_op <= CPU_OP_CLV;
                     6: cpu_op <= CPU_OP_CLD;
                     7: cpu_op <= CPU_OP_SED;
                  endcase
               end else begin
                  if (aaa[2]) case(bbb)
                     0: address_mode_prepare <= MODE_IMM;
                     1: address_mode_prepare <= MODE_Z;
                     2: address_mode_prepare <= MODE_SINGLE;
                     3: address_mode_prepare <= MODE_ABS;
                     5: address_mode_prepare <= MODE_Z_X;
                     7: address_mode_prepare <= MODE_ABS_X;
                  endcase
                  case(aaa)
                     0,1,2,3:
                        case(bbb)
                           0: case(aaa)
                                 0: cpu_op <= CPU_OP_BRK;
                                 1: cpu_op <= CPU_OP_JSR;
                                 2: cpu_op <= CPU_OP_RTI;
                                 3: cpu_op <= CPU_OP_RTS;
                              endcase
                           1: if (aaa == 1) begin
                                 cpu_op <= CPU_OP_BIT;
                                 address_mode_prepare <= MODE_Z;
                              end
                           2: case(aaa)
                                 0: cpu_op <= CPU_OP_PHP;
                                 1: cpu_op <= CPU_OP_PLP;
                                 2: cpu_op <= CPU_OP_PHA;
                                 3: cpu_op <= CPU_OP_PLA;
                              endcase
                           3: case(aaa)
                                 2: 
                                 begin
                                    cpu_op <= CPU_OP_JMP;
                                    address_mode_prepare <= MODE_ABS;
                                 end
                                 3: 
                                 begin
                                    cpu_op <= CPU_OP_JMP;
                                    address_mode_prepare <= MODE_IND_ABS;
                                 end
                              endcase
                        endcase
                     4: 
                     case(bbb)
                        1,3,5: 
                        begin
                           cpu_op <= CPU_OP_STY;
                           do_load_store <= DO_STORE; 
                           reg_write <= reg_y;
                        end
                        2: 
                        begin
                           cpu_op <= CPU_OP_DEY;
                        end
                     endcase
                     5: 
                     case(bbb)
                        0,1,3,5,7: 
                        begin
                           cpu_op <= CPU_OP_LDY;
                           do_load_store <= DO_LOAD;
                        end
                        2: 
                        begin
                           cpu_op <= CPU_OP_TAY;
                           do_load_store <= DO_NOTHING;
                        end
                     endcase
                     6,7:
                     begin
                        case(bbb)
                           0,1,3:
                           begin
                              cpu_op <= aaa == 6 ? CPU_OP_CPY : CPU_OP_CPX;
                              do_load_store <= DO_LOAD;
                           end
                           2: cpu_op <= aaa == 6 ? CPU_OP_INY : CPU_OP_INX;
                        endcase
                     end 
                  endcase
               end
            2'b01:
            begin
               case (bbb)
                  0: address_mode_prepare <= MODE_IND_X;
                  1: address_mode_prepare <= MODE_Z;
                  2: address_mode_prepare <= MODE_IMM; // undetermined with STA
                  3: address_mode_prepare <= MODE_ABS;
                  4: address_mode_prepare <= MODE_IND_Y;
                  5: address_mode_prepare <= MODE_Z_X;
                  6: address_mode_prepare <= MODE_ABS_X;
                  7: address_mode_prepare <= MODE_ABS_Y;
               endcase
               if (aaa == 3'b100) begin // STA
                  cpu_op <= CPU_OP_STA;
                  do_load_store <= DO_STORE;
                  reg_write <= reg_a;
               end else begin
                  do_load_store <= DO_LOAD;
                  case (aaa)
                     3'b000: cpu_op <= CPU_OP_ORA;
                     3'b001: cpu_op <= CPU_OP_AND;
                     3'b010: cpu_op <= CPU_OP_EOR;
                     3'b011: cpu_op <= CPU_OP_ADC;
                     3'b101: cpu_op <= CPU_OP_LDA;
                     3'b110: cpu_op <= CPU_OP_CMP;
                     3'b111: cpu_op <= CPU_OP_SBC;
                  endcase
               end
            end
            2'b10:
            begin
               if (!aaa[2]) begin
                  do_load_store <= DO_LOAD;
                  case (bbb)
                     1: address_mode_prepare <= MODE_Z;
                     2: address_mode_prepare <= MODE_A;
                     3: address_mode_prepare <= MODE_ABS;
                     5: address_mode_prepare <= MODE_Z_X;
                     7: address_mode_prepare <= MODE_ABS_Y;
                  endcase
                  case (aaa[1:0])
                     2'b00: cpu_op <= CPU_OP_ASL;
                     2'b01: cpu_op <= CPU_OP_ROL;
                     2'b10: cpu_op <= CPU_OP_LSR;
                     2'b11: cpu_op <= CPU_OP_ROR;
                  endcase
               end else begin
                  case(bbb)
                     0: address_mode_prepare <= MODE_IMM; // undefined for a in 4,6,7
                     1: address_mode_prepare <= MODE_Z;
                     2: address_mode_prepare <= MODE_SINGLE;
                     3: address_mode_prepare <= MODE_ABS;
                     5: address_mode_prepare <= aaa[1] ? MODE_Z_X : MODE_Z_Y;
                     6: address_mode_prepare <= MODE_SINGLE; // undefined for a in 6,7
                     7: address_mode_prepare <= aaa[1] ? MODE_ABS_X : MODE_ABS_Y; // undefined for a = 4
                  endcase
                  case(aaa[1:0])
                     0:
                     begin
                        cpu_op <= CPU_OP_STX;
                        do_load_store <= bbb[0] ? DO_STORE : DO_NOTHING;
                        reg_write <= reg_x;
                        case(bbb)
                           3'b010 : cpu_op <= CPU_OP_TXA;
                           3'b110 : cpu_op <= CPU_OP_TXS;
                        endcase
                     end
                     1:
                     begin
                        cpu_op <= CPU_OP_LDX;
                        do_load_store <= bbb[0] ? DO_LOAD : DO_NOTHING;
                        case(bbb)
                           3'b010 : cpu_op <= CPU_OP_TAX;
                           3'b110 : cpu_op <= CPU_OP_TSX;
                        endcase
                     end
                     2:
                     case(bbb)
                        1,3,5,7:
                        begin
                           cpu_op <= CPU_OP_DEC;
                           do_load_store <= DO_LOAD;
                        end
                        2: cpu_op <= CPU_OP_DEX;
                     endcase
                     3:
                     case(bbb)
                        1,3,5,7:
                        begin
                           cpu_op <= CPU_OP_INC;
                           do_load_store <= DO_LOAD;
                        end
                        2:
                        begin
                           cpu_op <= CPU_OP_NOP;
                           cpu_inst_single <= 1;
                        end
                     endcase
               endcase
               end
            end
         endcase
      end else if (cpu_inst_done == 0 && cpu_fetch_state == CPU_EXECUTE_WAIT) begin
         if (wait_for_reset) begin
            if (load_complete) begin
               pc <= reg_word;
               cpu_inst_done <= 1;
               wait_for_reset <= 0;
            end
         end else if (load_store_complete) begin 
            cpu_inst_done <= 1;
            pc <= pc + pc_delta;
            case (cpu_op)
               CPU_OP_ORA,
               CPU_OP_AND,
               CPU_OP_EOR,
               CPU_OP_ADC,
               CPU_OP_LDA,
               CPU_OP_SBC,
               CPU_OP_ASL,
               CPU_OP_ROL,
               CPU_OP_LSR,
               CPU_OP_ROR,
               CPU_OP_TXA,
               CPU_OP_TYA:    reg_a <= alu_out;
               CPU_OP_LDX,
               CPU_OP_TAX,
               CPU_OP_INX,
               CPU_OP_DEX,
               CPU_OP_TSX:    reg_x <= alu_out;
               CPU_OP_LDY,
               CPU_OP_INY,
               CPU_OP_DEY,
               CPU_OP_TAY:    reg_y <= alu_out;
               CPU_OP_BRANCH: pc <= pc + 2 + (do_branch ? $signed(reg_m) : 0);
            endcase
            cpu_op <= CPU_OP_NOP;
         end
      end
   end
   
   always @ (negedge clk) begin : cpu_set_addr_mode
      address_mode <= MODE_IDLE;
      
      case(address_mode_prepare)
         MODE_RESET:
            address_mode <= MODE_RESET;
         MODE_IMM:
         begin
            address_mode <= MODE_IMM;
            pc_delta <= 2;
         end
         MODE_A:
         begin
            address_mode <= MODE_A;
            pc_delta <= 1;
         end
         MODE_Z, MODE_Z_X, MODE_Z_Y:
         begin
            address_mode <= MODE_Z;
            pc_delta <= 2;
         end
         MODE_IND_X, MODE_IND_Y:
         begin
            address_mode <= MODE_IND_Z;
            pc_delta <= 2;
         end
         MODE_ABS, MODE_ABS_X, MODE_ABS_Y:
         begin
            address_mode <= MODE_ABS;
            pc_delta <= 3;
         end
         MODE_IND_ABS:
         begin
            address_mode <= MODE_IND_ABS;
            pc_delta <= 3;
         end
         MODE_SINGLE:
         begin
            pc_delta <= 1;
            address_mode <= MODE_SINGLE;
         end
      endcase
      case (address_mode_prepare)
         MODE_Z, MODE_ABS:
            reg_ndx <= 0;
         MODE_Z_X, MODE_ABS_X:
            reg_ndx <= reg_x;
         MODE_Z_Y, MODE_ABS_Y:
            reg_ndx <= reg_y;
         MODE_IND_X:
         begin
            reg_ndx_pre  <= reg_x;
            reg_ndx_post <= 0;
         end
         MODE_IND_Y:
         begin
            reg_ndx_pre  <= 0;
            reg_ndx_post <= reg_y;
         end
      endcase
   end
   
   localparam DO_NOTHING  = 0;
   localparam DO_LOAD     = 1;
   localparam DO_STORE    = 2;
   
   reg[1:0] load_store    = DO_NOTHING;
   reg[1:0] do_load_store = DO_NOTHING;
   
   reg load_complete;
   reg store_complete;
   wire load_store_complete = load_complete | store_complete;
   
   always @ (negedge clk) begin : cpu_load_store
      store_complete <= 0;
      bus_rd_req <= 0;
      bus_wr_en  <= 0;
      if (load_store == DO_LOAD) begin
         bus_rd_req <= 1;
      end else if (load_store == DO_STORE | write_from_alu | write_push_value) begin
         bus_wr_data <= write_from_alu ? alu_out : (write_push_value ? push_value : reg_write);
         bus_wr_en   <= 1;
         store_complete <= 1;
      end
   end
   
   localparam MODE_IDLE     = 0;
   localparam MODE_RESET    = 1;
   localparam MODE_SINGLE   = 2;
   localparam MODE_A        = 3;
   localparam MODE_IMM      = 4;
   localparam MODE_Z        = 5;
   localparam MODE_Z_X      = 6;
   localparam MODE_Z_Y      = 7;
   localparam MODE_ABS      = 8;
   localparam MODE_ABS_X    = 9;
   localparam MODE_ABS_Y    = 10;
   localparam MODE_IND_Z    = 11;
   localparam MODE_IND_X    = 12;
   localparam MODE_IND_Y    = 13;
   localparam MODE_IND_ABS  = 14;
   
   localparam NEXT_IDLE     = 0;
   localparam NEXT_RESET1   = 1;
   localparam NEXT_RESET2   = 2;
   localparam NEXT_READ_M   = 3;
   localparam NEXT_Z        = 4;
   localparam NEXT_ABS1     = 5;
   localparam NEXT_ABS2     = 6;
   localparam NEXT_IND_ABS1 = 7;
   localparam NEXT_IND_ABS2 = 8;
   localparam NEXT_IND_ABS3 = 9;
   localparam NEXT_IND_Z1   = 10;
   localparam NEXT_IND_Z2   = 11;
   localparam NEXT_JSR1     = 12;
   localparam NEXT_JSR2     = 13;
   localparam NEXT_JSR3     = 14;

   reg[3:0] address_mode;
   reg[3:0] address_mode_prepare;

   localparam CPU_OP_NOP    = 0;
   localparam CPU_OP_LDA    = 1;
   localparam CPU_OP_LDX    = 2;
   localparam CPU_OP_LDY    = 3;
   localparam CPU_OP_STA    = 4;
   localparam CPU_OP_STX    = 5;
   localparam CPU_OP_STY    = 6;
   localparam CPU_OP_CMP    = 7;
   localparam CPU_OP_BRANCH = 8;
   localparam CPU_OP_ORA    = 9;
   localparam CPU_OP_AND    = 10;
   localparam CPU_OP_EOR    = 11;
   localparam CPU_OP_ADC    = 12;
   localparam CPU_OP_SBC    = 13;
   localparam CPU_OP_ASL    = 14;
   localparam CPU_OP_LSR    = 15;
   localparam CPU_OP_ROL    = 16;
   localparam CPU_OP_ROR    = 17;
   localparam CPU_OP_TXA    = 18;
   localparam CPU_OP_TYA    = 19;
   localparam CPU_OP_TAY    = 20;
   localparam CPU_OP_TAX    = 21;
   localparam CPU_OP_TXS    = 22;
   localparam CPU_OP_TSX    = 23;
   localparam CPU_OP_CLC    = 24;
   localparam CPU_OP_SEC    = 25;
   localparam CPU_OP_CLI    = 26;
   localparam CPU_OP_SEI    = 27;
   localparam CPU_OP_CLV    = 28;
   localparam CPU_OP_CLD    = 29;
   localparam CPU_OP_SED    = 30;
   localparam CPU_OP_DEX    = 31;
   localparam CPU_OP_DEY    = 32;
   localparam CPU_OP_INX    = 33;
   localparam CPU_OP_INY    = 34;
   localparam CPU_OP_CPX    = 35;
   localparam CPU_OP_CPY    = 36;
   localparam CPU_OP_DEC    = 37;
   localparam CPU_OP_INC    = 38;
   
   localparam CPU_OP_BRK    = 39;
   localparam CPU_OP_JSR    = 40;
   localparam CPU_OP_RTI    = 41;
   localparam CPU_OP_RTS    = 42;
   localparam CPU_OP_BIT    = 43;
   localparam CPU_OP_PHP    = 44;
   localparam CPU_OP_PLP    = 45;
   localparam CPU_OP_PHA    = 46;
   localparam CPU_OP_PLA    = 47;
   localparam CPU_OP_JMP    = 48;
   
   reg[15:0] jmp_addr;
   reg[7:0]  push_value;
   reg       write_push_value;
   reg[5:0]  cpu_op;
   reg       do_branch;

   always @ (posedge clk) begin : cpu_load_store_decode
      reg[3:0] next_addr_op;
      reg[7:0] tmp_addr;
      reg cpu_op_finish;
      reg use_a;
      reg alu_wait;
      reg[1:0] push_state;
      reg[5:0] push_op_back;
      reg[15:0] ret_addr;
      
      use_a <= 0;
      alu_proceed <= 0;
      alu_wait <= 0;
      write_from_alu <= 0;
      write_push_value <= 0;
      do_branch <= 0;
      
      flag_c_reset <= 0;
      flag_c_set   <= 0;
      flag_v_reset <= 0;
      flag_d_reset <= 0;
      flag_d_set   <= 0;
      
      load_store <= DO_NOTHING;
      if (!reset_n) begin
         reg_sp <= 8'hff;
         next_addr_op <= NEXT_IDLE;
      end else if (ready && !bus_rd_req) begin
         load_complete <= 0;
         cpu_op_finish <= 0;
         next_addr_op <= NEXT_IDLE;
         
         case(address_mode)
            MODE_SINGLE:
            begin
               cpu_op_finish <= 1;
               if (cpu_inst_single) load_complete <= 1;
            end
            MODE_A:      /* A */
            begin
               use_a <= 1;
               cpu_op_finish <= 1;
            end
            MODE_IMM:    /* IMM */
            begin
               bus_addr <= pc_op;
               load_store <= DO_LOAD;
               cpu_op_finish <= 1;
            end
            MODE_Z:
            begin
               bus_addr <= pc_op;
               load_store <= DO_LOAD;
               next_addr_op <= NEXT_Z;
            end
            MODE_ABS:  /* ABS */
            begin
               bus_addr <= pc_op;
               load_store <= DO_LOAD;
               next_addr_op <= NEXT_ABS1;
            end
            MODE_IND_ABS: // JMP (IND)
            begin
               tmp_addr <= rd_data;
               bus_addr <= pc_op + 1;
               load_store <= DO_LOAD;
               next_addr_op <= NEXT_IND_ABS1; 
            end
            MODE_IND_Z:
            begin
               bus_addr <= {8'd0, rd_data} + reg_ndx_pre;
               load_store <= DO_LOAD;
               next_addr_op <= NEXT_IND_Z1;
            end
            MODE_RESET:
            begin
               bus_addr <= 16'hFFFC;
               load_store <= DO_LOAD;
               next_addr_op <= NEXT_RESET1;
            end
         endcase
         
         case (cpu_op)
            CPU_OP_CLC : flag_c_reset <= 1;
            CPU_OP_SEC : flag_c_set   <= 1;
            CPU_OP_CLI : flag_i <= 0;
            CPU_OP_SEI : flag_i <= 1;
            CPU_OP_CLV : flag_v_reset <= 1;
            CPU_OP_CLD : flag_d_reset <= 1;
            CPU_OP_SED : flag_d_set   <= 1;
         endcase

         case (next_addr_op)
            NEXT_Z:
            begin
               bus_addr   <= {8'd0, rd_data} + reg_ndx;
               load_store <= do_load_store;
               cpu_op_finish <= 1;
            end
            NEXT_ABS1:
            begin
               tmp_addr <= rd_data;
               bus_addr <= pc_op + 1;
               load_store <= DO_LOAD;
               next_addr_op <= NEXT_ABS2;
            end
            NEXT_ABS2:
            if (cpu_op == CPU_OP_JSR) begin
               jmp_addr <= {rd_data, tmp_addr};
               ret_addr <= pc + 3;
               next_addr_op <= NEXT_JSR1;
            end else begin
               bus_addr   <= {rd_data, tmp_addr} + reg_ndx;
               load_store <= do_load_store;
               cpu_op_finish <= 1;
            end
            NEXT_IND_ABS1:
            begin
               bus_addr <= {rd_data, tmp_addr};
               load_store <= DO_LOAD;
               next_addr_op <= NEXT_IND_ABS2;
            end
            NEXT_IND_ABS2:
            begin
               tmp_addr <= rd_data;
               bus_addr <= bus_addr + 1;
               load_store <= DO_LOAD;
               next_addr_op <= NEXT_IND_ABS3;
            end
            NEXT_IND_ABS3:
            begin
               reg_word <= {rd_data, tmp_addr};
               load_complete <= 1;
            end
            NEXT_IND_Z1:
            begin
               tmp_addr <= rd_data;
               bus_addr <= bus_addr + 1;
               load_store <= DO_LOAD;
               next_addr_op <= NEXT_IND_Z2;
            end
            NEXT_IND_Z2:
            begin
               bus_addr <= {rd_data, tmp_addr} + reg_ndx_post;
               load_store <= do_load_store;
               cpu_op_finish <= 1;
            end
            NEXT_RESET1:
            begin
               tmp_addr <= rd_data;
               bus_addr <= bus_addr + 1;
               load_store <= DO_LOAD;
               next_addr_op <= NEXT_RESET2;
            end
            NEXT_RESET2:
            begin
               reg_word <= {rd_data, tmp_addr};
               load_complete <= 1;
            end
         endcase
         
         case (next_addr_op)
            NEXT_JSR1:
            begin
               push_value <= ret_addr[7:0];
               push_state <= 1;
               push_op_back <= NEXT_JSR2;
            end
            NEXT_JSR2:
            begin
               push_value <= ret_addr[15:8];
               push_state <= 1;
               push_op_back <= NEXT_JSR3;
            end
            NEXT_JSR3:
            begin
               load_complete <= 1;
            end
         endcase
         
         case (push_state)
            1 : 
            begin
               bus_addr <= {8'd1, reg_sp};
               reg_sp <= reg_sp - 1'b1;
               push_state <= 2;
               write_push_value <= 1;
            end
            2 :
            begin
               next_addr_op <= push_op_back;
               push_state <= 0;
            end
         endcase
         
         if (alu_proceed & !alu_wait) begin
            load_complete <= 1;
         end else if (cpu_op_finish || alu_wait) begin
            case(cpu_op)
               CPU_OP_AND,
               CPU_OP_ADC,
               CPU_OP_ORA,
               CPU_OP_CMP,
               CPU_OP_EOR:
               begin
                  alu_proceed <= 1;
                  alu_in_a <= reg_a;
                  alu_in_b <= rd_data;
               end
               CPU_OP_CPX:
               begin
                  alu_proceed <= 1;
                  alu_in_a <= reg_x;
                  alu_in_b <= rd_data;
               end
               CPU_OP_CPY:
               begin
                  alu_proceed <= 1;
                  alu_in_a <= reg_y;
                  alu_in_b <= rd_data;
               end
               CPU_OP_INX:
               begin
                  alu_proceed <= 1;
                  alu_in_a <= reg_x;
                  alu_op <= OP_INC;
               end
               CPU_OP_INY:
               begin
                  alu_proceed <= 1;
                  alu_in_a <= reg_y;
                  alu_op <= OP_INC;
               end
               CPU_OP_DEX:
               begin
                  alu_proceed <= 1;
                  alu_in_a <= reg_x;
                  alu_op <= OP_DEC;
               end
               CPU_OP_DEY:
               begin
                  alu_proceed <= 1;
                  alu_in_a <= reg_y;
                  alu_op <= OP_DEC;
               end
               CPU_OP_ASL,
               CPU_OP_LSR,
               CPU_OP_ROL,
               CPU_OP_ROR:
               begin
                  alu_proceed <= 1;
                  alu_in_a <= use_a ? reg_a : rd_data;
               end
            endcase
            
            case(cpu_op)
               CPU_OP_LDA,
               CPU_OP_LDX,
               CPU_OP_LDY:
               begin
                  alu_op <= OP_UPDATE;
                  alu_proceed <= 1;
                  alu_in_a <= rd_data;
               end
               CPU_OP_SBC:
               begin
                  alu_op <= OP_ADC;
                  alu_proceed <= 1;
                  alu_in_a <= reg_a;
                  alu_in_b <= 8'hff ^ rd_data;
               end
               CPU_OP_CPX,
               CPU_OP_CPY,
               CPU_OP_CMP: alu_op <= OP_CMP;
               CPU_OP_ASL: alu_op <= OP_ASL;
               CPU_OP_ROL: alu_op <= OP_ROL;
               CPU_OP_LSR: alu_op <= OP_LSR;
               CPU_OP_ROR: alu_op <= OP_ROR;
               CPU_OP_ORA: alu_op <= OP_OR;
               CPU_OP_AND: alu_op <= OP_AND;
               CPU_OP_EOR: alu_op <= OP_EOR;
               CPU_OP_ADC: alu_op <= OP_ADC;
               CPU_OP_BRANCH:
               begin
                  reg_m <= rd_data;
                  case(cpu_branch)
                     3'b000 : do_branch <= !flag_n; // BPL
                     3'b001 : do_branch <=  flag_n; // BMI
                     3'b010 : do_branch <= !flag_v; // BVC
                     3'b011 : do_branch <=  flag_v; // BVS
                     3'b100 : do_branch <= !flag_c; // BCC
                     3'b101 : do_branch <=  flag_c; // BCS
                     3'b110 : do_branch <= !flag_z; // BNE
                     3'b111 : do_branch <=  flag_z; // BEQ
                  endcase
                  load_complete <= 1;
               end
            endcase
            
            case(cpu_op)
               CPU_OP_TXA,
               CPU_OP_TYA,
               CPU_OP_TAX,
               CPU_OP_TAY,
               CPU_OP_TSX:
               begin
                  alu_op <= OP_UPDATE;
                  alu_proceed <= 1;
               end
            endcase

            case(cpu_op)
               CPU_OP_TYA: alu_in_a <= reg_y; 
               CPU_OP_TXA: alu_in_a <= reg_x;
               CPU_OP_TAY,
               CPU_OP_TAX: alu_in_a <= reg_a;
               CPU_OP_TSX: alu_in_a <= reg_sp;
               CPU_OP_TXS: begin
                  reg_sp <= reg_x;
                  load_complete <= 1;
               end
            endcase

            case(cpu_op)
               CPU_OP_DEC:
               begin
                  if (!alu_wait) begin
                     alu_op <= OP_DEC;
                     alu_in_a <= rd_data;
                     alu_proceed <= 1;
                     alu_wait <= 1;
                  end else begin
                     write_from_alu <= 1;
                  end
               end
               CPU_OP_INC:
               begin
                  if (!alu_wait) begin
                     alu_op <= OP_INC;
                     alu_in_a <= rd_data;
                     alu_proceed <= 1;
                     alu_wait <= 1;
                  end else begin
                     write_from_alu <= 1;
                  end
               end
            endcase
         end   
      end
   end
   
   reg[15:0] bus_addr;
   reg bus_rd_req;
   reg bus_wr_en;

   assign wr_en  = bus_wr_en;
   assign rd_req = fetch_rd_req | bus_rd_req;
   assign addr   = hold_fetch_addr ? fetch_rd_addr : bus_addr;

   reg[15:0] fetch_rd_addr;
   reg       fetch_rd_req;

   reg[7:0] bus_wr_data;
   assign wr_data = bus_wr_data;
   
   reg alu_proceed;
   reg[3:0]  alu_op;
   reg[7:0]  alu_in_a;
   reg[7:0]  alu_in_b;
   wire[7:0] alu_out;
   
   reg write_from_alu;
   
   wire flag_c;
   wire flag_z;
   wire flag_v;
   wire flag_n;
   wire flag_d;
   reg  flag_c_set;
   reg  flag_c_reset;
   reg  flag_d_set;
   reg  flag_d_reset;
   reg  flag_v_reset;
   
   m6502_alu alu (
         .clk(clk),
         .reset_n(reset_n),
         .proceed(alu_proceed),
         .op(alu_op),
         .in_a(alu_in_a),
         .in_b(alu_in_b),
         .flag_c_set(flag_c_set),
         .flag_c_reset(flag_c_reset),
         .flag_d_set(flag_d_set),
         .flag_d_reset(flag_d_reset),
         .flag_v_reset(flag_v_reset),
         .out(alu_out),
         .flag_c(flag_c),
         .flag_z(flag_z),
         .flag_v(flag_v),
         .flag_n(flag_n),
         .flag_d(flag_d)
      );
endmodule
