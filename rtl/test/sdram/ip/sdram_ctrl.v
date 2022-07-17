`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Description	: SDRAM state control module
//                SDRAM initialization and timing refresh, read and write control
// Revision		: V1.0
// Additional Comments	:  
// 
////////////////////////////////////////////////////////////////////////////////
module sdram_ctrl(
    clk,
    rst_n,
    // sdram_udqm,
    // sdram_ldqm,
    sdram_wr_req,
    sdram_rd_req,
    sdwr_byte,
    sdrd_byte,
    sdram_wr_ack,
    sdram_rd_ack,
    // sdram_busy,
    sdram_init_done,
    init_state,
    work_state,
    cnt_clk,
    sys_r_wn
    );

// System signal interface
input clk;   // System clock, 100MHz
input rst_n; // Reset signal, active low

// SDRAM hardware interface
// output sdram_udqm;	// SDRAM high byte mask
// output sdram_ldqm;	// SDRAM low byte mask

// SDRAM package interface
input      sdram_wr_req; // System write SDRAM request signal
input      sdram_rd_req; // System read SDRAM request signal
input[8:0] sdwr_byte;    // Burst write SDRAM bytes (1-256)
input[8:0] sdrd_byte;    // Burst read SDRAM bytes (1-256)
output     sdram_wr_ack; // The system writes the SDRAM response signal as the output valid signal of wrFIFO
output     sdram_rd_ack; // System read SDRAM response signal

output	sdram_init_done; // System initialization complete signal
// output sdram_busy;    // SDRAM busy flag, high means busy

// SDRAM internal interface
output[3:0] init_state;	 // SDRAM initialization register
output[3:0] work_state;	 // SDRAM working status register
output[8:0] cnt_clk;     // clock count
output      sys_r_wn;    // SDRAM read/write control signal

wire done_200us;         // 200us input stable period end flag after power-on
// wire sdram_init_done; // SDRAM initialization complete flag, high indicates completion
wire sdram_busy;         // SDRAM busy flag, high indicates that SDRAM is working
reg  sdram_ref_req;      // SDRAM self-refresh request signal
wire sdram_ref_ack;      // SDRAM self-refresh request response signal

`include "sdram_para.v"	 // Contains SDRAM parameter definition module

// SDRAM timing delay parameters
parameter TRP_CLK       = 9'd4,//1,   // TRP=18ns precharge effective period
          TRFC_CLK	    = 9'd6,//3,   // TRC=60ns automatic pre-refresh cycle
          TMRD_CLK	    = 9'd6,//2,   // The mode register sets the wait clock cycle
          TRCD_CLK	    = 9'd2,//1,   // TRCD=18ns row strobe period
          TCL_CLK       = 9'd3,       // Latency TCL_CLK=3 CLKs, which can be set in the initialization mode register
          // TREAD_CLK  = 9'd256,//8, // Burst read data cycle 8CLK
          // TWRITE_CLK = 9'd256,//8, // Burst write data 8CLK
          TDAL_CLK      = 9'd3;	      // write wait

//------------------------------------------------------------------------------
// assign sdram_udqm = 1'b0; // SDRAM data high byte valid
// assign sdram_ldqm = 1'b0; // SDRAM data low byte valid

