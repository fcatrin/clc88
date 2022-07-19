`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Description	: SDRAM command module
////////////////////////////////////////////////////////////////////////////////

module sdram_cmd (
    // System signals
    input clk,                  // System clock, 100MHz
    input rst_n,                // Reset signal, active low

    // SDRAM hardware interface
    output       sdram_cke,     // SDRAM clock valid signal
    output       sdram_cs_n,    // SDRAM chip select signal
    output       sdram_ras_n,   // SDRAM row address strobe
    output       sdram_cas_n,   // SDRAM column address strobe
    output       sdram_we_n,    // SDRAM write enable bit
    output [1:0] sdram_ba,      // L-Bank address line of SDRAM
    output[12:0] sdram_addr,    // SDRAM address bus

    // SDRAM package interface
    input[22:0] sys_wraddr,	    // Address register when writing SDRAM
    input[22:0] sys_rdaddr,	    // Address register when reading from SDRAM
    input [8:0] sdwr_byte,	    // Burst write SDRAM bytes (1-256)
    input [8:0] sdrd_byte,	    // Burst read SDRAM bytes (1-256)

    // SDRAM internal interface
    input [3:0] init_state,	    // SDRAM initialization status register
    input [3:0] work_state,	    // SDRAM read and write status register
    input       sys_r_wn,       // SDRAM read/write control signal
    input [8:0] cnt_clk         // clock count
    );

`include "sdram_para.v" // Contains SDRAM parameter definition module

//-------------------------------------------------------------------------------
reg [4:0] sdram_cmd_r; // SDRAM Operation Commands
reg [1:0] sdram_ba_r;
reg[12:0] sdram_addr_r;

assign {sdram_cke, sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} = sdram_cmd_r;
assign sdram_ba   = sdram_ba_r;
assign sdram_addr = sdram_addr_r;

//-------------------------------------------------------------------------------
// SDRAM command parameter assignment
wire[22:0] sys_addr; // Address register when reading and writing SDRAM, (bit22-21) L-Bank address: (bit20-8) is the row address, (bit7-0) is the column address
assign sys_addr = sys_r_wn ? sys_rdaddr : sys_wraddr; // Read/Write Address Bus Switch Control
	
always @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sdram_cmd_r  <= `CMD_INIT;
        sdram_ba_r   <= 2'b11;
        sdram_addr_r <= 13'h1fff;
    end else case (init_state)
        `I_NOP,`I_TRP,`I_TRF1,`I_TRF2,`I_TMRD: begin
            sdram_cmd_r  <= `CMD_NOP;
            sdram_ba_r   <= 2'b11;
            sdram_addr_r <= 13'h1fff;
        end
        `I_PRE: begin
            sdram_cmd_r  <= `CMD_PRGE;
            sdram_ba_r   <= 2'b11;
            sdram_addr_r <= 13'h1fff;
        end
        `I_AR1,`I_AR2: begin
            sdram_cmd_r  <= `CMD_A_REF;
            sdram_ba_r   <= 2'b11;
            sdram_addr_r <= 13'h1fff;
        end
        `I_MRS: begin	              // Mode register setting, can be set according to actual needs
            sdram_cmd_r  <= `CMD_LMR;
            sdram_ba_r   <= 2'b00;    // Operation Mode Settings
            sdram_addr_r <= {
                3'b000,  // Operation Mode Settings
                1'b0,    // Operation mode setting (set here as A9=0, that is, burst read/burst write)
                2'b00,   // Operation mode setting ({A8,A7}=00), the current operation is the mode register setting
                3'b011,  // CAS latency setting (set to 3 here, {A6,A5,A4}=011)()
                1'b0,    // Burst transmission mode (set as sequence here, A3=b0)
                3'b011   // Burst length (set to 8 here)
            };
        end
        `I_DONE: case (work_state)
            `W_IDLE,`W_TRCD,`W_CL,`W_TRFC,`W_TDAL: begin
                sdram_cmd_r  <= `CMD_NOP;
                sdram_ba_r   <= 2'b11;
                sdram_addr_r <= 13'h1fff;
            end
            `W_ACTIVE: begin
                sdram_cmd_r  <= `CMD_ACTIVE;
                sdram_ba_r   <= sys_addr[22:21]; // L-Bank address
                sdram_addr_r <= sys_addr[20:8];  // line address
            end
            `W_READ: begin
                sdram_cmd_r  <= `CMD_READ;
                sdram_ba_r   <= sys_addr[22:21]; // L-Bank address
                sdram_addr_r <= {
                    5'b00100,      // A10=1, set write completion to allow precharge
                    sys_addr[7:0]  // column address
                };
            end
            `W_RD: if(`end_rdburst) begin
                sdram_cmd_r  <= `CMD_B_STOP;
            end else begin
                sdram_cmd_r  <= `CMD_NOP;
                sdram_ba_r   <= 2'b11;
                sdram_addr_r <= 13'h1fff;
            end
            `W_WRITE: begin
                sdram_cmd_r  <= `CMD_WRITE;
                sdram_ba_r   <= sys_addr[22:21]; // L-Bank address
                sdram_addr_r <= {
                    5'b00100,      // A10=1, set write completion to allow precharge
                    sys_addr[7:0]  // column address
                };
            end
            `W_WD: if(`end_wrburst) begin
                sdram_cmd_r  <= `CMD_B_STOP;
            end else begin
                sdram_cmd_r  <= `CMD_NOP;
                sdram_ba_r   <= 2'b11;
                sdram_addr_r <= 13'h1fff;
            end
            `W_AR: begin
                sdram_cmd_r  <= `CMD_A_REF;
                sdram_ba_r   <= 2'b11;
                sdram_addr_r <= 13'h1fff;
            end
            default: begin
                sdram_cmd_r  <= `CMD_NOP;
                sdram_ba_r   <= 2'b11;
                sdram_addr_r <= 13'h1fff;
            end
        endcase
        default: begin
            sdram_cmd_r  <= `CMD_NOP;
            sdram_ba_r   <= 2'b11;
            sdram_addr_r <= 13'h1fff;
        end
    endcase
end

endmodule

