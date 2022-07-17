`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Description : SDRAM data read and write module
////////////////////////////////////////////////////////////////////////////////
module sdram_wr_data(
    clk,
    rst_n,
    // sdram_clk,
    sdram_data,
    sys_data_in,
    sys_data_out,
    work_state,cnt_clk
    );

// System signals
input clk;   // System clock, 100MHz
input rst_n; // Reset signal, active low

// SDRAM hardware interface
// output sdram_clk;        // SDRAM clock signal
inout[15:0] sdram_data;     // SDRAM data bus

// SDRAM package interface
input [15:0] sys_data_in;   // Data scratchpad when writing to SDRAM
output[15:0] sys_data_out;  // Data scratchpad when reading SDRAM

// SDRAM internal interface
input[3:0] work_state;      // Data status register when reading and writing SDRAM
input[8:0] cnt_clk;         // clock count

`include "sdram_para.v"     // Contains SDRAM parameter definition module

// assign sdram_clk = ~clk; // SDRAM clock signal

//------------------------------------------------------------------------------
// data write control
//------------------------------------------------------------------------------
reg[15:0] sdr_din;   // Burst Data Write Register
reg       sdr_dlink; // SDRAM data bus input and output control

// Send the data to be written to the SDRAM data bus
always @ (posedge clk or negedge rst_n) 
    if (!rst_n)
        sdr_din <= 16'd0; // Burst data write register reset
    else if ((work_state == `W_WRITE) | (work_state == `W_WD))
        sdr_din <= sys_data_in; // Continuously write 256 16bit data stored in wrFIFO

// Generate bidirectional data line direction control logic
always @ (posedge clk or negedge rst_n) 
    if (!rst_n)
        sdr_dlink <= 1'b0;
    else if ((work_state == `W_WRITE) | (work_state == `W_WD))
        sdr_dlink <= 1'b1;
    else
        sdr_dlink <= 1'b0;

assign sdram_data = sdr_dlink ? sdr_din:16'hzzzz;

//------------------------------------------------------------------------------
// Data read control
//------------------------------------------------------------------------------
reg[15:0] sdr_dout; // Burst Data Read Register

// read data from SDRAM
always @ (posedge clk or negedge rst_n)
    if (!rst_n)
        sdr_dout <= 16'd0; // Burst data read register reset
    else if ((work_state == `W_RD)/* & (cnt_clk > 9'd0) & (cnt_clk < 9'd10)*/)
        sdr_dout <= sdram_data; // Continuously read 8B of 16bit data and store it in rdFIFO

assign sys_data_out = sdr_dout;

endmodule
