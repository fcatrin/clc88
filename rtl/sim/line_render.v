module line_render (
      input clk,
      input reset,
      output reg render_buffer,
      output reg render_flag,
      output reg pf,
      output reg [7:0] y_cnt,
      output reg [2:0] x_cnt,
      output reg [3:0] output_state,
      output reg output_buffer
      );

   parameter h_total = 4;
   parameter v_total = 24;
   parameter v_pf_start = 5;
   parameter v_pf_end = 17;
  

   reg vga_scale = 1;

   always @ (posedge clk) begin
      if (reset) begin
         x_cnt <= 1;
         y_cnt <= 1;
      end else if (x_cnt == h_total) begin
         x_cnt <= 1;
         y_cnt <= y_cnt == v_total ? 1 : (y_cnt + 1);
         if (y_cnt == 1) pf <= 0;
         else if (y_cnt == v_pf_start) pf <= 1;
         else if (y_cnt == v_pf_end)   pf <= 0;
      end else begin
         x_cnt <= x_cnt + 1;
      end
   end
  
   always @ (posedge clk) begin : output_block
      if (reset) begin
         output_state <= 15;
      end else if (x_cnt == 1) begin
         if (y_cnt == 1 || y_cnt == v_pf_end) begin
            output_state <= 15;
         end else if (y_cnt == v_pf_start) begin
            output_state <= vga_scale ? 5 : 1;
         end else if (output_state != 15) begin
            if (vga_scale) begin
               output_state <= output_state == 5 ? 0 : (output_state + 1);
               if (output_state == 5) begin
                  output_buffer <= 0;
               end else if (output_state == 2) begin
                  output_buffer <= 1;
               end
            end else begin
               output_state <= output_state == 3 ? 0 : (output_state + 1);
               if (output_state == 3) begin
                  output_buffer <= 0;
               end else if (output_state == 1) begin
                  output_buffer <= 1;
               end
            end
         end
      end
   end
    
  
   always @ (posedge clk) begin : render_block
      reg[3:0] render_state;
      if (reset) begin
         render_buffer <= 0;
         render_flag   <= 0;
         render_state  <= 15;
      end else begin
         if (x_cnt == h_total) begin
            if (y_cnt == 1 || y_cnt == v_pf_end - 2) begin
               render_state <= 15;
               render_flag  <= 0;
            end else if (y_cnt == v_pf_start - 2) begin
               render_state <= vga_scale ? 5 : 3;
            end else if (render_state != 15) begin
               if (vga_scale) begin
                  render_state  <= render_state == 5 ? 0 : (render_state + 1);
                  render_flag   <= render_state == 5 || render_state == 2;
                  render_buffer <= render_state == 5 ? 0 : 1;
               end else begin
                  render_state  <= render_state == 3 ? 0 : (render_state + 1);
                  render_flag   <= render_state[0];
                  render_buffer <= render_state == 3 ? 0 : 1;
               end
            end
         end
      end
   end
endmodule
