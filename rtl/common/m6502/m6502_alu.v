module m6502_alu (
      input clk,
      input reset_n,
      input proceed,
      input  [3:0] op,
      input  [7:0] in_a,
      input  [7:0] in_b,
      input  [1:0] flag_n_set,
      input  [1:0] flag_v_set,
      input  [1:0] flag_d_set,
      input  [1:0] flag_z_set,
      input  [1:0] flag_c_set,
      output [7:0] out,
      output reg flag_c,
      output reg flag_z,
      output reg flag_v,
      output reg flag_n,
      output reg flag_d
      );
   
   `include "m6502_alu_ops.vh"   
   
   reg[8:0] result;
   reg[7:0] ov;
   reg[3:0] op_post;
   reg      next_c;
   assign out = result[7:0];
   
   always @ (posedge clk) begin 
      reg proceed_prev;

      op_post <= OP_NOP;
      proceed_prev <= proceed;
      if (~proceed_prev & proceed) begin
         op_post <= OP_UPDATE;
         case (op)
            OP_UPDATE: result <= in_a;
            OP_AND:    result <= in_a & in_b;
            OP_OR:     result <= in_a | in_b;
            OP_EOR:    result <= in_a ^ in_b;
            OP_INC:    result <= in_a + 1;
            OP_DEC:    result <= in_a - 1;
            OP_CMP:    result <= in_a - in_b;
            OP_ADC:
            begin
               result   <= in_a + in_b + flag_c;
               ov       <= in_a[6:0] + in_b[6:0] + flag_c;
               op_post  <= OP_ADC;
            end
            OP_ASL:
            begin
               result  <= {in_a, 1'b0};
               next_c  <= in_a[7];
               op_post <= OP_UPDATE_C;
            end
            OP_LSR:
            begin
               next_c <= in_a[0];
               result <= in_a[7:1];
               op_post <= OP_UPDATE_C;
            end
            OP_ROL:
            begin
               result <= {in_a[6:0], flag_c};
               next_c <= in_a[7];
               op_post <= OP_UPDATE_C;
            end
            OP_ROR:
            begin
               result <= {flag_c, in_a[7:1]};
               next_c <= in_a[0];
               op_post <= OP_UPDATE_C;
            end
         endcase
      end
   end
   
   always @ (posedge clk) begin : update_flags

      if (~reset_n) begin
         flag_n <= 0;
         flag_v <= 0;
         flag_d <= 0;
         flag_z <= 0;
         flag_c <= 0;
      end else begin
         if (flag_n_set[1]) flag_n <= flag_n_set[0];
         if (flag_v_set[1]) flag_v <= flag_v_set[0];
         if (flag_d_set[1]) flag_d <= flag_d_set[0];
         if (flag_z_set[1]) flag_z <= flag_z_set[0];
         if (flag_c_set[1]) flag_c <= flag_c_set[0];
         
         if (op_post != OP_NOP) begin
            flag_z <= out == 0;
            flag_n <= out[7];
         end
         case (op_post)
            OP_ADC:
            begin
               flag_c <= result[8];
               flag_v <= (!in_a[7] & !in_b[7] & ov[7]) | (in_a[7] & in_b[7] & ov[7]);
            end
            OP_CMP:
               flag_c <= !result[8];
            OP_UPDATE_C:
               flag_c <= next_c;
         endcase
      end
   end
   
endmodule