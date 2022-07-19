module sdram_test(
    input  clk50,
    input  reset_n,
    input  start_n,
    output pll_locked,
    
    // SDRAM control
    output        S_CLK,  // SDRAM clock
    output        S_CKE,  // SDRAM clock enable
    output        S_NCS,  // SDRAM chip select
    output        S_NWE,  // SDRAM write enable
    output        S_NCAS, // SDRAM column address strobe
    output        S_NRAS, // SDRAM row address strobe
    output [1:0]  S_DQM,  // SDRAM data enable
    output [1:0]  S_BA,   // SDRAM bank address
    output [12:0] S_A,    // SDRAM address
    inout  [15:0] S_DB    // SDRAM data
    );

assign S_DQM = 2'b00;

/*******************************/
// SDRAM read and write test program
/*******************************/
reg [3:0] i;
reg [8:0] counter;

reg         sdram_wr_req;    // SDRAM burst write request
reg         sdram_rd_req;    // SDRAM burst read request
wire        sdram_wr_ack;    // SDRAM burst write response
wire        sdram_rd_ack;    // SDRAM burst read response
reg	  [8:0] wr_length;       // user interface SDRAM write burst length
reg	  [8:0] rd_length;       // user interface SDRAM read burst length
reg	 [22:0] wr_addr;         // user interface SDRAM start write address
reg	 [22:0] rd_addr;         // user interface SDRAM start read address
reg	 [15:0] sdram_din;       // user interface SDRAM data input
wire [15:0] sdram_dout;      // user interface SDRAM data output
wire        sdram_init_done; // SDRAM init done

always @ ( negedge sys_clk ) begin
    if( !reset_n ) begin
        i <=  4'd0;
        counter      <=     0;
        wr_length    <=  9'd0;
        rd_length    <=  9'd0;
        sdram_wr_req <=  1'b0;
        sdram_rd_req <=  1'b0;
        wr_addr      <= 23'd0;
        rd_addr      <= 23'd0;
        sdram_din    <= 16'd0;
    end else case( i )
        4'd0:       // Wait for SDRAM initialization to complete
            if( sdram_init_done & !start_n) i<=i+1'b1;
            else i<=4'd0;

        4'd1: begin // Send burst write command, write 512 data to SDRAM address 0
            sdram_wr_req <=  1'b1;
            wr_addr      <= 23'd0;
            wr_length    <=  9'd8;
            sdram_din    <= 16'd0;
            i <= i + 1'b1;
        end

        4'd2: // Waiting for the reply signal written by burst
            if( sdram_wr_ack==1'b1) begin
                i <= i + 1'b1;
                counter <= counter + 1'b1;
            end

        4'd3: begin // Write 256 data to SDRAM, add 1 to the data
            sdram_wr_req <= 1'b0;
            if( counter == 9'd8 ) begin
                counter   <= 9'd0;
                i <= i + 1'b1;
            end else if (sdram_wr_ack == 1'b1) begin
                sdram_din <= sdram_din + 1'b1;
                counter   <= counter + 1'b1;
            end;
        end

        4'd4: begin // Send burst read command, read 256 data from Sdram address 0 to Sdram address 0
            sdram_rd_req <=  1'b1;
            rd_addr      <= 23'd0;
            rd_length    <=  9'd8;
            i <= i + 1'b1;
        end

        4'd5: // Waiting for the response signal of burst read
            if( sdram_rd_ack == 1'b1 ) begin
                i <= i + 1'b1;
                sdram_rd_req <= 1'b0;
                counter      <= counter + 1'b1;
            end

        4'd6: // Read 256 data from SDRAM
            if( counter == 9'd8 ) begin
                i <= i + 1'b1; // finish state machine
            end else if (sdram_rd_ack == 1'b1) begin
                counter <= counter + 1'b1;
            end
        endcase
end

wire[22:0] sdram_wraddr = wr_addr;
wire[22:0] sdram_rdaddr = rd_addr;

// SDRAM read and write control section
//----------------------------------------------
sdram_top u_sdramtop (
    .clk   (sys_clk),   // SDRAM reference clock
    .rst_n (reset_n),   // global reset

    // Internal interface
    .sdram_wr_req    (sdram_wr_req),    // SDRAM write request
    .sdram_rd_req    (sdram_rd_req),    // SDRAM write ack
    .sdram_wr_ack    (sdram_wr_ack),    // SDRAM read request
    .sdram_rd_ack    (sdram_rd_ack),    // SDRAM read ack
    .sys_wraddr      (sdram_wraddr),    // SDRAM write address
    .sys_rdaddr      (sdram_rdaddr),    // SDRAM read address
    .sys_data_in     (sdram_din),       // fifo 2 SDRAM data input
    .sys_data_out    (sdram_dout),      // SDRAM 2 fifo data input
    .sdram_init_done (sdram_init_done), // SDRAM init done

    // Burst length
    .sdwr_byte (wr_length), // SDRAM write burst length
    .sdrd_byte (rd_length), // SDRAM read burst length

    // SDRAM interface
    .sdram_cke   (S_CKE),         // SDRAM clock enable
    .sdram_cs_n  (S_NCS),         // SDRAM chip select
    .sdram_we_n  (S_NWE),         // SDRAM write enable
    .sdram_ras_n (S_NRAS),        // SDRAM column address strobe
    .sdram_cas_n (S_NCAS),        // SDRAM row address strobe
    .sdram_ba    (S_BA),          // SDRAM data enable (H:8)
    .sdram_addr  (S_A),           // SDRAM data enable (L:8)
    .sdram_data  (S_DB)           // SDRAM bank address
);

wire sys_clk;
wire clk_disconnected;
assign S_CLK = sys_clk;

pll	pll_inst (
	.inclk0(clk50),
	.c0(sys_clk),        // 100Mhz    (system)
	.c1(clk_disconnected),          // 100Mhz    (SDRAM clock)
	.locked(pll_locked)
	);

endmodule