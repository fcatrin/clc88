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

   reg[15:0] pc;
   reg[15:0] pc_next;
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
   localparam CPU_DECODE_WAIT  = 2;
   localparam CPU_LOAD_INST    = 3;
   localparam CPU_EXECUTE      = 4;
   localparam CPU_EXECUTE_WAIT = 5;
   localparam CPU_RESET        = 6;
   
   reg[2:0] cpu_fetch_state = CPU_WAIT;
   reg cpu_reset;
   reg cpu_inst_done;
   reg cpu_inst_state;
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
               pc <= pc + 1;
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
   
   always @ (posedge clk) begin : cpu_decode
      reg wait_for_reset;
      
      address_mode_prepare <= MODE_IDLE;
      if (~reset_n) begin
         wait_for_reset <= 0;
      end else if (cpu_fetch_state == CPU_EXECUTE) begin
         address_mode_prepare <= MODE_IDLE;
         cpu_inst_done <= 0;
         if (cpu_reset) begin
            reg_a <= 0;
            reg_x <= 0;
            reg_y <= 0;
            reg_sp <= 8'hff;
            address_mode_prepare <= MODE_RESET;
            wait_for_reset <= 1;
         end else casex (reg_i)  // format aaabbbcc
            8'b101xxx01: /* LDA */
            begin
               do_load_store <= DO_LOAD;
               case (reg_i[4:2])
                  0: address_mode_prepare <= MODE_IND_X;
                  1: address_mode_prepare <= MODE_Z;
                  2: address_mode_prepare <= MODE_IMM;
                  3: address_mode_prepare <= MODE_ABS;
                  4: address_mode_prepare <= MODE_IND_Y;
                  5: address_mode_prepare <= MODE_Z_X;
                  6: address_mode_prepare <= MODE_ABS_X;
                  7: address_mode_prepare <= MODE_ABS_Y;
               endcase
            end
            8'b100xxx01: /* STA */
            begin
               do_load_store <= DO_STORE;
               reg_write <= reg_a;
               case (reg_i[4:2])
                  0: address_mode_prepare <= MODE_IND_X;
                  1: address_mode_prepare <= MODE_Z;
                  3: address_mode_prepare <= MODE_ABS;
                  4: address_mode_prepare <= MODE_IND_Y;
                  5: address_mode_prepare <= MODE_Z_X;
                  6: address_mode_prepare <= MODE_ABS_X;
                  7: address_mode_prepare <= MODE_ABS_Y;
               endcase
            end
         endcase
      end else if (cpu_inst_done == 0 && cpu_fetch_state == CPU_EXECUTE_WAIT) begin
         if (wait_for_reset) begin
            if (load_complete) begin
               pc_next <= reg_word;
               cpu_inst_done <= 1;
               wait_for_reset <= 0;
            end
         end else casex (reg_i)
            8'b101xxx01: /* LDA */
            if (load_store_complete) begin
               reg_a <= reg_m;
               cpu_inst_done <= 1;
               pc_next <= pc + pc_delta;
            end
            8'b100xxx01: /* STA */
            if (load_store_complete) begin
               cpu_inst_done <= 1;
               pc_next <= pc + pc_delta;
            end
         endcase
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
            pc_delta <= 1;
         end
         MODE_Z, MODE_Z_X, MODE_Z_Y:
         begin
            address_mode <= MODE_Z;
            pc_delta <= 1;
         end
         MODE_IND_X, MODE_IND_Y:
         begin
            address_mode <= MODE_IND_Z;
            pc_delta <= 1;
         end
         MODE_ABS, MODE_ABS_X, MODE_ABS_Y:
         begin
            address_mode <= MODE_ABS;
            pc_delta <= 2;
         end
         MODE_IND_ABS:
         begin
            address_mode <= MODE_IND_ABS;
            pc_delta <= 2;
         end
         MODE_SINGLE:
            pc_delta <= 0;
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
   
   always @ (posedge clk) begin : cpu_load_store_decode
      reg[3:0] next_op;
      reg[7:0] tmp_addr;
      reg wait_for_load;
      
      load_store <= DO_NOTHING;
      if (!reset_n) begin
         next_op <= NEXT_IDLE;
      end else if (bus_rd_req) begin
         wait_for_load <= 1;
      end else if (ready) begin
         load_complete <= 0;
         next_op <= NEXT_IDLE;
         
         case(address_mode)
            MODE_IMM:    /* IMM */
            begin
               bus_addr <= pc;
               load_store <= DO_LOAD;
            end
            MODE_Z:
            begin
               bus_addr <= pc;
               load_store <= DO_LOAD;
               next_op <= NEXT_Z;
            end
            MODE_ABS:  /* ABS */
            begin
               bus_addr <= pc;
               load_store <= DO_LOAD;
               next_op <= NEXT_ABS1;
            end
            MODE_IND_ABS: // JMP (IND)
            begin
               tmp_addr <= rd_data;
               bus_addr <= pc + 1;
               load_store <= DO_LOAD;
               next_op <= NEXT_IND_ABS1; 
            end
            MODE_IND_Z:
            begin
               bus_addr <= {8'd0, rd_data} + reg_ndx_pre;
               load_store <= DO_LOAD;
               next_op <= NEXT_IND_Z1;
            end
            MODE_RESET:
            begin
               bus_addr <= 16'hFFFC;
               load_store <= DO_LOAD;
               next_op <= NEXT_RESET1;
            end
         endcase
         
         case (next_op)
            NEXT_IDLE:
               if (wait_for_load) begin
                  reg_m <= rd_data;
                  load_complete <= 1;
                  wait_for_load <= 0;
               end
            NEXT_Z:
            begin
               bus_addr   <= {8'd0, rd_data} + reg_ndx;
               load_store <= do_load_store;
            end
            NEXT_ABS1:
            begin
               tmp_addr <= rd_data;
               bus_addr <= pc + 1;
               load_store <= DO_LOAD;
               next_op <= NEXT_ABS2;
            end
            NEXT_ABS2:
            begin
               bus_addr   <= {rd_data, tmp_addr} + reg_ndx;
               load_store <= do_load_store;
            end
            NEXT_IND_ABS1:
            begin
               bus_addr <= {rd_data, tmp_addr};
               load_store <= DO_LOAD;
               next_op <= NEXT_IND_ABS2;
            end
            NEXT_IND_ABS2:
            begin
               tmp_addr <= rd_data;
               bus_addr <= bus_addr + 1;
               load_store <= DO_LOAD;
               next_op <= NEXT_IND_ABS3;
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
               next_op <= NEXT_IND_Z2;
            end
            NEXT_IND_Z2:
            begin
               bus_addr <= {rd_data, tmp_addr} + reg_ndx_post;
               load_store <= do_load_store;
            end
            NEXT_RESET1:
            begin
               tmp_addr <= rd_data;
               bus_addr <= bus_addr + 1;
               load_store <= DO_LOAD;
               next_op <= NEXT_RESET2;
            end
            NEXT_RESET2:
            begin
               reg_word <= {rd_data, tmp_addr};
               load_complete <= 1;
            end
         endcase
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
   
   
endmodule
