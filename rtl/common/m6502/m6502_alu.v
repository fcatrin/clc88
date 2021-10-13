module m6502_alu (
      input clk,
      input reset_n,
      input proceed,
      input  [3:0] op,
      input  [7:0] in_a,
      input  [7:0] in_b,
      input  flag_c_set,
      input  flag_c_reset,
      output [7:0] out,
      output reg flag_c,
      output reg flag_z,
      output reg flag_v,
      output reg flag_n
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
         case (op)
            OP_UPDATE:
               result <= in_a;
            OP_AND:
               result <= in_a & in_b;
            OP_OR:
               result <= in_a | in_b;
            OP_EOR:
               result <= in_a ^ in_b;
            OP_ADC:
            begin
               result   <= in_a + in_b + flag_c;
               ov       <= in_a[6:0] + in_b[6:0] + flag_c;
               op_post  <= OP_ADC;
            end
            OP_INC:
               result <= in_a + 1;
            OP_DEC:
               result <= in_a - 1;
            OP_CMP:
               result <= in_a - in_b;
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
      reg flag_c_set_prev;
      reg flag_c_reset_prev;
      
      if (~reset_n) begin
         flag_c_set_prev   <= 0;
         flag_c_reset_prev <= 0;
         flag_c <= 0;
         flag_z <= 0;
         flag_n <= 0;
         flag_v <= 0;
      end else begin
         flag_c_set_prev   <= flag_c_set;
         flag_c_reset_prev <= flag_c_reset;
   
         flag_z <= out == 0;
         flag_n <= out[7];
         
         if (!flag_c_set_prev & flag_c_set) begin
            flag_c <= 1;
         end else if (!flag_c_reset_prev & flag_c_reset_prev) begin
            flag_c <= 0;
         end else case (op_post)
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