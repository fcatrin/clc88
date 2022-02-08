`timescale 1ns / 1ps

module uart_tx_path(
	input clk_i,
   input reset_n,

	input [7:0] uart_tx_data_i,
	input uart_tx_en_i,
	
	output uart_tx_o,
   output busy
);

parameter BAUD_DIV     = 14'd10416;     // 100Mhz/9600   = 10416
parameter BAUD_DIV_CAP = 14'd5208;      // 100Mhz/9600/2 = 5208

// parameter BAUD_DIV     = 14'd16;     // 100Mhz/9600   = 10416
// parameter BAUD_DIV_CAP = 14'd8;      // 100Mhz/9600/2 = 5208

reg [13:0] baud_div  = 0;
reg        baud_bps  = 0;
reg [9:0]  send_data = 10'b1111111111;  // 1bit + 8bit +1bit
reg [3:0]  bit_num   = 0;

reg uart_send_flag = 0;
reg uart_tx_o_r    = 1;

assign busy = uart_send_flag;

reg baud_clk = 0  /* synthesis keep */;

always@(posedge clk_i)
begin
	if(baud_div == BAUD_DIV_CAP)	begin
		baud_bps <= 1'b1;
		baud_div <= baud_div + 1'b1;
      baud_clk <= !baud_clk;
	end else if (baud_div < BAUD_DIV && uart_send_flag) begin
		baud_div <= baud_div + 1'b1;
		baud_bps <= 0;	
	end else begin
		baud_bps <= 0;
		baud_div <= 0;
   end
end

always@(posedge clk_i)
begin
   if (~reset_n) begin
      uart_send_flag <= 1'b0;
      send_data      <= 10'b1111_1111_11;
   end else if (uart_tx_en_i) begin
		uart_send_flag <= 1'b1;
		send_data      <= {1'b1,uart_tx_data_i,1'b0};  // 1bit + 8bit + 1bit
	end else if (bit_num == 4'd10) begin
		uart_send_flag <= 1'b0;
		send_data      <= 10'b1111_1111_11;
	end
end

always@(posedge clk_i)
begin
	if (uart_send_flag) begin
      if (baud_bps) begin
         if (bit_num <= 4'd9)	begin
            uart_tx_o_r <= send_data[bit_num];
            bit_num <= bit_num + 1'b1;
         end
      end else if (bit_num == 4'd10) begin
				bit_num <= 4'd0;
      end
   end else	begin
		uart_tx_o_r <= 1'b1;
		bit_num     <= 0;
	end
end

assign uart_tx_o = uart_tx_o_r;

endmodule