//------------------------------------------------------------------------------
// 200us timing after power-on, when the timing is up, done_200us=1
//------------------------------------------------------------------------------
reg[14:0] cnt_200us; 
always @ (posedge clk or negedge rst_n) 
    if (!rst_n)
        cnt_200us <= 15'd0;
    else if (cnt_200us < 15'd20_000)
        cnt_200us <= cnt_200us + 1'b1;

assign done_200us = (cnt_200us == 15'd20_000);

//------------------------------------------------------------------------------
// SDRAM initialization operation state machine
//------------------------------------------------------------------------------
reg[3:0] init_state_r;	// SDRAM initialization status

always @ (posedge clk or negedge rst_n)
    if (!rst_n)
        init_state_r <= `I_NOP;
    else case (init_state_r)
        `I_NOP:  init_state_r <= done_200us ? `I_PRE:`I_NOP;    // After 200us after power-on reset, it will enter the next state
        `I_PRE:  init_state_r <= `I_TRP;                        // Precharge state
        `I_TRP:  init_state_r <= (`end_trp) ? `I_AR1:`I_TRP;    // Precharge waits for TRP_CLK clock cycles
        `I_AR1:  init_state_r <= `I_TRF1;                       // 1st self-refresh
        `I_TRF1: init_state_r <= (`end_trfc) ? `I_AR2:`I_TRF1;  // Wait for the end of the first self-refresh, TRFC_CLK clock cycles
        `I_AR2:  init_state_r <= `I_TRF2;                       // 2nd self-refresh
        `I_TRF2: init_state_r <= (`end_trfc) ? `I_MRS:`I_TRF2;  // Wait for the end of the second self-refresh, TRFC_CLK clock cycles
        `I_MRS:  init_state_r <= `I_TMRD;                       // Mode Register Set (MRS)
        `I_TMRD: init_state_r <= (`end_tmrd) ? `I_DONE:`I_TMRD; // Wait for the mode register setting to complete, TMRD_CLK clock cycles
        `I_DONE: init_state_r <= `I_DONE;                       // SDRAM initialization set complete flag
        default: init_state_r <= `I_NOP;
    endcase

assign init_state = init_state_r;
assign sdram_init_done = (init_state_r == `I_DONE);		// SDRAM initialization complete flag

