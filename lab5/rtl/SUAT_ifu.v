`include "define.v"

module SUAT_ifu (
  input  wire						clk
 ,input  wire						rst
 ,input	 wire						jump
 ,input	 wire 	[`SUAT_PC]			jump_pc
 ,input  wire	[`SUAT_INST]		inst_i
 ,output wire 	[`SUAT_INST]		inst_o
 ,output wire	[`SUAT_PC]			pc_o
 ,output wire	[`SUAT_PC] 			snpc_o
 );

 reg  [`SUAT_PC] pc_reg;
 wire [`SUAT_PC] snpc;

 assign snpc = pc_reg + 4;
 assign snpc_o = snpc;
 assign inst_o = inst_i;
 assign pc_o   = pc_reg;

// TODO: Modify the following always block to update pc_reg correctly
 always@(posedge clk) begin
	if(rst == `SUAT_RSTABLE)begin
	    pc_reg <= `SUAT_STARTPC;		
	end
    else if (jump) begin
	    pc_reg <= jump_pc;
	end
    else begin
	    pc_reg <= snpc;
	end
end

endmodule
