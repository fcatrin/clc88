module sdram_test(
   input clk50,
	input reset_n,

	//sdram control
	output			S_CLK,		//sdram clock
	output			S_CKE,		//sdram clock enable
	output			S_NCS,		//sdram chip select
	output			S_NWE,		//sdram write enable
	output			S_NCAS,	   //sdram column address strobe
	output			S_NRAS,	   //sdram row address strobe
	output [1:0] 	S_DQM,		//sdram data enable
	output [1:0]	S_BA,		   //sdram bank address
	output [12:0]	S_A,		   //sdram address
	inout	[15:0]	S_DB		   //sdram data

    );

assign S_DQM = 2'b11;
assign S_CLK = sys_clk;

//PLL时钟
wire sys_rst_n;
system_ctrl	u_system_ctrl
(
	.clk				   (clk50),		//global clock  50MHZ
	.rst_n				(reset_n),		//external reset

	.sys_rst_n			(sys_rst_n),	//global reset
	.pll_locked(pll1_locked)
);


/*******************************/
//SDRAM读写测试程序
/*******************************/
reg [3:0] i;
reg [8:0] counter;

reg             sdram_wr_req;           //sdram burst写请求
reg             sdram_rd_req;           //sdram burst读请求
wire            sdram_wr_ack;           //sdram burst写应答
wire            sdram_rd_ack;           //sdram burst读应答
reg		[8:0]	 wr_length;			       //user interface sdram write burst length
reg		[8:0]	 rd_length;			       //user interface sdram read burst length
reg		[22:0] wr_addr;			       //user interface sdram start write address
reg		[22:0] rd_addr;			       //user interface sdram start read address
reg	   [15:0] sdram_din;					 //user interface sdram data input
wire	   [15:0] sdram_dout;				 //user interface sdram data output
wire				 sdram_init_done;	       //sdram init done



always @ ( negedge sys_clk )
begin
    if( !sys_rst_n ) begin
			i <= 4'd0;
			counter <= 0;
			wr_length <= 9'd0;
			rd_length <= 9'd0;
         sdram_wr_req <= 1'b0;
         sdram_rd_req <= 1'b0;
         wr_addr <= 23'd0;
         rd_addr <= 23'd0;
         sdram_din <= 16'd0;
	 end
	 else
	     case( i )
	      4'd0://等待SDRAM初始化完成
			if( sdram_init_done ) begin i<=i+1'b1; end
			else begin i<=4'd0; end

	      4'd1: begin//发送burst写命令，写512个数据到Sdram地址0
			   sdram_wr_req<=1'b1;
            wr_addr<=23'd0;
			   wr_length<=9'd256;
		      sdram_din<=16'd0;
			   i<=i+1'b1;
	      end

			4'd2: //等待burst写的应答信号
			if( sdram_wr_ack==1'b1) begin i<=i+1'b1; counter<=counter+1'b1; end
			else begin  i<=i; end

	      4'd3: begin//写256个数据到SDRAM,数据加1
				sdram_wr_req<=1'b0;
				if( counter==9'd256 ) begin i <= i + 1'b1; counter <= 9'd0; sdram_din <=sdram_din+1'b1;end
				else if (sdram_wr_ack==1'b1)begin sdram_din <=sdram_din+1'b1; counter<=counter+1'b1; i<=i; end
				else begin sdram_din<=sdram_din; counter<=counter; i<= i; end //保持
         end

			4'd4: begin//发送burst读命令，从Sdram地址0读256个数据到Sdram地址0
			   sdram_rd_req<=1'b1;
            rd_addr<=23'd0;
			   rd_length<=9'd256;
				i<=i+1'b1;
	      end

			4'd5: //等待burst读的应答信号
			if( sdram_rd_ack==1'b1 ) begin i<=i+1'b1; sdram_rd_req<=1'b0; counter<=counter+1'b1;end
			else begin  i<=i; end

			4'd6: //从SDRAM读256个数据
			if( counter==9'd256 ) begin i<=i+1'b1; counter<=9'd0;end
			else if (sdram_rd_ack==1'b1)begin  counter<=counter+1'b1; i <= i;end
			else begin counter<=counter; i<= i; end //保持

			4'd7: //finish
			i<=i;

	      endcase
end

wire[22:0] sdram_wraddr = wr_addr;
wire[22:0] sdram_rdaddr = rd_addr;

//SDR读写控制部分
//----------------------------------------------
sdram_top		u_sdramtop
(
	//global clock
	.clk				   (sys_clk),			//sdram reference clock
	.rst_n				(sys_rst_n),			//global reset

	//internal interface
	.sdram_wr_req		(sdram_wr_req), 	//sdram write request
	.sdram_rd_req		(sdram_rd_req), 	//sdram write ack
	.sdram_wr_ack		(sdram_wr_ack), 	//sdram read request
	.sdram_rd_ack		(sdram_rd_ack),		//sdram read ack
	.sys_wraddr			(sdram_wraddr), 	//sdram write address
	.sys_rdaddr			(sdram_rdaddr), 	//sdram read address
	.sys_data_in		(sdram_din),    	//fifo 2 sdram data input
	.sys_data_out		(sdram_dout),   	//sdram 2 fifo data input
	.sdram_init_done	(sdram_init_done),	//sdram init done

	//burst length
	.sdwr_byte			(wr_length),		//sdram write burst length
	.sdrd_byte			(rd_length),		//sdram read burst length

	//sdram interface
//	.sdram_clk			(sdram_clk),		//sdram clock
	.sdram_cke			(S_CKE),		//sdram clock enable
	.sdram_cs_n			(S_NCS),		//sdram chip select
	.sdram_we_n			(S_NWE),		//sdram write enable
	.sdram_ras_n		(S_NRAS),		//sdram column address strobe
	.sdram_cas_n		(S_NCAS),		//sdram row address strobe
	.sdram_ba			(S_BA),			//sdram data enable (H:8)
	.sdram_addr			(S_A),		//sdram data enable (L:8)
	.sdram_data			(S_DB)		//sdram bank address
//	.sdram_udqm			(sdram_udqm),		//sdram address
//	.sdram_ldqm			(sdram_ldqm)		//sdram data
);

wire sys_clk;
wire pll1_locked;
wire CLK_OUT1;
wire CLK_OUT2;

   pll1 pll1_inst (
      .inclk0(clk50),      // IN
      .c0(sys_clk),      // 100Mhz    (system)
      .c1(CLK_OUT1),     // 25.17Mhz  (640x480)
      .c2(CLK_OUT2),     // 40Mhz     (800x600)
      .areset(1'b0),
      .locked(pll1_locked)
   );



endmodule