
module clock_divider(
  input clk,
  input reset,
  output reg chroni_rd_req,
  output reg chroni_rd_ack,
  output reg[7:0] vram_data_read,
  output reg[7:0] vram_data_addr,
  output reg[7:0] rom_addr,
  output reg[7:0] font_reg_next,
  wire[2:0] w_font_decode_state,
  wire[2:0] w_bus_state,
  reg[3:0] counter
);

  wire w_font_decode_state;
  assign w_font_decode_state = font_decode_state;

  wire w_bus_state;
  assign w_bus_state = bus_state;

  reg[2:0] bus_state;
  
  localparam BUS_STATE_READY = 3'd0;
  localparam BUS_STATE_CHRONI_READ_REQ  = 3'd1;
  localparam BUS_STATE_CHRONI_READ_REQ2 = 3'd2;
  
  always @(posedge clk)
    begin
      if (reset) begin
        counter <= 0;
        bus_state <= 0;
        vram_data_read <= 0;
        rom_addr <= 0;
        chroni_rd_ack <= 0;
      end else begin
         case (bus_state)
            BUS_STATE_READY :
               begin
                  chroni_rd_ack <= 0;
                  if (chroni_rd_req) begin
                     bus_state <= BUS_STATE_CHRONI_READ_REQ;
                     rom_addr <= vram_data_addr;
                  end
               end
            BUS_STATE_CHRONI_READ_REQ : 
               bus_state <= BUS_STATE_CHRONI_READ_REQ2;
            BUS_STATE_CHRONI_READ_REQ2 :
               begin
                 vram_data_read <= {4'b000, counter};
                 bus_state <= BUS_STATE_READY;
                 chroni_rd_ack <= 1;
               end
           default:
              bus_state <= bus_state;
         endcase
         counter <= counter + 1;
      end
    end

  reg[2:0] font_decode_state;
  
  localparam FONT_DECODE_STATE_IDLE = 3'd0;
  localparam FONT_DECODE_STATE_TEXT_READ =  3'd1;
  localparam FONT_DECODE_STATE_TEXT_WAIT =  3'd2;
  localparam FONT_DECODE_STATE_FONT_READ =  3'd3;
  localparam FONT_DECODE_STATE_FONT_SHIFT = 3'd4;

  reg chroni_rd_ack_prev;
  
  always @(posedge clk)
    begin
      if (reset) begin
        font_decode_state <= FONT_DECODE_STATE_IDLE;
        vram_data_addr <= 0;
        chroni_rd_req <= 0;
        font_reg_next <= 0;
      end else 
         case (font_decode_state)
         FONT_DECODE_STATE_IDLE: 
            begin
               chroni_rd_req <= 0;
               font_decode_state <= FONT_DECODE_STATE_TEXT_READ;
            end
         FONT_DECODE_STATE_TEXT_READ:
            begin
               vram_data_addr <= 8'd32;
               chroni_rd_req <= 1;
               chroni_rd_ack_prev <= 1;
               font_decode_state <= FONT_DECODE_STATE_TEXT_WAIT;
            end
         FONT_DECODE_STATE_TEXT_WAIT:
            begin
              if (chroni_rd_ack) begin
                  chroni_rd_req <= 1;
                  vram_data_addr <= vram_data_read + 1;
                  font_decode_state <= FONT_DECODE_STATE_FONT_READ;
              end else
                chroni_rd_req <= 0;
            end
         FONT_DECODE_STATE_FONT_READ:
            begin
               if (chroni_rd_ack) begin
                  chroni_rd_req <= 0;
                  font_reg_next <= vram_data_read;
                  font_decode_state <= FONT_DECODE_STATE_FONT_SHIFT;
              end else
                chroni_rd_req <= 0;
            end
         FONT_DECODE_STATE_FONT_SHIFT:
            font_decode_state <= FONT_DECODE_STATE_IDLE;
         default:
           vram_data_addr <= vram_data_addr;
         endcase
    end
endmodule
