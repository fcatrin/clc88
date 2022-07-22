`timescale 1ns / 1ps

module cache (
    input sys_clk,
    input reset_n,

    // device interface (cpu/wopi)
    input[7:0]  data_write,
    output reg[7:0] data_read,
    input[16:0] address,
    input       read_req,
    input       write_req,
    output reg  read_ack,
    output reg  write_ack,

    // SDRAM interface
    output reg[23:0] sdram_address,
    output reg[15:0] sdram_data_write,
    output reg[15:0] sdram_data_read,
    output reg[1:0]  sdram_byte_mask,
    output reg   sdram_read_req,
    output reg   sdram_write_req,
    input        sdram_read_ack,
    input        sdram_write_ack
);

/*
    Cache metadata for:

    - 2 way cache
    - 16 bytes/8 words per line
    - 16 lines
    - LRU eviction
    - Write back
    - index: 4 bits
    - tag: 24 - 4 - 4 = 16 bits

    4321098765432109876543210
                         ++++ -> address within line
                     ++++------> line index
    +++++++++++++++++----------> tag

    w0   ndx         w1   ndx
    tag 0000 data    tag 0000 data
    tag 0001 data    tag 0001 data
    tag 0010 data    tag 0010 data
    tag 0011 data    tag 0011 data
        ....             ....
    tag 1111 data    tag 1111 data
*/

localparam CACHE_LINES = 16;
localparam CACHE_WAYS  = 2;
localparam CACHE_MD    = CACHE_LINES * CACHE_WAYS;
localparam LINE_SIZE   = 4; // 4 bits
localparam INDEX_SIZE  = 4;
localparam TAG_SIZE    = 24 - INDEX_SIZE - LINE_SIZE;

reg[TAG_SIZE-1:0] line_tag    [0:CACHE_MD-1];
reg               line_lru    [0:CACHE_LINES-1];  // 0 = w0, 1 = w1
reg               line_dirty  [0:CACHE_MD-1];
reg               line_valid  [0:CACHE_MD-1];

/*
    State machine:
    IDLE -> READ REQ  -> READ DONE
                      -> READ SDRAM -> READ DONE
                      -> EVICT -> READ SRAM -> READ DONE
         -> WRITE REQ -> WRITE DONE
                      -> READ SDRAM -> WRITE DONE
                      -> EVICT -> READ SRAM -> READ DONE

*/

localparam CA_IDLE       = 0;
localparam CA_READ_REQ   = 1;
localparam CA_READ_DONE  = 2;
localparam CA_READ_SDRAM = 3;
localparam CA_FETCH      = 5;
localparam CA_EVICT      = 6;
localparam CA_WRITE_REQ  = 7;
localparam CA_WRITE_DONE = 8;

always @ (posedge sys_clk or negedge reset_n) begin
    reg[3:0] ca_state;
    reg[3:0] index;
    reg[TAG_SIZE-1:0] tag;
    reg valid_w0;
    reg valid_w1;
    reg[INDEX_SIZE + LINE_SIZE - 1:0] cache_addr_0;
    reg[INDEX_SIZE + LINE_SIZE - 1:0] cache_addr_1;
    reg[15:0] data;
    reg cache_way;
    reg[4:0]  fetch_count;

    read_ack <= 0;
    write_ack <= 0;
    if (!reset_n) begin
        ca_state <= CA_IDLE;
    end else case(ca_state)
        CA_IDLE: begin
            if (read_req | write_req) begin
                index = address[8:5];
                tag   = address[16:9];
                valid_w0 <= line_valid[{index, 0}] && line_tag[{index, 0}] == tag;
                valid_w1 <= line_valid[{index, 1}] && line_tag[{index, 1}] == tag;

                // optimistic read
                cache_address <= {index, address[4:1]};

                ca_state <= read_req ? CA_READ_REQ : CA_WRITE_REQ;
            end
        end
        CA_READ_REQ:
            if (valid_w0 || valid_w1) begin
                line_lru[index] <= !valid_w0;
                ca_state <= CA_READ_DONE;
                read_ack <= 1'b1;
            end else begin
                sdram_address <= {tag, index};
                sdram_read_req <= 1'b1;
                cache_way <= line_lru[index];
                ca_state <= CA_READ_SDRAM;
            end
        CA_READ_DONE: begin
            data = valid_w0 ? q0 : q1;
            data_read <= address[0] ? data[7:0] : data[15:8];
            ca_state <= CA_IDLE;
        end
        CA_READ_SDRAM: if (sdram_read_ack) begin
            ca_state <= CA_FETCH;
            cache_address <= {index, 0};
            fetch_count <= 0;
        end
        CA_FETCH: if (fetch_count != 8) begin
            cache_data_write <= sdram_data_read;
            cache_wr_en_w0 <= cache_way == 0;
            cache_wr_en_w1 <= cache_way == 1;
            fetch_count <= fetch_count + 1'b1;

            // output data as soon as it arrives
            if (fetch_count == address[4:1]) begin
                data_read <= address[0] ? sdram_data_read[7:0] : sdram_data_read[15:8];
                read_ack <= 1'b1;
            end
        end else begin
            valid_w0 = cache_wr_en_w0;
            valid_w1 = cache_wr_en_w1;
            ca_state <= CA_IDLE;
        end
    endcase
end

reg[15:0] cache_address;
reg[15:0] cache_data_write;
reg cache_wr_en_w0;
reg cache_wr_en_w1;
wire[15:0] q0;
wire[15:0] q1;

spram #(256, 8, 16) cache_w0 (
    .address(cache_address),
    .clock(sys_clk),
    .data(cache_data_write),
    .wren(cache_wr_en_w0),
    .q(q0)
    );

spram #(256, 8, 16) cache_w1 (
    .address(cache_address),
    .clock(sys_clk),
    .data(cache_data_write),
    .wren(cache_wr_en_w1),
    .q(q1)
    );


endmodule