//------------------------------------------------------------------------------
// 7.5us timing, self-refresh every 64ms for all 8,192 rows of memory
// ( The upper limit of the valid data retention period of the capacitor in the memory bank is 64ms )
//------------------------------------------------------------------------------	 
reg[10:0] cnt_7_5us;
always @ (posedge clk or negedge rst_n)
    if (!rst_n)
        cnt_7_5us <= 11'd0;
    else if (cnt_7_5us < 11'd749)
        cnt_7_5us <= cnt_7_5us+1'b1; // 60ms(64ms) / 8192 = 7.5us loop count
    else
        cnt_7_5us <= 11'd0;

always @ (posedge clk or negedge rst_n)
	if (!rst_n)
	    sdram_ref_req <= 1'b0;
	else if (cnt_7_5us == 11'd749)
	    sdram_ref_req <= 1'b1;       // Generate self-refresh request
	else if (sdram_ref_ack)
	    sdram_ref_req <= 1'b0;       // Responded to self-refresh

//------------------------------------------------------------------------------
// SDRAM read and write and self-refresh operation state machine
//------------------------------------------------------------------------------
reg[3:0] work_state_r;	// SDRAM read and write status
reg sys_r_wn;			// SDRAM read/write control signal

always @ (posedge clk or negedge rst_n) begin
    if (!rst_n)
        work_state_r <= `W_IDLE;
    else case (work_state_r)
        // Initialize idle state
        `W_IDLE: if (sdram_ref_req & sdram_init_done) begin
                work_state_r <= `W_AR; // Timed self-refresh request
                sys_r_wn <= 1'b1;
            end else if (sdram_wr_req & sdram_init_done) begin
                work_state_r <= `W_ACTIVE;  // write SDRAM
                sys_r_wn <= 1'b0;
            end else if (sdram_rd_req && sdram_init_done) begin
                work_state_r <= `W_ACTIVE;  // read SDRAM
                sys_r_wn <= 1'b1;
            end else begin
                work_state_r <= `W_IDLE;
                sys_r_wn <= 1'b1;
            end
		// row valid status
        `W_ACTIVE:
            if (TRCD_CLK == 0)
                if (sys_r_wn) work_state_r <= `W_READ;
                else          work_state_r <= `W_WRITE;
            else              work_state_r <= `W_TRCD;

		// row valid wait
        `W_TRCD:
            if (`end_trcd)
                if (sys_r_wn) work_state_r <= `W_READ;
                else          work_state_r <= `W_WRITE;
            else              work_state_r <= `W_TRCD;
					
        // read data status
        `W_READ:    work_state_r <= `W_CL;
        // waiting incubation period
        `W_CL:      work_state_r <= (`end_tcl) ? `W_RD:`W_CL;
        // read data
        `W_RD:      work_state_r <= (`end_tread) ? `W_IDLE:`W_RD;
        // Precharge wait state after read completion
        `W_RWAIT:   work_state_r <= (`end_trwait) ? `W_IDLE:`W_RWAIT;
		
		// write data status
        `W_WRITE:   work_state_r <= `W_WD;
        // write data
        `W_WD:      work_state_r <= (`end_twrite) ? `W_TDAL:`W_WD;
        // Waiting to write data and self-refresh is over
        `W_TDAL:    work_state_r <= (`end_tdal) ? `W_IDLE:`W_TDAL;
		
        // Auto refresh status
        `W_AR:      work_state_r <= `W_TRFC;
        // Self refresh wait
        `W_TRFC:    work_state_r <= (`end_trfc) ? `W_IDLE:`W_TRFC;
        /*************************************************************/
        default:    work_state_r <= `W_IDLE;
    endcase
end

assign work_state    = work_state_r;               // SDRAM working status register
assign sdram_ref_ack = (work_state_r == `W_AR); // SDRAM self-refresh response signal

// One clock ahead to write
// Write SDRAM response signal
assign sdram_wr_ack = ((work_state == `W_TRCD) & ~sys_r_wn) |
                      (work_state == `W_WRITE)|
                      ((work_state == `W_WD) & (cnt_clk_r < sdwr_byte -2'd2));
// Read SDRAM response signal
assign sdram_rd_ack = (work_state_r == `W_RD) &
                      (cnt_clk_r >= 9'd1) & (cnt_clk_r < sdrd_byte + 2'd1);

// assign sdram_busy = (sdram_init_done && work_state_r == `W_IDLE) ? 1'b0:1'b1;	// SDRAM busy flag

//------------------------------------------------------------------------------
// Generate delays for SDRAM sequential operations
//------------------------------------------------------------------------------
reg[8:0] cnt_clk_r; // clock count
reg      cnt_rst_n; // Clock count reset signal

always @ (posedge clk or negedge rst_n) 
    if (!rst_n)
        cnt_clk_r <= 9'd0;             // count register reset
    else if (!cnt_rst_n)
        cnt_clk_r <= 9'd0;             // Clear the count register
    else
        cnt_clk_r <= cnt_clk_r + 1'b1; // Start count delay
	
assign cnt_clk = cnt_clk_r;	// Count register is exported, used in internal `define

// Counter Control Logic
always @ (init_state_r or work_state_r or cnt_clk_r or sdwr_byte or sdrd_byte) begin
    case (init_state_r)
        `I_NOP:	 cnt_rst_n <= 1'b0;
        `I_PRE:	 cnt_rst_n <= 1'b1;                      // Precharge delay count start
        `I_TRP:	 cnt_rst_n <= (`end_trp) ? 1'b0 : 1'b1;  // After waiting for the end of the precharge delay count, clear the counter
        `I_AR1,`I_AR2:
                 cnt_rst_n <= 1'b1;                      // Self-refresh delay count start
        `I_TRF1,`I_TRF2:
                 cnt_rst_n <= (`end_trfc) ? 1'b0 : 1'b1; // After waiting for the self-refresh delay count to end, clear the counter
        `I_MRS:	 cnt_rst_n <= 1'b1;                      // Mode register setting delay count start
        `I_TMRD: cnt_rst_n <= (`end_tmrd) ? 1'b0 : 1'b1; // After waiting for the self-refresh delay count to end, clear the counter
        `I_DONE: case (work_state_r)
            `W_IDLE:	cnt_rst_n <= 1'b0;
            `W_ACTIVE: 	cnt_rst_n <= 1'b1;
            `W_TRCD:	cnt_rst_n <= (`end_trcd)   ? 1'b0 : 1'b1;
            `W_CL:		cnt_rst_n <= (`end_tcl)    ? 1'b0 : 1'b1;
            `W_RD:		cnt_rst_n <= (`end_tread)  ? 1'b0 : 1'b1;
            `W_RWAIT:	cnt_rst_n <= (`end_trwait) ? 1'b0 : 1'b1;
            `W_WD:		cnt_rst_n <= (`end_twrite) ? 1'b0 : 1'b1;
            `W_TDAL:	cnt_rst_n <= (`end_tdal)   ? 1'b0 : 1'b1;
            `W_TRFC:	cnt_rst_n <= (`end_trfc)   ? 1'b0 : 1'b1;
            default:    cnt_rst_n <= 1'b0;
        endcase
		default: cnt_rst_n <= 1'b0;
    endcase
end

endmodule
