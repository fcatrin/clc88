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
   
   localparam NOP = 0;
   localparam RESET = 1;
   
   always @ (posedge clk) begin : cpu_decode
      cpu_inst_done <= 0;
      if (~reset_n) begin
         cpu_inst_state <= NOP;
         reg_sp <= 8'hff;
      end else begin
         if (cpu_reset) begin
            cpu_inst_state <= RESET;
         end else if (cpu_fetch_state == CPU_EXECUTE) begin
            reg_ndx <= 0;
            reg_ndx_pre <= 0;
            reg_ndx_post <= 0;
            pc_delta <= 0;
            // format aaabbbcc
            casex (reg_i)
               8'b101xxx01: /* LDA */
               if (load_complete) begin
                  reg_a <= reg_m;
                  cpu_inst_done <= 1;
               end else begin
                  do_load_store <= DO_LOAD;
                  // address_mode  = reg_i[4:2];
               end
            endcase
         end
      end
   end
   
   localparam DO_NOTHING = 0;
   localparam DO_LOAD    = 1;
   localparam DO_STORE   = 2;
   
   reg[1:0] load_store    = DO_NOTHING;
   reg[1:0] do_load_store = DO_NOTHING;
   
   reg load_complete;
   reg store_complete;
   wire load_store_complete = load_complete | store_complete;
   
   always @ (negedge clk) begin : cpu_load_store
      store_complete <= 0;
      if (load_store == DO_LOAD) begin
         bus_rd_req <= 1;
      end else if (load_store == DO_STORE) begin
         bus_wr_data <= reg_m;
         bus_wr_en   <= 1;
         store_complete <= 1;
      end
   end
   
   localparam MODE_IDLE     = 0;
   localparam MODE_READ_M   = 1;
   localparam MODE_IMM      = 2;
   localparam MODE_Z        = 3;
   localparam MODE_ABS      = 4;
   localparam MODE_ABS1     = 5;
   localparam MODE_IND_ABS  = 6;
   localparam MODE_IND_ABS1 = 7;
   localparam MODE_IND_ABS2 = 8;
   localparam MODE_IND_ABS3 = 9;
   localparam MODE_IND_Z    = 10;
   localparam MODE_IND_Z1   = 11;
   localparam MODE_IND_Z2   = 12;
   
   
   always @ (posedge clk) begin : cpu_load_store_decode
      reg[3:0] address_mode;
      reg[7:0] tmp_addr;
      
      load_store = DO_NOTHING;
      load_complete <= 0;
      case(address_mode)
         MODE_READ_M:
         begin
            reg_m <= rd_data;
            load_complete <= 1;
         end
         MODE_IMM:    /* IMM */
         begin
            bus_addr <= pc;
            load_store = DO_LOAD;
         end
         MODE_Z:      /* Z */
         begin
            bus_addr   <= {8'd0, rd_data} + reg_ndx;
            load_store <= do_load_store;
         end
         MODE_ABS:  /* ABS */
         begin
            tmp_addr <= rd_data;
            bus_addr <= pc + 1;
            load_store <= DO_LOAD;
         end
         MODE_ABS1:
         begin
            bus_addr[15:8] <= {rd_data, tmp_addr} + reg_ndx;
            load_store <= do_load_store;
         end
         MODE_IND_ABS: // JMP (IND)
         begin
            tmp_addr <= rd_data;
            bus_addr <= pc + 1;
            load_store <= DO_LOAD;
         end
         MODE_IND_ABS1:
         begin
            bus_addr <= {rd_data, tmp_addr};
            load_store <= DO_LOAD;
         end
         MODE_IND_ABS2:
         begin
            tmp_addr <= rd_data;
            bus_addr <= bus_addr + 1;
            load_store <= DO_LOAD;
         end
         MODE_IND_ABS3:
         begin
            reg_word <= {rd_data, tmp_addr};
            load_complete <= 1;
         end
         MODE_IND_Z:
         begin
            bus_addr <= {8'd0, rd_data} + reg_ndx_pre;
            load_store <= DO_LOAD;
         end
         MODE_IND_Z1:
         begin
            tmp_addr <= rd_data;
            bus_addr <= bus_addr + 1;
            load_store <= DO_LOAD;
         end
         MODE_IND_Z2:
         begin
            bus_addr <= {rd_data, tmp_addr} + reg_ndx_post;
            load_store <= do_load_store;
         end
      endcase            
   end
   
   /*
   always @ (posedge clk) begin : cpu_execute
      cpu_inst_done  <= 0;
      cpu_next_op    <= NOP;
      if (cpu_inst_done == 0 && cpu_fetch_state == CPU_EXECUTE_WAIT) begin
         case (cpu_inst_state)
            CLC:
            begin
               flag_c <= 0;
               pc_next <= pc + pc_delta;
               cpu_inst_done <= 1;
            end
            DONE:
               cpu_inst_done <= 1;
         endcase

         if (bus_rd_ack) begin
            case (cpu_inst_state)
         endcase
         end
      end
   end
   */
   
   reg[15:0] bus_addr;
   reg bus_rd_req;
   reg bus_rd_ack;
   reg bus_wr_en;

   assign wr_en  = bus_wr_en;
   assign rd_req = fetch_rd_req | bus_rd_req;
   assign addr   = hold_fetch_addr ? fetch_rd_addr : bus_addr;

   reg[15:0] fetch_rd_addr;
   reg       fetch_rd_req;

   reg[7:0] bus_wr_data;
   assign wr_data = bus_wr_data;
   
   
endmodule
