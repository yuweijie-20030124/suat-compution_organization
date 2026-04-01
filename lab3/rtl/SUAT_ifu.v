 `include "define.v"

module SUAT_ifu (
  input  wire						clk			
 ,input  wire						rst			
 ,input	 wire						jump	
 ,input	 wire 	[`SUAT_PC]			jump_pc  	
 ,input  wire	[`SUAT_INST]		inst_i		
 
 ,output wire 	[`SUAT_INST]		inst_o		
 ,output wire	[`SUAT_PC]			pc_o
 ,output wire	[`SUAT_PC] 			snpc
 );

 reg  [`SUAT_PC] pc_reg;
 wire [`SUAT_PC] dnpc;

 assign snpc = pc_o + 4;
 assign dnpc = jump ? jump_pc : snpc;

 always@(posedge clk) begin
	if(rst == `SUAT_RSTABLE)begin
	    pc_reg <= `SUAT_STARTPC;		
	end
    else begin
	    pc_reg <= dnpc;
	end
end
 
 assign inst_o = inst_i;
 assign pc_o   = pc_reg;
  
endmodule
