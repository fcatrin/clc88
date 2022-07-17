/*-------------------------------------------------------------------------
Description			:		generate system reset and clock for sdram.
===========================================================================
15/02/1
--------------------------------------------------------------------------*/
`timescale 1 ns / 1 ns
module system_ctrl
(
	input 		clk,		//50MHz
	input 		rst_n,		//global reset

	output 		sys_rst_n,	//system reset
	output 		clk_c0,		
	output 		clk_c1,
	output		clk_c2,	   //sdram clock1 0 degree
	output		clk_c3	   //sdram clock2 0 degree
);

//----------------------------------------------
reg  [21:0]   delay_cnt;
reg  delay_done;
always @(posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		delay_cnt <= 0;
		delay_done <= 1'b0;
		end
	else
		begin
		  if (delay_cnt== 22'd2000000)
			 delay_done <= 1'b1;
        else
          delay_cnt <= delay_cnt +1'b1;
		end
end

assign sys_rst_n=delay_done;
//----------------------------------------------
//Component instantiation
wire 	pll1_locked;

   pll1 pll1_inst (
      .inclk0(clk),      // IN
      .c0(sys_clk),      // 100Mhz    (system)
      .c1(CLK_OUT1),     // 25.17Mhz  (640x480)
      .c2(CLK_OUT2),     // 40Mhz     (800x600)
      .areset(1'b0),
      .locked(pll1_locked)
   );


endmodule
