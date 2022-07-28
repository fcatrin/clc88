`timescale 1ns / 1ps

//`define ALTSYNCRAM

module cache (
    input sys_clk,
    input reset_n,

    // device interface (cpu/wopi)
    input[7:0]  data_write,
    output[7:0] data_read,
    input[16:0] address,
    input       read_req,
    input       write_req,
    output reg  read_ack,
    output reg  write_ack,

    // SDRAM interface
    output reg[23:0] sdram_address,
    output reg[15:0] sdram_data_write,
    input[15:0]      sdram_data_read,
    output reg       sdram_read_req,
    output reg       sdram_write_req,
    input            sdram_read_ack,
    input            sdram_write_ack
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
localparam TAG_SIZE    = 17 - INDEX_SIZE - LINE_SIZE;

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

    Evict / Replace logic:
    * Avoid replacing a dirty line
    * replace_w1 if neither line is candidate

    replace_w0 = dirty_w1 | !lru;
    replace_w1 = dirty_w0 | lru | !replace_w0;

*/

localparam CA_IDLE        =  0;
localparam CA_READ_REQ    =  1;
localparam CA_READ_SDRAM  =  3;
localparam CA_FETCH       =  4;
localparam CA_FETCH_DONE  = 11;
localparam CA_EVICT       =  5;
localparam CA_WRITE_REQ   =  6;
localparam CA_WRITE_DONE  =  7;
localparam CA_WRITE_START =  8;
localparam CA_WRITE_BACK  =  9;
localparam CA_WAIT_BRAM   = 10;

reg[3:0] index;
wire lru = line_lru[index];
wire[4:0] index_0 = {index, 1'b0};
wire[4:0] index_1 = {index, 1'b1};

reg valid_w0;
reg valid_w1;
reg byte_low;
wire[15:0] data = valid_w0 ? q0 : q1;
assign data_read = byte_low ? data[7:0] : data[15:8];

always @ (posedge sys_clk or negedge reset_n) begin : cache_rw
    reg[3:0] ca_state;
    reg[3:0] ca_back;
    reg[TAG_SIZE-1:0] tag;
    reg cache_way;
    reg[3:0]  fetch_count;
    reg[3:0]  write_count;
    reg replace_w0;
    reg replace_w1;
    reg[15:0] last_address;

    read_ack <= 0;
    write_ack <= 0;
    cache_wr_en_w0 <= 0;
    cache_wr_en_w1 <= 0;

    if (!reset_n) begin
        ca_state <= CA_IDLE;
        last_address <= 16'h1234; // just use a random number here. KISS
    end else case(ca_state)
        CA_IDLE: begin
            if ((read_req | write_req) && !read_ack) begin
                /* verilator lint_off BLKSEQ */
                index = address[7:4];
                tag   = address[16:8];
                valid_w0 <= line_valid[{index, 1'b0}] && line_tag[{index, 1'b0}] == tag;
                valid_w1 <= line_valid[{index, 1'b1}] && line_tag[{index, 1'b1}] == tag;

                replace_w0 = line_dirty[{index, 1'b0}] | !lru;
                replace_w1 = line_dirty[{index, 1'b1}] | lru | !replace_w0;

                byte_low <= !address[0];

                // optimistic read
                cache_address <= {index, address[3:1]};

                last_address <= address[16:1];
                if (read_req && last_address == address[16:1]) begin
                    read_ack <= 1'b1;
                end else begin
                    ca_state <= read_req ? CA_READ_REQ : CA_WRITE_REQ;
                end
            end
        end
        CA_READ_REQ: begin
            ca_back   <= CA_IDLE;
            cache_way <= replace_w0 ? 0 : 1;
            if (valid_w0 || valid_w1) begin
                cache_way <= valid_w0 ? 0 : 1;
                line_lru[index] <= valid_w0;
                ca_state <= CA_IDLE;
                read_ack <= 1'b1;
            end else if ((replace_w0 && line_dirty[index_0]) || (replace_w1 && line_dirty[index_1])) begin
                ca_state <= CA_EVICT;
            end else begin
                sdram_address <= {8'b0, tag, index, 3'b0};
                sdram_read_req <= 1'b1;
                ca_state <= CA_READ_SDRAM;
                ca_back  <= CA_READ_REQ;
            end
        end
        CA_WRITE_REQ: begin
            ca_back  <= CA_WRITE_REQ;
            cache_way <= replace_w0 ? 0 : 1;
            if (valid_w0 || valid_w1) begin
                line_lru[index] <= valid_w0;
                line_dirty[valid_w0 ? index_0 : index_1] = 1'b1;
                ca_state <= CA_WRITE_DONE;
                write_ack <= 1'b1;
            end else if ((replace_w0 && line_dirty[index_0]) || (replace_w1 && line_dirty[index_1])) begin
                ca_state <= CA_EVICT;
            end else begin
                valid_w0 <= cache_way == 0 ? 1 : 0;
                valid_w1 <= cache_way == 1 ? 1 : 0;
                sdram_address <= {8'b0, tag, index, 3'b0};
                sdram_read_req <= 1'b1;
                ca_state <= CA_READ_SDRAM;
            end
        end
        CA_WRITE_DONE: begin
            if (byte_low)
                cache_data_write[7:0]  <= data_write;
            else
                cache_data_write[15:8] <= data_write;
            cache_data_mask <= byte_low ? 2'b01 : 2'b10;
            cache_wr_en_w0 <= cache_way == 0;
            cache_wr_en_w1 <= cache_way == 1;
            ca_state <= CA_IDLE;
        end
        CA_READ_SDRAM: if (sdram_read_ack) begin
            sdram_read_req <= 0;
            ca_state <= CA_FETCH;
            cache_data_mask <= 2'b11;
            fetch_count <= 0;
        end
        CA_FETCH: begin
            if (fetch_count == 0) begin
                cache_address <= {index, 3'b0};
            end else begin
                cache_address <= cache_address + 1'b1;
            end
            cache_data_write <= sdram_data_read;
            fetch_count <= fetch_count + 1'b1;

            cache_wr_en_w0 <= cache_way == 0;
            cache_wr_en_w1 <= cache_way == 1;

            if (fetch_count == 4'd7) begin
                line_valid[cache_way ? index_1 : index_0] <= 1'b1;
                line_tag[cache_way ? index_1 : index_0]   <= tag;
                valid_w0 <= cache_way == 0 ? 1 : 0;
                valid_w1 <= cache_way == 1 ? 1 : 0;
                ca_state <= CA_FETCH_DONE;
            end
        end
        CA_FETCH_DONE: begin
            cache_address <= {index, address[3:1]};
            ca_state <= ca_back;
        end
        CA_EVICT: begin
            cache_data_mask <= 2'b11;
            cache_way <= replace_w0 ? 0 : 1;
            cache_address <= {index, 3'b0};
            ca_state <= CA_WAIT_BRAM;
        end
        CA_WAIT_BRAM: begin
            ca_state <= CA_WRITE_START;
        end
        CA_WRITE_START: begin
            sdram_address <= {8'b0, line_tag[replace_w0 ? index_0 : index_1], index, 3'b0};
            sdram_data_write <= cache_way ? q1 : q0;
            sdram_write_req <= 1'b1;
            write_count <= 0;
            ca_state <= CA_WRITE_BACK;
        end
        CA_WRITE_BACK: if (sdram_write_ack) begin
            sdram_address <= sdram_address + 1'b1;
            sdram_data_write <= cache_way ? q1 : q0;
            sdram_write_req <= 1'b1;
            if (write_count == 4'd7) begin
                line_dirty[cache_way ? index_1 : index_0] = 1'b0;
                ca_state <= ca_back;
            end else begin
                write_count <= write_count + 1'b1;
            end
        end
    endcase
end

reg[6:0]  cache_address;
reg[15:0] cache_data_write;
reg[1:0]  cache_data_mask;
reg cache_wr_en_w0;
reg cache_wr_en_w1;

`ifdef ALTSYNCRAM

wire[15:0] q0;
wire[15:0] q1;

spram #(256, 7, 16) cache_w0 (
    .address(cache_address),
    .clock(sys_clk),
    .data(cache_data_write),
    .byte_en(cache_data_mask),
    .wren(cache_wr_en_w0),
    .q(q0)
    );

spram #(256, 7, 16) cache_w1 (
    .address(cache_address),
    .clock(sys_clk),
    .data(cache_data_write),
    .byte_en(cache_data_mask),
    .wren(cache_wr_en_w1),
    .q(q1)
    );

`else

reg[15:0] mem0[0:127];
reg[15:0] mem1[0:127];
reg[15:0] q0;
reg[15:0] q1;

always @(posedge sys_clk) begin : cache_mem_0
    reg[6:0] last_address;
    /* verilator lint_off CASEINCOMPLETE */
    if (cache_wr_en_w0) case(cache_data_mask)
        2'b01 : mem0[cache_address][7:0]  <= cache_data_write[7:0];
        2'b10 : mem0[cache_address][15:8] <= cache_data_write[15:8];
        2'b11 : mem0[cache_address]       <= cache_data_write;
    endcase
    if (cache_address != last_address) begin
        last_address <= cache_address;
    end
    q0 <= mem0[last_address];
end

always @(posedge sys_clk) begin : cache_mem_1
    reg[6:0] last_address;
    /* verilator lint_off CASEINCOMPLETE */
    if (cache_wr_en_w1) case(cache_data_mask)
        2'b01 : mem1[cache_address][7:0]  <= cache_data_write[7:0];
        2'b10 : mem1[cache_address][15:8] <= cache_data_write[15:8];
        2'b11 : mem1[cache_address]       <= cache_data_write;
    endcase
    if (cache_address != last_address) begin
        last_address <= cache_address;
    end
    q1 <= mem1[last_address];
end

`endif
endmodule
