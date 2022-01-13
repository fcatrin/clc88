`timescale 1ns / 1ps

module uart_rx_path(
	input clk_i,
	input uart_rx_i,
	
	output [7:0] uart_rx_data_o,
	output uart_rx_done,
	output baud_bps_tb			//for simulation
    );
    
parameter [12:0] BAUD_DIV     = 13'd5208;   //50Mhz/9600=5208
parameter [12:0] BAUD_DIV_CAP = 13'd2604;   //50Mhz/9600/2=2604

reg [12:0] baud_div=0;
reg baud_bps=0;
reg bps_start=0;
always@(posedge clk_i)
begin
	if(baud_div==BAUD_DIV_CAP)
		begin
			baud_bps<=1'b1;
			baud_div<=baud_div+1'b1;
		end
	else if(baud_div<BAUD_DIV && bps_start)
		begin
			baud_div<=baud_div+1'b1;
			baud_bps<=0;
		end
	else
		begin
			baud_bps<=0;
			baud_div<=0;
		end
end

reg [4:0] uart_rx_i_r=5'b11111;
always@(posedge clk_i)
begin
	uart_rx_i_r<={uart_rx_i_r[3:0],uart_rx_i};
end
wire uart_rx_int=uart_rx_i_r[4] | uart_rx_i_r[3] | uart_rx_i_r[2] | uart_rx_i_r[1] | uart_rx_i_r[0];

reg [3:0] bit_num=0;
reg uart_rx_done_r=0;
reg state=1'b0;

reg [7:0] uart_rx_data_o_r0=0;
reg [7:0] uart_rx_data_o_r1=0;

always@(posedge clk_i)
begin
	uart_rx_done_r<=1'b0;
	case(state)
		1'b0 : 
			if(!uart_rx_int)
				begin
					bps_start<=1'b1;
					state<=1'b1;
				end
		1'b1 :			
			if(baud_bps)
				begin
					bit_num<=bit_num+1'b1;
					if(bit_num<4'd9)
						uart_rx_data_o_r0[bit_num-1]<=uart_rx_i;
				end
			else if(bit_num==4'd10)
				begin
					bit_num<=0;
					uart_rx_done_r<=1'b1;
					uart_rx_data_o_r1<=uart_rx_data_o_r0;
					state<=1'b0;
					bps_start<=0;
				end
		default:;
	endcase
end

assign baud_bps_tb=baud_bps;//for simulation
assign uart_rx_data_o=uart_rx_data_o_r1;		
assign uart_rx_done=uart_rx_done_r;
endmodule
