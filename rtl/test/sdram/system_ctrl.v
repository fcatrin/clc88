/*-------------------------------------------------------------------------
Description			:		generate system reset and clock for sdram.
===========================================================================
15/02/1
--------------------------------------------------------------------------*/
`timescale 1 ns / 1 ns
module system_ctrl (
    input  clk,        // 50MHz
    input  rst_n,      // global reset
    input  pll_locked,
    output sys_rst_n   // system reset
);

//----------------------------------------------
reg  [21:0]   delay_cnt;
reg  delay_done;
always @(posedge clk) begin
    if(!rst_n || !pll_locked) begin
        delay_cnt <= 0;
        delay_done <= 1'b0;
    end else if (delay_cnt== 22'd4000000)
        delay_done <= 1'b1;
    else
        delay_cnt <= delay_cnt +1'b1;
end

assign sys_rst_n = delay_done;

endmodule
