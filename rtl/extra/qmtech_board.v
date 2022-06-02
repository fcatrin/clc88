`timescale 1ns / 1ps

// module to interface with the QMTECH daughter board buttons and displays
// just for testing. It will be replaced by a generic IO in the future

module qmtech_board (
   input clk,
   input reset_n,
   input  [4:0] buttons,
   output reg [7:0] lcd_segment,
   output reg [2:0] lcd_digit,
   input  [7:0] wr_data,
   output [7:0] rd_data,
   input  [3:0] addr,
   input wr_en
);
   
   assign rd_data = data;
   reg[7:0] data;

   always @(posedge clk) begin : register_read
     case (addr[3:0])
        4'h0: data <= {3'b0, ~buttons};
     endcase
   end

    parameter
        lcd_0 = 8'b1100_0000,
        lcd_1 = 8'b1111_1001,
        lcd_2 = 8'b1010_0100,
        lcd_3 = 8'b1011_0000,
        lcd_4 = 8'b1001_1001,
        lcd_5 = 8'b1001_0010,
        lcd_6 = 8'b1000_0010,
        lcd_7 = 8'b1111_1000,
        lcd_8 = 8'b1000_0000,
        lcd_9 = 8'b1001_0000;

    parameter LCD_CYCLE_1MS = 16'd49999;
    reg[11:0] lcd_bcd = 12'h123;
    reg[15:0] lcd_counter;
    reg[7:0]  lcd_segment_on;
    reg[1:0]  lcd_digit_index;
    wire[3:0] lcd_number = lcd_digit_index == 2'b0 ? lcd_bcd[3:0] :
        (lcd_digit_index == 2'b1 ? lcd_bcd[7:4] : lcd_bcd[11:8]);

    always @(posedge clk) begin : lcd_counter_cycle
        if(!reset_n || lcd_counter == LCD_CYCLE_1MS)
            lcd_counter <= 16'd0;
        else
            lcd_counter <= lcd_counter + 1'b1;
    end

    always @(posedge clk) begin : lcd_output
        if (!reset_n) begin
            lcd_digit = 3'b0;
            lcd_digit_index = 2'b0;
        end else if (lcd_counter == LCD_CYCLE_1MS) begin
            case(lcd_digit_index)
                2'd0 : begin
                    lcd_digit <= 3'b100;
                    lcd_segment <= lcd_segment_on;
                    lcd_digit_index <= 2'd1;
                    end
                2'd1 : begin
                    lcd_digit <= 3'b010;
                    lcd_segment <= lcd_segment_on;
                    lcd_digit_index <= 2'd2;
                    end
                2'd2 : begin
                    lcd_digit <= 3'b001;
                    lcd_segment <= lcd_segment_on;
                    lcd_digit_index <= 2'b0;
                    end
            endcase
        end
    end

    always @(posedge clk) begin : lcd_generate
        if (!reset_n) begin
            lcd_segment_on <= 8'b1111_1111;
        end else case(lcd_number)
            4'h0 : lcd_segment_on <= lcd_0;
            4'h1 : lcd_segment_on <= lcd_1;
            4'h2 : lcd_segment_on <= lcd_2;
            4'h3 : lcd_segment_on <= lcd_3;
            4'h4 : lcd_segment_on <= lcd_4;
            4'h5 : lcd_segment_on <= lcd_5;
            4'h6 : lcd_segment_on <= lcd_6;
            4'h7 : lcd_segment_on <= lcd_7;
            4'h8 : lcd_segment_on <= lcd_8;
            4'h9 : lcd_segment_on <= lcd_9;
        endcase
    end

endmodule
