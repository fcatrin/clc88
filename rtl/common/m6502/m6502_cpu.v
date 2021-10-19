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
      output reg [15:0] bus_addr,
      input       [7:0] bus_rd_data,
      output reg  [7:0] bus_wr_data,
      output reg bus_wr_en,
      output reg bus_rd_req,
      input  irq_n,
      input  nmi_n,
      input  ready
      );

   `include "m6502_alu_ops.vh"
   
   localparam NMI_VECTOR = 16'hfffa;
   localparam RST_VECTOR = 16'hfffc;
   localparam IRQ_VECTOR = 16'hfffe;
   
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
   
   wire[2:0] aaa = reg_i[7:5];
   wire[2:0] bbb = reg_i[4:2];
   wire[2:0] cc  = reg_i[1:0];

   wire flag_n;
   wire flag_v;
   wire flag_d;
   reg  flag_i;
   wire flag_z;
   wire flag_c;
   
   wire[7:0] reg_sr = {flag_n, flag_v, 1'b0, 1'b0, flag_d, flag_i, flag_z, flag_c}; 

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
   
   reg pending_irq;
   reg pending_irq_ack;
   reg pending_nmi;
   reg pending_nmi_ack;
   reg cpu_irq;
   reg cpu_nmi;
   
   always @ (posedge clk) begin : cpu_interrupts
      reg irq_n_prev;
      reg nmi_n_prev;
      
      if (~reset_n) begin
         irq_n_prev = 1'b1;
         nmi_n_prev = 1'b1;
      end else begin
         irq_n_prev <= irq_n;
         nmi_n_prev <= nmi_n;
         if (pending_irq_ack) begin
            pending_irq <= 0;
         end else if (irq_n_prev & ~irq_n) begin
            pending_irq <= 1;
         end
         if (pending_nmi_ack) begin
            pending_nmi <= 0;
         end else if (nmi_n_prev & ~nmi_n) begin
            pending_nmi <= 1;
         end
      end
   end
   
   always @ (posedge clk) begin : cpu_fetch
      cpu_reset <= 0;
      fetch_rd_req <= 0;
      hold_fetch_addr <= 0;
      pending_irq_ack <= 0;
      pending_nmi_ack <= 0;
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
               if (ready & !pending_rd_req) begin
                  reg_i <= bus_rd_data;
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
                  cpu_irq <= 0;
                  cpu_nmi <= 0;
                  if (pending_nmi) begin
                     cpu_nmi <= 1;
                     cpu_fetch_state <= CPU_EXECUTE;
                     pending_nmi_ack <= 1;
                  end else if (pending_irq & !flag_i) begin
                     cpu_irq <= 1;
                     cpu_fetch_state <= CPU_EXECUTE;
                     pending_irq_ack <= 1;
                  end else begin
                     fetch_rd_addr <= pc;
                     fetch_rd_req  <= 1;
                     pc_op <= pc + 1;
                     cpu_fetch_state <= CPU_FETCH;
                     hold_fetch_addr <= 1;
                  end
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
            cpu_op <= CPU_OP_NOP;
            address_mode_prepare <= MODE_RESET;
            wait_for_reset <= 1;
         end else if (cpu_irq | cpu_nmi) begin
            cpu_op <= CPU_OP_BRK;
            address_mode_prepare <= MODE_BRK;
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
                                 0: 
                                 begin
                                    cpu_op <= CPU_OP_BRK;
                                    address_mode_prepare <= MODE_BRK;
                                 end
                                 1: 
                                 begin
                                    cpu_op <= CPU_OP_JSR;
                                    address_mode_prepare <= MODE_ABS;
                                 end
                                 2: cpu_op <= CPU_OP_RTI;
                                 3: cpu_op <= CPU_OP_RTS;
                              endcase
                           1: if (aaa == 1) begin
                                 cpu_op <= CPU_OP_BIT;
                                 address_mode_prepare <= MODE_Z;
                                 do_load_store <= DO_LOAD;
                              end
                           2: case(aaa)
                                 0: cpu_op <= CPU_OP_PHP;
                                 1: cpu_op <= CPU_OP_PLP;
                                 2: cpu_op <= CPU_OP_PHA;
                                 3: cpu_op <= CPU_OP_PLA;
                              endcase
                           3: case(aaa)
                                 1:
                                 begin
                                    cpu_op <= CPU_OP_BIT;
                                    address_mode_prepare <= MODE_ABS;
                                    do_load_store <= DO_LOAD;
                                 end
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
                  6: address_mode_prepare <= MODE_ABS_Y;
                  7: address_mode_prepare <= MODE_ABS_X;
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
            if (load_store_complete) begin
               pc <= jmp_addr;
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
               CPU_OP_PLA,
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
               CPU_OP_BRK,
               CPU_OP_JMP,
               CPU_OP_JSR,
               CPU_OP_RTS,
               CPU_OP_RTI:    pc <= jmp_addr;
            endcase
            cpu_op <= CPU_OP_NOP;
         end
      end
   end
   
   reg cpu_op_finish_a;
   reg cpu_op_finish_b;
   wire cpu_op_finish = cpu_op_finish_a | cpu_op_finish_b;

   reg use_a;

   always @ (posedge clk) begin : cpu_set_addr_mode

      op_rd_req       <= 0;

      if (cpu_exec) begin
         address_mode <= MODE_IDLE;
         use_a <= 0;
         cpu_op_finish_a <= 0;
         case(address_mode_prepare)
            MODE_A:      /* A */
            begin
               use_a <= 1;
               pc_delta <= 1;
               cpu_op_finish_a <= 1;
            end
            MODE_IMM:
            begin
               pc_delta <= 2;
               cpu_op_finish_a <= 1;
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
               cpu_op_finish_a <= 1;
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
         case (address_mode_prepare) // tod group these cases
            MODE_IMM,
            MODE_Z, MODE_Z_X, MODE_Z_Y,
            MODE_IND_X, MODE_IND_Y,
            MODE_ABS, MODE_ABS_X, MODE_ABS_Y,
            MODE_IND_ABS:
            begin
               op_addr   <= pc_op;
               op_rd_req <= 1;
            end
            MODE_RESET:
            begin
               op_addr   <= RST_VECTOR;
               op_rd_req <= 1;
            end
            MODE_BRK:
            begin
               op_addr   <= cpu_nmi ? NMI_VECTOR : IRQ_VECTOR;
               op_rd_req <= 1;
            end
         endcase
      end
   end
   
   localparam INT_IDLE       = 0;
   localparam INT_GET_VECTOR = 1;
   localparam INT_PUSH_ADDRH = 2;
   localparam INT_PUSH_ADDRL = 3;
   localparam INT_PUSH_SR    = 4;
   
   localparam JSR_IDLE       = 0;
   localparam JSR_PUSH_ADDRH = 1;
   localparam JSR_PUSH_ADDRL = 2;
   
   localparam STACK_IDLE = 0;
   localparam STACK_RTS1 = 1;
   localparam STACK_RTS2 = 2;
   localparam STACK_RTI  = 3;
   localparam STACK_PLA  = 4;
   localparam STACK_PLP  = 5;
   
   localparam RESET_IDLE       = 0;
   localparam RESET_GET_VECTOR = 1;
   localparam RESET_FINISH     = 2;
   
   always @ (posedge clk) begin : exec_misc_ops
      reg[15:0] ret_addr;

      reg[2:0] int_state;
      reg[2:0] jsr_state;
      reg[2:0] int_state_next;
      reg[2:0] jsr_state_next;
      reg[2:0] stack_state_next;
      reg[2:0] reset_state;

      flag_n_set <= ALU_FLAG_KEEP;
      flag_v_set <= ALU_FLAG_KEEP;
      flag_d_set <= ALU_FLAG_KEEP;
      flag_z_set <= ALU_FLAG_KEEP;
      flag_c_set <= ALU_FLAG_KEEP;

      stack_do_pop       <= 0;
      stack_do_push      <= 0;
      stack_do_push_back <= 0;
      reg_sp_update      <= 0;
      
      misc_ops_complete  <= 0;
      misc_rd_req <= 0;

      if (~reset_n) begin
         int_state <= INT_IDLE;
         jsr_state <= JSR_IDLE;
         stack_state <= STACK_IDLE;
         int_state_next <= INT_IDLE;
         jsr_state_next <= JSR_IDLE;
         stack_state_next <= STACK_IDLE;
         reset_state <= RESET_IDLE;
      end else if (cpu_exec) begin
         
         int_state <= INT_IDLE;
         jsr_state <= JSR_IDLE;
         stack_state <= STACK_IDLE;
         
         if (address_mode_prepare == MODE_SINGLE) begin
            if (cpu_op == CPU_OP_RTS) begin // TODO convert to case
               stack_do_pop  <= 1;
               stack_state_next <= STACK_RTS1;
            end else if (cpu_op == CPU_OP_RTI) begin
               stack_do_pop  <= 1;
               stack_state_next <= STACK_RTI;
            end else if (cpu_op == CPU_OP_PHA) begin
               stack_do_push  <= 1;
               stack_wr_value <= reg_a;
            end else if (cpu_op == CPU_OP_PLA) begin
               stack_do_pop  <= 1;
               stack_state_next <= STACK_PLA;
            end else if (cpu_op == CPU_OP_PHP) begin
               stack_do_push  <= 1;
               stack_wr_value <= reg_sr | 8'b00010000; // BREAK flag is always 1 on PHP and BRK
            end else if (cpu_op == CPU_OP_PLP) begin
               stack_do_pop  <= 1;
               stack_state_next <= STACK_PLP;
            end else if (cpu_op == CPU_OP_TXS) begin
               reg_sp_next   <= reg_x;
               reg_sp_update <= 1;
               misc_ops_complete <= 1;
            end else begin
               if (cpu_inst_single) misc_ops_complete <= 1;
            end
         end else if (address_mode_prepare == MODE_RESET) begin
            reset_state <= RESET_GET_VECTOR;
         end else if (address_mode_prepare == MODE_BRK) begin
            ret_addr  <= pc + ((cpu_irq | cpu_nmi) ? 0 : 2);
            int_state <= INT_GET_VECTOR;
         end
         
         case (int_state)
            INT_GET_VECTOR:
            begin
               jmp_addr[7:0] <= bus_rd_data;
               misc_addr <= (cpu_nmi ? NMI_VECTOR : IRQ_VECTOR) + 1;
               misc_rd_req <= 1;
               int_state <= INT_PUSH_ADDRH;
            end
            INT_PUSH_ADDRH:
            begin
               jmp_addr[15:8] <= bus_rd_data;
               stack_do_push_back <= 1;
               stack_wr_value     <= ret_addr[15:8];
               int_state_next     <= INT_PUSH_ADDRL;
            end
            INT_PUSH_ADDRL:
            begin
               stack_do_push_back <= 1;
               stack_wr_value <= ret_addr[7:0];
               int_state_next  <= INT_PUSH_SR;
            end
            INT_PUSH_SR:
            begin
               flag_d_set  <= ALU_FLAG_RESET;
               flag_i <= 1;
               stack_wr_value <= reg_sr | ((cpu_irq | cpu_nmi) ? 0 : 8'b00010000);
               stack_do_push  <= 1;
            end
         endcase
         
         if (cpu_op == CPU_OP_JSR || cpu_op == CPU_OP_JMP) begin
            if (next_addr_op == NEXT_ABS) begin
               jmp_addr <= {bus_rd_data, tmp_addr};
               if (cpu_op == CPU_OP_JSR) begin
                  ret_addr <= pc + 3;
                  jsr_state <= JSR_PUSH_ADDRH;
               end else begin
                  misc_ops_complete <= 1;
               end
            end

            if (next_addr_op == NEXT_IND_ABS_DONE) begin // TODO unify with jump above
               jmp_addr <= {bus_rd_data, tmp_addr};
               misc_ops_complete <= 1;
            end
            
            case(jsr_state)
               JSR_PUSH_ADDRH:
               begin
                  stack_wr_value <= ret_addr[15:8];
                  stack_do_push_back  <= 1;
                  jsr_state_next <= JSR_PUSH_ADDRL;
               end
               JSR_PUSH_ADDRL:
               begin
                  stack_wr_value <= ret_addr[7:0];
                  stack_do_push  <= 1;
               end
            endcase
         end
         
         case (stack_state)
            STACK_RTS1:
            begin
               jmp_addr[7:0] <= stack_rd_value;
               stack_do_pop  <=1;
               stack_state_next <= STACK_RTS2;
            end
            STACK_RTS2:
            begin
               jmp_addr[15:8] <= stack_rd_value;
               misc_ops_complete <= 1;
            end
            STACK_RTI, STACK_PLP:
            begin
               flag_n_set   <=  {1'b1, stack_rd_value[7]};
               flag_v_set   <=  {1'b1, stack_rd_value[6]};
               flag_d_set   <=  {1'b1, stack_rd_value[3]};
               flag_i       <=  stack_rd_value[2];
               flag_z_set   <=  {1'b1, stack_rd_value[1]};
               flag_c_set   <=  {1'b1, stack_rd_value[0]};
               if (stack_state == STACK_RTI) begin
                  stack_do_pop <= 1;
                  stack_state_next <= STACK_RTS1;
               end else begin
                  misc_ops_complete <= 1;
               end
            end
         endcase
         
         case (reset_state)
            RESET_GET_VECTOR:
            begin
               jmp_addr[7:0] <= bus_rd_data;
               misc_addr <= RST_VECTOR + 1;
               misc_rd_req <= 1;
               reset_state <= RESET_FINISH;
            end
            RESET_FINISH:
            begin
               jmp_addr[15:8] <= bus_rd_data;
               misc_ops_complete <= 1;
               reset_state <= RESET_IDLE;
            end
         endcase
         
         case (cpu_op)
            CPU_OP_CLC : flag_c_set <= ALU_FLAG_RESET;
            CPU_OP_SEC : flag_c_set <= ALU_FLAG_SET;
            CPU_OP_CLD : flag_d_set <= ALU_FLAG_RESET;
            CPU_OP_SED : flag_d_set <= ALU_FLAG_SET;
            CPU_OP_CLI : flag_i <= 0;
            CPU_OP_SEI : flag_i <= 1;
            CPU_OP_CLV : flag_v_set <= ALU_FLAG_RESET;
         endcase

         if (stack_op_done) begin
            jsr_state   <= jsr_state_next;
            int_state   <= int_state_next;
            stack_state <= stack_state_next;
            
            int_state_next   <= INT_IDLE;
            jsr_state_next   <= JSR_IDLE;
            stack_state_next <= STACK_IDLE;
         end
      end
   end
   
   localparam DO_NOTHING  = 0;
   localparam DO_LOAD     = 1;
   localparam DO_STORE    = 2;
   
   reg[1:0] load_store    = DO_NOTHING;
   reg[1:0] do_load_store = DO_NOTHING;
   
   reg load_complete;
   reg store_complete;
   reg misc_ops_complete;
   wire load_store_complete = load_complete | store_complete | misc_ops_complete;
   
   always @ (negedge clk) begin : bus_access
      bus_rd_req <= fetch_rd_req | misc_rd_req | op_rd_req | stack_rd_req | load_store == DO_LOAD; 
      bus_wr_en  <= stack_wr_req | write_from_alu | load_store == DO_STORE;
      store_complete <= (stack_wr_req & stack_finish_on_push) | write_from_alu | load_store == DO_STORE;
      if (hold_fetch_addr) begin
         bus_addr   <= fetch_rd_addr;
      end else if (misc_rd_req) begin
         bus_addr   <= misc_addr;
      end else if (op_rd_req) begin
         bus_addr   <= op_addr;
      end else if (load_store == DO_LOAD) begin
         bus_addr   <= data_addr; 
      end else if (stack_rd_req | stack_wr_req) begin
         bus_addr <= {8'd1, stack_addr};
         bus_wr_data <= stack_wr_value;
      end else if (load_store == DO_STORE) begin
         bus_addr    <= data_addr;
         bus_wr_data <= reg_write;
      end else if (write_from_alu) begin
         bus_addr    <= data_addr;
         bus_wr_data <= alu_out;
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
   localparam MODE_BRK      = 15;
   
   localparam NEXT_IDLE     = 0;
   localparam NEXT_RESET1   = 1;
   localparam NEXT_RESET2   = 2;
   localparam NEXT_READ_M   = 3;
   localparam NEXT_ABS      = 4;
   localparam NEXT_IND_ABS1 = 5;
   localparam NEXT_IND_ABS2 = 6;
   localparam NEXT_IND_ABS_DONE = 7;
   localparam NEXT_IND_Z1   = 8;
   localparam NEXT_IND_Z2   = 9;

   reg[4:0] address_mode;
   reg[4:0] address_mode_prepare;

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
   
   // todo check if rd_req can be moved to negedge 
   wire pending_rd_req = bus_rd_req | fetch_rd_req | misc_rd_req | op_rd_req | stack_rd_req;
   wire cpu_exec = ready && !pending_rd_req && cpu_fetch_state == CPU_EXECUTE_WAIT;
   
   reg[15:0] jmp_addr;
   reg[7:0]  tmp_addr;
   reg[2:0]  stack_state;
   reg[7:0]  stack_rd_value;
   reg[7:0]  stack_wr_value;
   reg[5:0]  cpu_op;
   reg[4:0]  next_addr_op;
   reg       do_branch;

   always @ (posedge clk) begin : cpu_load_store_decode
      reg alu_wait;
      reg[1:0] push_state;
      reg[1:0] pop_state;
      
      alu_proceed <= 0;
      alu_wait <= 0;
      write_from_alu <= 0;
      do_branch <= 0;
      
      load_store <= DO_NOTHING;
      if (!reset_n) begin
         pop_state <= 0;
         push_state <= 0;
         next_addr_op <= NEXT_IDLE;
         load_complete <= 0;
      end else if (cpu_exec) begin
         load_complete <= 0;
         cpu_op_finish_b <= 0;
         next_addr_op <= NEXT_IDLE;
         
         case(address_mode)
            MODE_Z:
            begin
               data_addr   <= {8'd0, bus_rd_data} + reg_ndx;
               load_store  <= do_load_store;
               cpu_op_finish_b <= 1;
            end
            MODE_ABS:  /* ABS */
            begin
               tmp_addr     <= bus_rd_data;
               data_addr    <= pc_op + 1;
               load_store   <= DO_LOAD;
               next_addr_op <= NEXT_ABS;
            end
            MODE_IND_ABS: // JMP (IND)
            begin
               tmp_addr     <= bus_rd_data;
               data_addr    <= pc_op + 1;
               load_store   <= DO_LOAD;
               next_addr_op <= NEXT_IND_ABS1;
            end
            MODE_IND_Z:
            begin
               data_addr <= {8'd0, bus_rd_data} + reg_ndx_pre;
               load_store <= DO_LOAD;
               next_addr_op <= NEXT_IND_Z1;
            end
         endcase
         

         case (next_addr_op)
            NEXT_ABS:
            // this state is also used for JSR/JMP in exec_misc_ops
            if (do_load_store != DO_NOTHING) begin
               data_addr   <= {bus_rd_data, tmp_addr} + reg_ndx;
               load_store  <= do_load_store;
               cpu_op_finish_b <= 1;
            end
            NEXT_IND_ABS1:
            begin
               data_addr <= {bus_rd_data, tmp_addr};
               load_store <= DO_LOAD;
               next_addr_op <= NEXT_IND_ABS2;
            end
            NEXT_IND_ABS2:
            begin
               tmp_addr <= bus_rd_data;
               data_addr <= data_addr + 1;
               load_store <= DO_LOAD;
               next_addr_op <= NEXT_IND_ABS_DONE;
            end
            NEXT_IND_Z1:
            begin
               tmp_addr <= bus_rd_data;
               data_addr <= data_addr + 1;
               load_store <= DO_LOAD;
               next_addr_op <= NEXT_IND_Z2;
            end
            NEXT_IND_Z2:
            begin
               data_addr <= {bus_rd_data, tmp_addr} + reg_ndx_post;
               load_store <= do_load_store;
               cpu_op_finish_b <= 1;
            end
         endcase
         
         if (stack_state == STACK_PLA) begin
            alu_in_a <= stack_rd_value;
            alu_proceed <= 1;
         end
         
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
                  alu_in_b <= bus_rd_data;
               end
               CPU_OP_CPX:
               begin
                  alu_proceed <= 1;
                  alu_in_a <= reg_x;
                  alu_in_b <= bus_rd_data;
               end
               CPU_OP_CPY:
               begin
                  alu_proceed <= 1;
                  alu_in_a <= reg_y;
                  alu_in_b <= bus_rd_data;
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
               if (use_a) begin
                  alu_proceed <= 1;
                  alu_in_a <= reg_a;
               end else begin
                  if (!alu_wait) begin
                     alu_in_a <= bus_rd_data;
                     alu_proceed <= 1;
                     alu_wait <= 1;
                  end else begin
                     write_from_alu <= 1;
                  end
               end
               CPU_OP_BIT:
               begin
                  alu_in_a <= bus_rd_data;
                  alu_in_b <= reg_a;
                  alu_op   <= OP_BIT;
                  alu_proceed <= 1;
               end
            endcase
            
            case(cpu_op)
               CPU_OP_LDA,
               CPU_OP_LDX,
               CPU_OP_LDY:
               begin
                  alu_op <= OP_UPDATE;
                  alu_proceed <= 1;
                  alu_in_a <= bus_rd_data;
               end
               CPU_OP_SBC:
               begin
                  alu_op <= OP_ADC;
                  alu_proceed <= 1;
                  alu_in_a <= reg_a;
                  alu_in_b <= 8'hff ^ bus_rd_data;
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
                  reg_m <= bus_rd_data;
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
            endcase

            case(cpu_op)
               CPU_OP_DEC:
               begin
                  if (!alu_wait) begin
                     alu_op <= OP_DEC;
                     alu_in_a <= bus_rd_data;
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
                     alu_in_a <= bus_rd_data;
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
   
   reg[15:0] misc_addr;
   reg       misc_rd_req;
   reg[15:0] op_addr;
   reg       op_rd_req;
   
   reg stack_do_pop;
   reg stack_do_push;
   reg stack_do_push_back;
   reg stack_op_done;
   reg stack_rd_req;
   reg stack_wr_req;
   reg stack_finish_on_push;
   reg[7:0] stack_addr;
   reg[7:0] reg_sp_next;
   reg      reg_sp_update;
   
   always @ (posedge clk) begin : stack_ops
      reg pop_wait;
      reg push_wait;

      stack_op_done <= 0;
      stack_rd_req  <= 0;
      stack_wr_req  <= 0;
      
      if (!reset_n) begin
         pop_wait  <= 0;
         push_wait <= 0;
         reg_sp    <= 8'hff;
      end else if (cpu_exec) begin
         pop_wait  <= 0;
         push_wait <= 0;
         if (pop_wait) begin
            stack_rd_value <= bus_rd_data;
            stack_op_done  <= 1;
         end else if (stack_do_pop) begin
            stack_rd_req <= 1;
            stack_addr   <= reg_sp + 1'b1;
            reg_sp       <= reg_sp + 1'b1;
            pop_wait     <= 1;
         end 
         if (push_wait) begin
            stack_op_done <= 1;
         end else if (stack_do_push | stack_do_push_back) begin
            stack_wr_req <= 1;
            stack_addr   <= reg_sp;
            reg_sp       <= reg_sp - 1'b1;
            push_wait    <= 1;
            stack_finish_on_push <= stack_do_push;
         end 
         if (reg_sp_update) begin
            reg_sp <= reg_sp_next;
         end
      end
   end
   
   reg[15:0] data_addr;
   reg[15:0] fetch_rd_addr;
   reg       fetch_rd_req;
   
   reg alu_proceed;
   reg[3:0]  alu_op;
   reg[7:0]  alu_in_a;
   reg[7:0]  alu_in_b;
   wire[7:0] alu_out;
   
   reg write_from_alu;
   
   localparam ALU_FLAG_KEEP  = 2'b00;
   localparam ALU_FLAG_RESET = 2'b10;
   localparam ALU_FLAG_SET   = 2'b11;
   
   reg[1:0] flag_n_set;
   reg[1:0] flag_v_set;
   reg[1:0] flag_d_set;
   reg[1:0] flag_z_set;
   reg[1:0] flag_c_set;
   
   m6502_alu alu (
         .clk(clk),
         .reset_n(reset_n),
         .proceed(alu_proceed),
         .op(alu_op),
         .in_a(alu_in_a),
         .in_b(alu_in_b),
         .flag_n_set(flag_n_set),
         .flag_v_set(flag_v_set),
         .flag_d_set(flag_d_set),
         .flag_z_set(flag_z_set),
         .flag_c_set(flag_c_set),
         .out(alu_out),
         .flag_c(flag_c),
         .flag_z(flag_z),
         .flag_v(flag_v),
         .flag_n(flag_n),
         .flag_d(flag_d)
      );
endmodule
