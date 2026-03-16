module SUAT_regfile (
     input    wire             					clk   
    ,input    wire             					rst   

    ,input    wire   [`SUAT_REGADDR]     		waddr 
    ,input    wire   [`SUAT_REG]    	 		wdata 
    ,input    wire             				    wen   
   
	,input    wire   [`SUAT_REGADDR]	 		raddr1
	,output	  wire   [`SUAT_REG]	  	 		rdata1
	,input	  wire             					ren1  

	,input    wire   [`SUAT_REGADDR]	 		raddr2
	,output	  wire   [`SUAT_REG]	  	 		rdata2
	,input	  wire             					ren2  

);
 
    reg  [`SUAT_REG] regs [0:31];

 always@(posedge clk) begin
	 if(rst == `SUAT_RSTABLE) begin
		regs[0]  <= `SUAT_ZERO32; 
 		regs[1]  <= `SUAT_ZERO32; 
 		regs[2]  <= `SUAT_ZERO32; 
 		regs[3]  <= `SUAT_ZERO32; 
 		regs[4]  <= `SUAT_ZERO32; 
 		regs[5]  <= `SUAT_ZERO32; 
 		regs[6]  <= `SUAT_ZERO32; 
 		regs[7]  <= `SUAT_ZERO32; 
 		regs[8]  <= `SUAT_ZERO32; 
 		regs[9]  <= `SUAT_ZERO32; 
 		regs[10] <= `SUAT_ZERO32; 
 		regs[11] <= `SUAT_ZERO32; 
 		regs[12] <= `SUAT_ZERO32; 
 		regs[13] <= `SUAT_ZERO32; 
 		regs[14] <= `SUAT_ZERO32; 
 		regs[15] <= `SUAT_ZERO32; 
 		regs[16] <= `SUAT_ZERO32; 
 		regs[17] <= `SUAT_ZERO32; 
 		regs[18] <= `SUAT_ZERO32; 
 		regs[19] <= `SUAT_ZERO32; 
 		regs[20] <= `SUAT_ZERO32; 
 		regs[21] <= `SUAT_ZERO32; 
 		regs[22] <= `SUAT_ZERO32; 
 		regs[23] <= `SUAT_ZERO32; 
 		regs[24] <= `SUAT_ZERO32; 
 		regs[25] <= `SUAT_ZERO32; 
 		regs[26] <= `SUAT_ZERO32; 
 		regs[27] <= `SUAT_ZERO32; 
 		regs[28] <= `SUAT_ZERO32; 
 		regs[29] <= `SUAT_ZERO32; 
 		regs[30] <= `SUAT_ZERO32; 
 		regs[31] <= `SUAT_ZERO32;
	 end
   else begin
		 if(wen == `SUAT_WENABLE && waddr != 5'd0)begin
			 regs[waddr]<=wdata;
		 end
	 end
 end

 assign rdata1 = ((rst != `SUAT_RSTABLE) && (ren1 == `SUAT_RENABLE)) ? regs[raddr1] : `SUAT_ZERO32;
 assign rdata2 = ((rst != `SUAT_RSTABLE) && (ren2 == `SUAT_RENABLE)) ? regs[raddr2] : `SUAT_ZERO32;

 endmodule


