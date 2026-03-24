 `include "define.v"

module SUAT_ifu (
  input  wire						clk			
 ,input  wire						rst			
 ,input	 wire						pcsrc_i		
 ,input	 wire 	[`SUAT_PC]			ex_pc_i  	
 ,input  wire	[`SUAT_INST]		inst_i		
 
 ,output wire 	[`SUAT_INST]		inst_o		
 ,output wire	[`SUAT_PC]			pc_o	
 );

 reg  [`SUAT_PC] pc_reg;

 wire [`SUAT_PC] pc_next;
 
 assign pc_next = (rst == `SUAT_RSTABLE) ? `SUAT_STARTPC : ((pcsrc_i==0) ? pc_o + 4 : ex_pc_i);

 always@(posedge clk) begin
	if(rst == `SUAT_RSTABLE)begin
	    pc_reg <= `SUAT_STARTPC;		
	end
    else begin
	    pc_reg <= pc_next;
	end
end
 
 assign inst_o = inst_i;
 assign pc_o   = pc_reg;
  
endmodule
