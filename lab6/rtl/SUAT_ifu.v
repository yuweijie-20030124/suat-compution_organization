`include "define.v"

module SUAT_ifu (
  input  wire						clk
 ,input  wire						rst
 ,input	 wire						flush
 ,input	 wire 	[`SUAT_PC]			flush_pc
 ,input  wire						id_allow_in
 ,input  wire	[`SUAT_INST]		inst_i
 ,output wire 	[`SUAT_INST]		inst_o
 ,output wire	[`SUAT_PC]			pc_o
 ,output wire	[`SUAT_PC] 			snpc_o
 ,output wire						if_valid_o
 );

 reg  [`SUAT_PC] pc_reg;
 wire [`SUAT_PC] snpc;

 assign snpc = pc_reg + 4;
 assign snpc_o = snpc;
 assign inst_o = inst_i;
 assign pc_o   = pc_reg;
 assign if_valid_o = id_allow_in;
 
 always@(posedge clk) begin
	if(rst == `SUAT_RSTABLE)begin
	    pc_reg <= `SUAT_STARTPC;		
	end
    else if (flush) begin
	    pc_reg <= flush_pc;
	end
    else if (id_allow_in) begin
	    pc_reg <= snpc;
	end
end

endmodule
