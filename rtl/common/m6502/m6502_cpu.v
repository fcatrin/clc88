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

   localparam CPU_WAIT         = 0;
   localparam CPU_FETCH        = 1;
   localparam CPU_EXECUTE      = 2;
   localparam CPU_EXECUTE_WAIT = 3;
   localparam CPU_RESET        = 4;
   
   reg[2:0] cpu_fetch_state = CPU_WAIT;
   reg cpu_reset;
   reg cpu_inst_done;
   reg cpu_inst_state;
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
      if (~reset_n) begin
         wait_for_reset <= 0;
      end else if (cpu_fetch_state == CPU_EXECUTE) begin
         address_mode_prepare <= MODE_IDLE;
         cpu_inst_done <= 0;
         cpu_op <= CPU_OP_NOP;
         if (cpu_reset) begin
            reg_a <= 0;
            reg_x <= 0;
            reg_y <= 0;
            reg_sp <= 8'hff;
            address_mode_prepare <= MODE_RESET;
            wait_for_reset <= 1;
         end else case (reg_i[1:0])  // format aaabbbcc. Check cc first
            2'b01:
            begin
               case (reg_i[4:2])
                  0: address_mode_prepare <= MODE_IND_X;
                  1: address_mode_prepare <= MODE_Z;
                  2: address_mode_prepare <= MODE_IMM; // undetermined with STA
                  3: address_mode_prepare <= MODE_ABS;
                  4: address_mode_prepare <= MODE_IND_Y;
                  5: address_mode_prepare <= MODE_Z_X;
                  6: address_mode_prepare <= MODE_ABS_X;
                  7: address_mode_prepare <= MODE_ABS_Y;
               endcase
               if (reg_i[7:5] == 6'b100) begin // STA
                  do_load_store <= DO_STORE;
                  reg_write <= reg_a;
               end else begin
                  do_load_store <= DO_LOAD;
                  case (reg_i[7:5])
                     6'b000: cpu_op <= CPU_OP_ORA;
                     6'b001: cpu_op <= CPU_OP_AND;
                     6'b010: cpu_op <= CPU_OP_EOR;
                     6'b011: cpu_op <= CPU_OP_ADC;
                     6'b101: cpu_op <= CPU_OP_LD;
                     6'b110: cpu_op <= CPU_OP_CMP;
                     6'b111: cpu_op <= CPU_OP_SBC;
                  endcase
               end
            end
            2'b00:
            casex (reg_i[7:2])
               6'bxxx100: /* BRANCH */
               begin
                  cpu_op <= CPU_OP_BRANCH;
                  cpu_branch <= reg_i[7:5];
                  address_mode_prepare <= MODE_IMM;
               end
            endcase
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
            casex (reg_i)
               8'b000xxx01, /* ORA */
               8'b001xxx01, /* AND */
               8'b010xxx01, /* EOR */
               8'b011xxx01, /* ADC */
               8'b101xxx01, /* LDA */
               8'b111xxx01: /* SBC */
               begin
                  reg_a <= alu_out;
                  pc <= pc + pc_delta;
               end
               8'b100xxx01, /* STA */
               8'b110xxx01: /* CMP */
                  pc <= pc + pc_delta;
               8'bxxx10000: /* BRANCH */
               begin
                  pc <= pc + 2 + (do_branch ? $signed(reg_m) : 0);
               end
            endcase
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
            pc_delta <= 1;
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
      end else if (load_store == DO_STORE) begin
         bus_wr_data <= reg_write;
         bus_wr_en   <= 1;
         store_complete <= 1;
      end
   end
   
   localparam MODE_IDLE     = 0;
   localparam MODE_RESET    = 1;
   localparam MODE_SINGLE   = 2;
   localparam MODE_IMM      = 3;
   localparam MODE_Z        = 4;
   localparam MODE_Z_X      = 5;
   localparam MODE_Z_Y      = 6;
   localparam MODE_ABS      = 7;
   localparam MODE_ABS_X    = 8;
   localparam MODE_ABS_Y    = 9;
   localparam MODE_IND_Z    = 10;
   localparam MODE_IND_X    = 11;
   localparam MODE_IND_Y    = 12;
   localparam MODE_IND_ABS  = 13;
   
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

   reg[3:0] address_mode;
   reg[3:0] address_mode_prepare;

   localparam CPU_OP_NOP    = 0;
   localparam CPU_OP_LD     = 1;
   localparam CPU_OP_CMP    = 2;
   localparam CPU_OP_BRANCH = 3;
   localparam CPU_OP_ORA    = 4;
   localparam CPU_OP_AND    = 5;
   localparam CPU_OP_EOR    = 6;
   localparam CPU_OP_ADC    = 7;
   localparam CPU_OP_SBC    = 8;
   
   reg[3:0] cpu_op;
   reg do_branch;

   always @ (posedge clk) begin : cpu_load_store_decode
      reg[3:0] next_addr_op;
      reg[7:0] tmp_addr;
      reg cpu_op_finish;
      
      alu_proceed <= 0;
      do_branch <= 0;
      load_store <= DO_NOTHING;
      if (!reset_n) begin
         next_addr_op <= NEXT_IDLE;
      end else if (ready && !bus_rd_req) begin
         load_complete <= 0;
         cpu_op_finish <= 0;
         next_addr_op <= NEXT_IDLE;
         
         case(address_mode)
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
            begin
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
         if (alu_proceed) begin
            load_complete <= 1;
         end else if (cpu_op_finish) begin
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
            endcase
               
            case(cpu_op)
               CPU_OP_LD:
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
               CPU_OP_CMP: alu_op <= OP_CMP;
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
   wire flag_c;
   wire flag_z;
   wire flag_v;
   wire flag_n;
   reg  flag_c_set;
   reg  flag_c_reset;
   
   m6502_alu alu (
         .clk(clk),
         .reset_n(reset_n),
         .proceed(alu_proceed),
         .op(alu_op),
         .in_a(alu_in_a),
         .in_b(alu_in_b),
         .flag_c_set(flag_c_set),
         .flag_c_reset(flag_c_reset),
         .out(alu_out),
         .flag_c(flag_c),
         .flag_z(flag_z),
         .flag_v(flag_v),
         .flag_n(flag_n)
      );
endmodule
