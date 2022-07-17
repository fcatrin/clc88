`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module Name : sdram_para
// Project Name : 
// Target Device: Cyclone EP4CE6C8 
// Tool versions: Quartus II 12.1
// Description : SDRAM module parameter definition
//    
// Revision  : V1.0
// Additional Comments :  
// 
////////////////////////////////////////////////////////////////////////////////

//------------------------------------------------------------------------------
// SDRAM read and write working state parameters
`define W_IDLE    4'd0  // Idle state
`define W_ACTIVE  4'd1  // Line is valid, judge read and write
`define W_TRCD    4'd2  // Row valid wait
/*************************************************************/
`define W_READ    4'd3  // Read data status
`define W_CL      4'd4  // Waiting incubation period
`define W_RD      4'd5  // Read data
`define W_RWAIT   4'd6  // Precharge wait state after read completion
/*************************************************************/
`define W_WRITE   4'd7  // Write data status
`define W_WD      4'd8  // Write data
`define W_TDAL    4'd9  // Waiting to write data and self-refresh is over
/*************************************************************/
`define W_AR      4'd10  // Self-refresh
`define W_TRFC    4'd11  // Self refresh wait

// SDRAM initialization status parameters
`define I_NOP     4'd0  // Wait for the end of the 200us stable period of power-on
`define I_PRE     4'd1  // Precharge state
`define I_TRP     4'd2  // Wait for precharge to complete tRP
`define I_AR1     4'd3  // 1st self-refresh
`define I_TRF1    4'd4  // Wait for the first self-refresh to end tRFC
`define I_AR2     4'd5  // 2nd self-refresh
`define I_TRF2    4'd6  // Wait for the second self-refresh to end tRFC
`define I_MRS     4'd7  // Mode register settings
`define I_TMRD    4'd8  // Wait for mode register setting to complete tMRD
`define I_DONE    4'd9  // Loading finished

// Delay parameter
`define end_trp      cnt_clk_r == TRP_CLK
`define end_trfc     cnt_clk_r == TRFC_CLK
`define end_tmrd     cnt_clk_r == TMRD_CLK
`define end_trcd     cnt_clk_r == TRCD_CLK-1
`define end_tcl      cnt_clk_r == TCL_CLK-1
`define end_rdburst  cnt_clk   == sdrd_byte-4 // TREAD_CLK-4  // Issue a burst read interrupt command
`define end_tread    cnt_clk_r == sdrd_byte+2 // TREAD_CLK+2  // TREAD_CLK+2
`define end_wrburst  cnt_clk   == sdwr_byte-1 // TWRITE_CLK-1 // Issue a burst write interrupt command
`define end_twrite   cnt_clk_r == sdwr_byte-1 // TWRITE_CLK-1
`define end_tdal     cnt_clk_r == TDAL_CLK
`define end_trwait   cnt_clk_r == TRP_CLK

// SDRAM control signal command
`define CMD_INIT     5'b01111 // Power-on initialization command port
`define CMD_NOP      5'b10111 // NOP COMMAND
`define CMD_ACTIVE   5'b10011 // ACTIVE COMMAND
`define CMD_READ     5'b10101 // READ COMMAND
`define CMD_WRITE    5'b10100 // WRITE COMMAND
`define CMD_B_STOP   5'b10110 // BURST STOP
`define CMD_PRGE     5'b10010 // PRECHARGE
`define CMD_A_REF    5'b10001 // AUTO REFRESH
`define CMD_LMR      5'b10000 // LODE MODE REGISTER

