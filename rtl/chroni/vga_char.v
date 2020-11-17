`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name:    vga_char 
// Descriptin:     ROM中存储了2个字体，字体大小为56*75,字体显示为单色             
//////////////////////////////////////////////////////////////////////////////////
module vga_char(
			input clk,
			input reset_n,
			output vga_hs,
			output vga_vs,
			output [4:0] vga_r,
			output [5:0] vga_g,
			output [4:0] vga_b

    );
//-----------------------------------------------------------//
// 水平扫描参数的设定1024*768 60Hz VGA
//-----------------------------------------------------------//
//parameter LinePeriod =1344;            //行周期数
//parameter H_SyncPulse=136;             //行同步脉冲（Sync a）
//parameter H_BackPorch=160;             //显示后沿（Back porch b）
//parameter H_ActivePix=1024;            //显示时序段（Display interval c）
//parameter H_FrontPorch=24;             //显示前沿（Front porch d）
//parameter Hde_start=296;
//parameter Hde_end=1320;

//-----------------------------------------------------------//
// 垂直扫描参数的设定1024*768 60Hz VGA
//-----------------------------------------------------------//
//parameter FramePeriod =806;           //列周期数
//parameter V_SyncPulse=6;              //列同步脉冲（Sync o）
//parameter V_BackPorch=29;             //显示后沿（Back porch p）
//parameter V_ActivePix=768;            //显示时序段（Display interval q）
//parameter V_FrontPorch=3;             //显示前沿（Front porch r）
//parameter Vde_start=35;
//parameter Vde_end=803;

//-----------------------------------------------------------//
// 水平扫描参数的设定800*600 VGA
//-----------------------------------------------------------//
parameter LinePeriod =1056;           //行周期数
parameter H_SyncPulse=128;            //行同步脉冲（Sync a）
parameter H_BackPorch=88;             //显示后沿（Back porch b）
parameter H_ActivePix=800;            //显示时序段（Display interval c）
parameter H_FrontPorch=40;            //显示前沿（Front porch d）
parameter Hde_start=216;
parameter Hde_end=1016;

//-----------------------------------------------------------//
// 垂直扫描参数的设定800*600 VGA
//-----------------------------------------------------------//
parameter FramePeriod =628;           //列周期数
parameter V_SyncPulse=4;              //列同步脉冲（Sync o）
parameter V_BackPorch=23;             //显示后沿（Back porch p）
parameter V_ActivePix=600;            //显示时序段（Display interval q）
parameter V_FrontPorch=1;             //显示前沿（Front porch r）
parameter Vde_start=27;
parameter Vde_end=627;

  reg[10 : 0] x_cnt;
  reg[9 : 0]  y_cnt;
  reg hsync_r;
  reg vsync_r; 
  reg hsync_de;
  reg vsync_de;
  
  
  wire vga_clk;
  wire CLK_OUT1;
  wire CLK_OUT2;
  wire CLK_OUT3;
  wire CLK_OUT4; 
  
parameter	Pos_X1	=	500;        //第一个字在VGA上显示的X坐标
parameter	Pos_Y1	=	300;        //第一个字在VGA上显示的Y坐标

parameter	Pos_X2	=	650;        //第二个字在VGA上显示的X坐标
parameter	Pos_Y2	=	300;        //第二个字在VGA上显示的Y坐标
 
//----------------------------------------------------------------
////////// 水平扫描计数
//----------------------------------------------------------------
always @ (posedge vga_clk)
       if(~reset_n)    x_cnt <= 1;
       else if(x_cnt == LinePeriod) x_cnt <= 1;
       else x_cnt <= x_cnt+ 1;
		 
//----------------------------------------------------------------
////////// 水平扫描信号hsync,hsync_de产生
//----------------------------------------------------------------
always @ (posedge vga_clk)
   begin
       if(~reset_n) hsync_r <= 1'b1;
       else if(x_cnt == 1) hsync_r <= 1'b0;            //产生hsync信号
       else if(x_cnt == H_SyncPulse) hsync_r <= 1'b1;
		 
		 		 
	    if(1'b0) hsync_de <= 1'b0;
       else if(x_cnt == Hde_start) hsync_de <= 1'b1;    //产生hsync_de信号
       else if(x_cnt == Hde_end) hsync_de <= 1'b0;	
	end

//----------------------------------------------------------------
////////// 垂直扫描计数
//----------------------------------------------------------------
always @ (posedge vga_clk)
       if(~reset_n) y_cnt <= 1;
       else if(y_cnt == FramePeriod) y_cnt <= 1;
       else if(x_cnt == LinePeriod) y_cnt <= y_cnt+1;

//----------------------------------------------------------------
////////// 垂直扫描信号vsync, vsync_de产生
//----------------------------------------------------------------
always @ (posedge vga_clk)
  begin
       if(~reset_n) vsync_r <= 1'b1;
       else if(y_cnt == 1) vsync_r <= 1'b0;    //产生vsync信号
       else if(y_cnt == V_SyncPulse) vsync_r <= 1'b1;
		 
	    if(1'b0) vsync_de <= 1'b0;
       else if(y_cnt == Vde_start) vsync_de <= 1'b1;    //产生vsync_de信号
       else if(y_cnt == Vde_end) vsync_de <= 1'b0;	 
  end	 

//----------------------------------------------------------------
////////// ROM读字地址产生模块
//----------------------------------------------------------------
reg[4:0] x1_count;
reg[4:0] x2_count;
reg[10:0] word1_rom_addra;
reg[10:0] word2_rom_addra;
wire y_word1;
wire x_word1;
wire y_word2;
wire x_word2;
wire pre_x_word1;
wire pre_x_word2;

assign x_word1=(x_cnt >= Pos_X1 && x_cnt < Pos_X1 + 56) ? 1'b1 : 1'b0;        //第一个字体的X坐标的位置显示范围,字体宽度为56
assign y_word1=(y_cnt >= Pos_Y1 && y_cnt < Pos_Y1 + 75) ? 1'b1 : 1'b0;        //第一个字体的Y坐标的位置显示范围,字体高度为75
assign pre_x_word1=(x_cnt >= Pos_X1 - 2 && x_cnt < Pos_X1 + 54) ? 1'b1 : 1'b0;//提前2个时钟准备数据（ROM的数据输出延迟地址2个时钟周期）

assign x_word2=(x_cnt >= Pos_X2 && x_cnt < Pos_X2 + 56) ? 1'b1 : 1'b0;              //第二个字体的X坐标的位置显示范围,字体宽度为56
assign y_word2=(y_cnt >= Pos_Y2 && y_cnt < Pos_Y2 + 75) ? 1'b1 : 1'b0;              //第二个字体的Y坐标的位置显示范围,字体高度为75
assign pre_x_word2=(x_cnt >= Pos_X2 - 2 && x_cnt < Pos_X2 + 54) ? 1'b1 : 1'b0;      //提前2个时钟准备数据（ROM的数据输出延迟地址2个时钟周期）

 always @(posedge vga_clk)
   begin
	  if (~reset_n) begin
		  x1_count<=0;
		  x2_count<=0;	
		  word1_rom_addra<=0;              //第一个字体在ROM中的位置
		  word2_rom_addra<=525;            //第二个字体在ROM中的位置
	  end
	  else begin
		  if (vsync_r==1'b0) begin
		     word1_rom_addra<=0;             //第一个字体在ROM中的位置
			  word2_rom_addra<=525;           //第二个字体在ROM中的位置
			  x1_count<=0;
			  x2_count<=0;				  
        end
		  else if((y_word1==1'b1) && (pre_x_word1==1'b1)) begin //读第一个字体，提前2个时钟产生地址
			   if (x1_count==7) begin                        //ROM里的每个字节显示8个像数，8个时钟ROM地址加1
              word1_rom_addra<=word1_rom_addra+1'b1;          //ROM地址加1
				  x1_count<=0;
				end
            else begin
					x1_count<=x1_count+1'b1;
					word1_rom_addra<=word1_rom_addra;				  
				end
        end
		  else if((y_word2==1'b1) && (pre_x_word2==1'b1)) begin //读第二个字体，提前2个时钟产生地址
			   if (x2_count==7) begin                        //ROM里的每个字节显示8个像数，8个时钟ROM地址加1
              word2_rom_addra<=word2_rom_addra+1'b1;          //ROM地址加1
				  x2_count<=0;
				end
            else begin
					x2_count<=x2_count+1'b1;
					word2_rom_addra<=word2_rom_addra;				  
				end
        end		  
        else begin
			  x1_count<=0;
			  x2_count<=0;
			  word1_rom_addra<=word1_rom_addra;	
			  word2_rom_addra<=word2_rom_addra;	
		  end	  
		end	  
  end     

 
//----------------------------------------------------------------
////////// 延迟2个节拍,因为ROM的数据输出延迟地址2个时钟周期
//---------------------------------------------------------------- 
reg [4:0] x1_bit_count;
reg [4:0] x2_bit_count;             


 always @(posedge vga_clk)
   begin
	  if (~reset_n) begin
		  x1_bit_count<=7;
		  x2_bit_count<=7;	
	  end
	  else begin
		  if (vsync_r==1'b0) begin
		     x1_bit_count<=7;
			  x2_bit_count<=7;  
        end
		  else if((y_word1==1'b1) && (x_word1==1'b1)) begin //读第一个字体，提前2个时钟产生地址
			   if (x1_bit_count==0)      
				  x1_bit_count<=7;
            else 
					x1_bit_count<=x1_bit_count-1'b1;
        end
		  else if((y_word2==1'b1) && (x_word2==1'b1)) begin //读第二个字体，提前2个时钟产生地址
			   if (x2_bit_count==0)                        //ROM里的每个字节显示8个像数，8个时钟ROM地址加1
				  x2_bit_count<=7;
            else 
					x2_bit_count<=x2_bit_count-1'b1;
        end		  
        else begin
			  x1_bit_count<=7;
			  x2_bit_count<=7;
		  end	  
		end	  
  end 
 
 
//----------------------------------------------------------------
////////// VGA数据输出
//---------------------------------------------------------------- 
wire [4:0] vga_r_reg;
wire [4:0] vga_r_word1;
wire [4:0] vga_r_word2;
assign vga_r_word1 = {5{rom_data[x1_bit_count]}};                 //显示单色的数据1
assign vga_r_word2 = {5{rom_data[x2_bit_count]}};                 //显示单色的数据2
assign vga_r_reg = (x_word1==1'b1) ?  vga_r_word1 : vga_r_word2;
  
//----------------------------------------------------------------
////////// ROM实例化
//----------------------------------------------------------------	
wire [10:0] rom_addra;
wire [7:0] rom_data;
assign rom_addra=(x_word1==1'b1) ? word1_rom_addra : word2_rom_addra; //rom的地址选择          

	rom rom_inst (
	  .clock(vga_clk), // input clka
	  .address(rom_addra), // input [10 : 0] addra
	  .q(rom_data) // output [7 : 0] douta
	);
	
	
  assign vga_hs = hsync_r;
  assign vga_vs = vsync_r;  
  assign vga_r = (((y_word1==1'b1) && (x_word1==1'b1)) | ((y_word2==1'b1) && (x_word2==1'b1))) ? vga_r_reg:5'b00000;
  assign vga_g = (hsync_de & vsync_de) ? 6'b00011 : 6'b000000;
  assign vga_b = (hsync_de & vsync_de) ? 5'b00011 : 5'b00000;
  assign vga_clk = CLK_OUT2;  //VGA时钟频率选择40Mhz
  
  
   pll pll_inst
  (// Clock in ports
   .inclk0(clk),      // IN
   .c0(CLK_OUT1),     // 21.175Mhz for 640x480(60hz)
   .c1(CLK_OUT2),     // 40.0Mhz for 800x600(60hz)
   .c2(CLK_OUT3),     // 65.0Mhz for 1024x768(60hz)
   .c3(CLK_OUT4),     // 108.0Mhz for 1280x1024(60hz)
   .areset(1'b0),               // reset input 
   .locked(LOCKED));        // OUT
// INST_TAG_END ------ End INSTANTIATI 


 
endmodule

