`timescale 1ns / 1ps

// module to interface with the QMTECH daughter board buttons and displays
// just for testing. It will be replaced by a generic IO in the future

module qmtech_board (
   input clk,
   input reset_n,
   input  [4:0] buttons,
   output reg [7:0] led_segment,
   output reg [2:0] led_digit,
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

    always @(posedge clk) begin : register_write
        if (!reset_n) begin
            led_hex <= 12'h598;
        end else if (wr_en) begin
            case (addr[3:0])
                4'h1: led_hex[3:0]  <= wr_data[3:0];
                4'h2: led_hex[7:4]  <= wr_data[3:0];
                4'h3: led_hex[11:8] <= wr_data[3:0];
            endcase
        end
   end

    parameter   // pgfe dcba
        led_0 = 8'b1100_0000,    //
        led_1 = 8'b1111_1001,    //    aaaaaa
        led_2 = 8'b1010_0100,    //    f    b
        led_3 = 8'b1011_0000,    //    f    b
        led_4 = 8'b1001_1001,    //    gggggg
        led_5 = 8'b1001_0010,    //    e    c
        led_6 = 8'b1000_0010,    //    e    c
        led_7 = 8'b1111_1000,    //    dddddd p
        led_8 = 8'b1000_0000,    //
        led_9 = 8'b1001_0000,
        led_a = 8'b1000_1000,
        led_b = 8'b1000_0011,
        led_c = 8'b1100_0110,
        led_d = 8'b1010_0001,
        led_e = 8'b1000_0110,
        led_f = 8'b1000_1110;

    parameter LCD_CYCLE_1MS = 16'd49999;
    reg[11:0] led_hex;
    reg[15:0] led_counter;
    reg[7:0]  led_segment_on;
    reg[1:0]  led_digit_index;
    wire[3:0] led_number = led_digit_index == 2'b0 ? led_hex[3:0] :
        (led_digit_index == 2'b1 ? led_hex[7:4] : led_hex[11:8]);

    always @(posedge clk) begin : led_counter_cycle
        if(!reset_n || led_counter == LCD_CYCLE_1MS)
            led_counter <= 16'd0;
        else
            led_counter <= led_counter + 1'b1;
    end

    always @(posedge clk) begin : led_output
        if (!reset_n) begin
            led_digit = 3'b0;
            led_digit_index = 2'b0;
        end else if (led_counter == LCD_CYCLE_1MS) begin
            case(led_digit_index)
                2'd0 : begin
                    led_digit <= 3'b100;
                    led_segment <= led_segment_on;
                    led_digit_index <= 2'd1;
                    end
                2'd1 : begin
                    led_digit <= 3'b010;
                    led_segment <= led_segment_on;
                    led_digit_index <= 2'd2;
                    end
                2'd2 : begin
                    led_digit <= 3'b001;
                    led_segment <= led_segment_on;
                    led_digit_index <= 2'b0;
                    end
            endcase
        end
    end

    always @(posedge clk) begin : led_generate
        if (!reset_n) begin
            led_segment_on <= 8'b1111_1111;
        end else case(led_number)
            4'h0 : led_segment_on <= led_0;
            4'h1 : led_segment_on <= led_1;
            4'h2 : led_segment_on <= led_2;
            4'h3 : led_segment_on <= led_3;
            4'h4 : led_segment_on <= led_4;
            4'h5 : led_segment_on <= led_5;
            4'h6 : led_segment_on <= led_6;
            4'h7 : led_segment_on <= led_7;
            4'h8 : led_segment_on <= led_8;
            4'h9 : led_segment_on <= led_9;
            4'ha : led_segment_on <= led_a;
            4'hb : led_segment_on <= led_b;
            4'hc : led_segment_on <= led_c;
            4'hd : led_segment_on <= led_d;
            4'he : led_segment_on <= led_e;
            4'hf : led_segment_on <= led_f;
        endcase
    end

endmodule
