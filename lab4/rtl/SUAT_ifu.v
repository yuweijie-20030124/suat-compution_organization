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
 reg  [`SUAT_INST] inst_reg;
 reg  [`SUAT_INST] hold_inst;
 reg             hold_valid;

 wire [`SUAT_PC] issue_pc;
 wire [`SUAT_PC] fetch_snpc;

 assign issue_pc   = jump ? jump_pc : fetch_pc;
 assign fetch_snpc = issue_pc + `SUAT_PLUS4;

 always@(posedge clk) begin
	if(rst == `SUAT_RSTABLE)begin
	    fetch_pc   <= `SUAT_STARTPC;
	    inst_pc    <= `SUAT_STARTPC;
	    inst_valid <= 1'b0;
	    inst_reg   <= 32'h00000013;
	    hold_inst  <= 32'h00000013;
	    hold_valid <= 1'b0;
	end
    else begin
	    // Strict single-cycle IFU:
	    // each cycle issues exactly one instruction and immediately resolves
	    // branch/jump redirection for the next cycle.
	    inst_pc    <= issue_pc;
	    inst_reg   <= bram_rdata;
	    fetch_pc   <= fetch_snpc;
	    inst_valid <= 1'b1;
	    hold_inst  <= 32'h00000013;
	    hold_valid <= 1'b0;
	end
end
 
 assign inst_o    = inst_reg;
 assign pc_o      = inst_pc;
 assign snpc      = pc_o + `SUAT_PLUS4;
 assign bram_addr = issue_pc[17:2];
 assign bram_cs   = (rst != `SUAT_RSTABLE);
  
endmodule
