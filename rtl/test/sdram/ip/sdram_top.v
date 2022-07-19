`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// SDRAM Package control top-level module
////////////////////////////////////////////////////////////////////////////////

/*-----------------------------------------------------------------------------
SDRAM Interface Description
    During power-on reset, SDRAM will automatically wait for 200us and then initialize.
    See the sdram_ctrl module for settings
    Operation of SDRAM：
        Control sys_en=1, sys_r_wn=0, sys_addr, sys_data_in to write SDRAM data Operation;
        Control sys_en=1, sys_r_wn=1, sys_addr can read data from sys_data_out.
        At the same time, you can check whether the read and write is completed by querying the status of sdram_busy.
-----------------------------------------------------------------------------*/
module sdram_top (
    input clk,    // System clock, 100MHz
    input rst_n,  // Reset signal, active low

    // SDRAM package interface
    input  sdram_wr_req,  // System write SDRAM request signal
    input  sdram_rd_req,  // System read SDRAM request signal
    output sdram_wr_ack,  // System write SDRAM response signal
    output sdram_rd_ack,  // System read SDRAM response signal

    input [22:0] sys_wraddr,   // Address register when writing SDRAM
    input [22:0] sys_rdaddr,   // Address register when reading SDRAM
    input [15:0] sys_data_in,  // System to SDRAM data
    output[15:0] sys_data_out, // SDRAM to System data
    input  [8:0] sdwr_byte,    // Burst write SDRAM bytes (1-256)
    input  [8:0] sdrd_byte,    // Burst read SDRAM bytes (1-256)

    // FPGA and SDRAM hardware interface
    output sdram_cke,         // SDRAM clock valid signal
    output sdram_cs_n,        // SDRAM chip select signal
    output sdram_ras_n,       // SDRAM row address strobe
    output sdram_cas_n,       // SDRAM column address strobe
    output sdram_we_n,        // SDRAM write enable bit
    output [1:0] sdram_ba,    // L-Bank address line of SDRAM
    output[12:0] sdram_addr,  // SDRAM address bus
    inout [15:0] sdram_data,  // SDRAM data bus

    output  sdram_init_done   // System initialization complete signal
    );


// SDRAM internal interface
wire[3:0] init_state;  // SDRAM initialization register
wire[3:0] work_state;  // SDRAM working status register
wire[8:0] cnt_clk;     // clock count
wire sys_r_wn;         // SDRAM read/write control signal
        
sdram_ctrl module_001 ( // SDRAM state control module
    .clk   (clk),
    .rst_n (rst_n),
    // .sdram_udqm   (sdram_udqm),
    // .sdram_ldqm   (sdram_ldqm)
    .sdram_wr_req    (sdram_wr_req),
    .sdram_rd_req    (sdram_rd_req),
    .sdram_wr_ack    (sdram_wr_ack),
    .sdram_rd_ack    (sdram_rd_ack),
    .sdwr_byte       (sdwr_byte),
    .sdrd_byte       (sdrd_byte),
    // .sdram_busy   (sdram_busy),
    // .sys_dout_rdy (sys_dout_rdy),
    .sdram_init_done (sdram_init_done),
    .init_state      (init_state),
    .work_state      (work_state),
    .cnt_clk         (cnt_clk),
    .sys_r_wn        (sys_r_wn)
    );

sdram_cmd module_002 ( // SDRAM command module
    .clk   (clk),
    .rst_n (rst_n),
    .sdram_cke   (sdram_cke),
    .sdram_cs_n  (sdram_cs_n),
    .sdram_ras_n (sdram_ras_n),
    .sdram_cas_n (sdram_cas_n),
    .sdram_we_n  (sdram_we_n),
    .sdram_ba    (sdram_ba),
    .sdram_addr  (sdram_addr),
    .sys_wraddr  (sys_wraddr),
    .sys_rdaddr  (sys_rdaddr),
    .sdwr_byte   (sdwr_byte),
    .sdrd_byte   (sdrd_byte),
    .init_state  (init_state),
    .work_state  (work_state),
    .sys_r_wn    (sys_r_wn),
    .cnt_clk     (cnt_clk)
    );

sdram_wr_data module_003 ( // SDRAM data read and write module
    .clk   (clk),
    .rst_n (rst_n),
    // .sdram_clk (sdram_clk),
    .sdram_data   (sdram_data),
    .sys_data_in  (sys_data_in),
    .sys_data_out (sys_data_out),
    .work_state   (work_state),
    .cnt_clk      (cnt_clk)
    );
endmodule

