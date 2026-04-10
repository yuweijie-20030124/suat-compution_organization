 `include "define.v"

module SUAT_ifu (
 input  wire						clk			
 ,input  wire						rst			
 ,input  wire                       stall
 ,input	 wire						jump	
 ,input	 wire 	[`SUAT_PC]			jump_pc  	
 ,input  wire	[`SUAT_INST]		bram_rdata		
 
 ,output wire 	[`SUAT_INST]		inst_o		
 ,output wire	[`SUAT_PC]			pc_o
 ,output wire	[`SUAT_PC] 			snpc
 ,output wire   [15:0]              bram_addr
 ,output wire                       bram_cs
 );

 reg  [`SUAT_PC] fetch_pc;
 reg  [`SUAT_PC] inst_pc;
 reg             inst_valid;
 reg  [`SUAT_INST] hold_inst;
 reg             hold_valid;

 wire [`SUAT_PC] fetch_snpc;
 wire [`SUAT_PC] dnpc;
 wire [`SUAT_INST] current_inst;

 assign fetch_snpc = fetch_pc + `SUAT_PLUS4;
 assign dnpc       = jump ? jump_pc : fetch_snpc;
 assign current_inst = inst_valid ? bram_rdata : 32'h00000013;

 always@(posedge clk) begin
	if(rst == `SUAT_RSTABLE)begin
	    fetch_pc   <= `SUAT_STARTPC;
	    inst_pc    <= `SUAT_STARTPC;
	    inst_valid <= 1'b0;
	    hold_inst  <= 32'h00000013;
	    hold_valid <= 1'b0;
	end
    else if (stall) begin
	    fetch_pc   <= fetch_pc;
	    inst_pc    <= inst_pc;
	    inst_valid <= inst_valid;
	    hold_inst  <= current_inst;
	    hold_valid <= 1'b1;
    end
    else begin
	    inst_pc    <= jump ? jump_pc : fetch_pc;
	    fetch_pc   <= dnpc;
	    inst_valid <= ~jump;
	    hold_inst  <= hold_inst;
	    hold_valid <= 1'b0;
	end
end
 
 assign inst_o    = hold_valid ? hold_inst : current_inst;
 assign pc_o      = inst_pc;
 assign snpc      = pc_o + `SUAT_PLUS4;
 assign bram_addr = fetch_pc[17:2];
 assign bram_cs   = (rst != `SUAT_RSTABLE);
  
endmodule
