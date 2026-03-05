`include "define.v"

module ysyx_25060170_regfile (
    input    wire             					 clk   ,
    input    wire             					 rst   ,

    input    wire   [`ysyx_25060170_REGADDR]     waddr ,
    input    wire   [`ysyx_25060170_REG]    	 wdata ,
    input    wire             				     wen   ,
   
	input    wire   [`ysyx_25060170_REGADDR]	 raddr1,
	output	 wire   [`ysyx_25060170_REG]	  	 rdata1,
	input	 wire             					 ren1  ,

	input    wire   [`ysyx_25060170_REGADDR]	 raddr2,
	output	 wire   [`ysyx_25060170_REG]	  	 rdata2,
	input	 wire             					 ren2  ,

	//to dpi-c for difftest
	output  wire	[`ysyx_25060170_REG]		 regs0 ,
	output  wire	[`ysyx_25060170_REG]		 regs1 ,
	output  wire	[`ysyx_25060170_REG]		 regs2 ,
	output  wire	[`ysyx_25060170_REG]		 regs3 ,
	output  wire	[`ysyx_25060170_REG]		 regs4 ,
	output  wire	[`ysyx_25060170_REG]		 regs5 ,
	output  wire	[`ysyx_25060170_REG]		 regs6 ,
	output  wire	[`ysyx_25060170_REG]		 regs7 ,
	output  wire	[`ysyx_25060170_REG]		 regs8 ,
	output  wire	[`ysyx_25060170_REG]		 regs9 ,
	output  wire	[`ysyx_25060170_REG]		 regs10,
	output  wire	[`ysyx_25060170_REG]		 regs11,
	output  wire	[`ysyx_25060170_REG]		 regs12,
	output  wire	[`ysyx_25060170_REG]		 regs13,
	output  wire	[`ysyx_25060170_REG]		 regs14,
	output  wire	[`ysyx_25060170_REG]		 regs15,
	output  wire	[`ysyx_25060170_REG]		 regs16,
	output  wire	[`ysyx_25060170_REG]		 regs17,
	output  wire	[`ysyx_25060170_REG]		 regs18,
	output  wire	[`ysyx_25060170_REG]		 regs19,
	output  wire	[`ysyx_25060170_REG]		 regs20,
	output  wire	[`ysyx_25060170_REG]		 regs21,
	output  wire	[`ysyx_25060170_REG]		 regs22,
	output  wire	[`ysyx_25060170_REG]		 regs23,
	output  wire	[`ysyx_25060170_REG]		 regs24,
	output  wire	[`ysyx_25060170_REG]		 regs25,
	output  wire	[`ysyx_25060170_REG]		 regs26,
	output  wire	[`ysyx_25060170_REG]		 regs27,
	output  wire	[`ysyx_25060170_REG]		 regs28,
	output  wire	[`ysyx_25060170_REG]		 regs29,
	output  wire	[`ysyx_25060170_REG]		 regs30,
	output  wire	[`ysyx_25060170_REG]		 regs31
);
 
    reg [`ysyx_25060170_REG] regs [0:31];

 

 
 always@(posedge clk) begin
	 if(rst == `ysyx_25060170_RSTABLE) begin
		regs[0] <= `ysyx_25060170_ZERO32; 
 		regs[1] <= `ysyx_25060170_ZERO32; 
 		regs[2] <= `ysyx_25060170_ZERO32; 
 		regs[3] <= `ysyx_25060170_ZERO32; 
 		regs[4] <= `ysyx_25060170_ZERO32; 
 		regs[5] <= `ysyx_25060170_ZERO32; 
 		regs[6] <= `ysyx_25060170_ZERO32; 
 		regs[7] <= `ysyx_25060170_ZERO32; 
 		regs[8] <= `ysyx_25060170_ZERO32; 
 		regs[9] <= `ysyx_25060170_ZERO32; 
 		regs[10] <= `ysyx_25060170_ZERO32; 
 		regs[11] <= `ysyx_25060170_ZERO32; 
 		regs[12] <= `ysyx_25060170_ZERO32; 
 		regs[13] <= `ysyx_25060170_ZERO32; 
 		regs[14] <= `ysyx_25060170_ZERO32; 
 		regs[15] <= `ysyx_25060170_ZERO32; 
 		regs[16] <= `ysyx_25060170_ZERO32; 
 		regs[17] <= `ysyx_25060170_ZERO32; 
 		regs[18] <= `ysyx_25060170_ZERO32; 
 		regs[19] <= `ysyx_25060170_ZERO32; 
 		regs[20] <= `ysyx_25060170_ZERO32; 
 		regs[21] <= `ysyx_25060170_ZERO32; 
 		regs[22] <= `ysyx_25060170_ZERO32; 
 		regs[23] <= `ysyx_25060170_ZERO32; 
 		regs[24] <= `ysyx_25060170_ZERO32; 
 		regs[25] <= `ysyx_25060170_ZERO32; 
 		regs[26] <= `ysyx_25060170_ZERO32; 
 		regs[27] <= `ysyx_25060170_ZERO32; 
 		regs[28] <= `ysyx_25060170_ZERO32; 
 		regs[29] <= `ysyx_25060170_ZERO32; 
 		regs[30] <= `ysyx_25060170_ZERO32; 
 		regs[31] <= `ysyx_25060170_ZERO32;
	 end
   else begin
		 if(wen == `ysyx_25060170_WENABLE && waddr != 5'd0)begin
			 regs[waddr]<=wdata;
		 end
	 end
 end

 assign rdata1 = ((rst != `ysyx_25060170_RSTABLE) && (ren1 == `ysyx_25060170_RENABLE)) ? regs[raddr1] : `ysyx_25060170_ZERO32;
 assign rdata2 = ((rst != `ysyx_25060170_RSTABLE) && (ren2 == `ysyx_25060170_RENABLE)) ? regs[raddr2] : `ysyx_25060170_ZERO32;

assign regs0  = regs[0] ;
assign regs1  = regs[1] ;
assign regs2  = regs[2] ;
assign regs3  = regs[3] ;
assign regs4  = regs[4] ;
assign regs5  = regs[5] ;
assign regs6  = regs[6] ;
assign regs7  = regs[7] ;
assign regs8  = regs[8] ;
assign regs9  = regs[9] ;
assign regs10 = regs[10];
assign regs11 = regs[11];
assign regs12 = regs[12];
assign regs13 = regs[13];
assign regs14 = regs[14];
assign regs15 = regs[15];
assign regs16 = regs[16];
assign regs17 = regs[17];
assign regs18 = regs[18];
assign regs19 = regs[19];
assign regs20 = regs[20];
assign regs21 = regs[21];
assign regs22 = regs[22];
assign regs23 = regs[23];
assign regs24 = regs[24];
assign regs25 = regs[25];
assign regs26 = regs[26];
assign regs27 = regs[27];
assign regs28 = regs[28];
assign regs29 = regs[29];
assign regs30 = regs[30];
assign regs31 = regs[31];

 endmodule


