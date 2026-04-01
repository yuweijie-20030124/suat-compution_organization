`include "define.v"

module SUAT_idu(
	//system input
	input	  wire [`SUAT_INST]	    inst_i	
	,input	  wire [`SUAT_PC]		pc_i	
	,input	  wire [`SUAT_PC] 		snpc
	
	//regfile signal
	,output    wire [`SUAT_REGADDR] rs1_addr 
	,output    wire				 	rs1_ren
	,input     wire [`SUAT_REG]     rs1_data 
	
	,output    wire [`SUAT_REGADDR] rs2_addr 
	,output    wire					rs2_ren
	,input     wire [`SUAT_REG]     rs2_data 

  	,output    wire [`SUAT_REGADDR] rd_addr 

	//control out signal
	,output    wire [17:0]        	exu_op
	,output    wire      			wbctl_op

	//id out signal
	,output    wire [`SUAT_DATA]  	data1
	,output    wire [`SUAT_DATA]  	data2
	,output    wire [`SUAT_DATA]  	data3
	,output    wire [`SUAT_DATA]    data4
);

//----------------------------------decode---------------------------//
wire   [ 4:0]   rd     ;
wire   [ 4:0]   rs1    ;
wire   [ 4:0]   rs2    ;
assign  rd       =  inst_i [11:7]   ;
assign  rs1      =  inst_i [19:15]  ;
assign  rs2      =  inst_i [24:20]  ;

wire [6:0] opcode ;
wire [2:0] funct3 ;

/* verilator lint_off UNUSEDSIGNAL */
wire [6:0] funct7 ;
/* verilator lint_on UNUSEDSIGNAL */

wire [31:0] i_imm ;
wire [31:0] j_imm ;
wire [31:0] u_imm ;
wire [31:0] s_imm ;
wire [31:0] b_imm ;

wire [31:0] inst = inst_i;
wire [31:0] pc = pc_i;

assign opcode = inst[6:0];
assign funct3 = inst[14:12];
assign funct7 = inst[31:25];

assign i_imm = {{20{inst[31]}}, inst[31:20]};
assign j_imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
assign u_imm = {inst[31:12], {12{1'b0}}};
assign s_imm = {{21{inst[31]}}, inst[30:25], inst[11:7]};
assign b_imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};

//-----------------------------------decode--------------------------------//

wire type_i = (opcode[6:2] == `SUAT_OPIMM)    ;
wire type_r = (opcode[6:2] == `SUAT_OP)    ;
wire type_branch = (opcode[6:2] == `SUAT_BRANCH)    ;
wire type_load = (opcode[6:2] == `SUAT_LOAD) & (opcode[1:0] == 2'b11)     ;
wire type_store = (opcode[6:2] == `SUAT_STORE)     ;

wire inst_lui   = (opcode[6:2] == `SUAT_LUI)    ;
wire inst_auipc = (opcode[6:2] == `SUAT_AUIPC)  ;
wire inst_jal   = (opcode[6:2] == `SUAT_JAL)    ;
wire inst_jalr  = (opcode[6:2] == `SUAT_JALR)   ;

wire inst_sb    = type_store &  ~funct3[2] & ~funct3[1] & ~funct3[0]   ;
wire inst_sh    = type_store &  ~funct3[2] & ~funct3[1] &  funct3[0]   ;
wire inst_sw    = type_store &  ~funct3[2] &  funct3[1] & ~funct3[0]   ;

wire inst_lb    = type_load &  ~funct3[2] & ~funct3[1] & ~funct3[0]   ;
wire inst_lh    = type_load &  ~funct3[2] & ~funct3[1] &  funct3[0]   ;
wire inst_lw    = type_load &  ~funct3[2] &  funct3[1] & ~funct3[0]   ;
wire inst_ld    = type_load &  ~funct3[2] &  funct3[1] &  funct3[0]   ;
wire inst_lbu   = type_load &   funct3[2] & ~funct3[1] & ~funct3[0]   ;
wire inst_lhu   = type_load &   funct3[2] & ~funct3[1] &  funct3[0]   ;

wire inst_beq   = type_branch & ~funct3[2] & ~funct3[1] & ~funct3[0]   ;
wire inst_bne   = type_branch & ~funct3[2] & ~funct3[1] &  funct3[0]   ;
wire inst_blt   = type_branch &  funct3[2] & ~funct3[1] & ~funct3[0]   ;
wire inst_bge   = type_branch &  funct3[2] & ~funct3[1] &  funct3[0]   ;
wire inst_bltu  = type_branch &  funct3[2] &  funct3[1] & ~funct3[0]   ;
wire inst_bgeu  = type_branch &  funct3[2] &  funct3[1] &  funct3[0]   ;

wire inst_add   = type_r & ~funct3[2] & ~funct3[1] & ~funct3[0] & ~funct7[5] & ~funct7[0];
wire inst_sub   = type_r & ~funct3[2] & ~funct3[1] & ~funct3[0] &  funct7[5] & ~funct7[0];
wire inst_sll   = type_r & ~funct3[2] & ~funct3[1] &  funct3[0] & ~funct7[0] ;
wire inst_slt   = type_r & ~funct3[2] &  funct3[1] & ~funct3[0] & ~funct7[0] ;
wire inst_sltu  = type_r & ~funct3[2] &  funct3[1] &  funct3[0] & ~funct7[0]  ;
wire inst_xor   = type_r &  funct3[2] & ~funct3[1] & ~funct3[0] & ~funct7[0] ;
wire inst_srl   = type_r &  funct3[2] & ~funct3[1] &  funct3[0] & ~funct7[5] & ~funct7[0];
wire inst_sra   = type_r &  funct3[2] & ~funct3[1] &  funct3[0] &  funct7[5] & ~funct7[0];
wire inst_or    = type_r &  funct3[2] &  funct3[1] & ~funct3[0] & ~funct7[0] ;
wire inst_and   = type_r &  funct3[2] &  funct3[1] &  funct3[0] & ~funct7[0]  ;

wire inst_addi  = type_i & ~funct3[2] & ~funct3[1] & ~funct3[0]   ;
wire inst_slti  = type_i & ~funct3[2] &  funct3[1] & ~funct3[0]   ;
wire inst_sltiu = type_i & ~funct3[2] &  funct3[1] &  funct3[0]   ;
wire inst_xori  = type_i &  funct3[2] & ~funct3[1] & ~funct3[0]   ;
wire inst_ori   = type_i &  funct3[2] &  funct3[1] & ~funct3[0]   ;
wire inst_andi  = type_i &  funct3[2] &  funct3[1] &  funct3[0]   ;
wire inst_slli  = type_i & ~funct3[2] & ~funct3[1] &  funct3[0]   ;
wire inst_srli  = type_i &  funct3[2] & ~funct3[1] &  funct3[0] & ~i_imm[10]   ;
wire inst_srai  = type_i &  funct3[2] & ~funct3[1] &  funct3[0] &  i_imm[10]   ;

wire jump = inst_jal | inst_jalr;
wire rd_wen;
assign rd_wen  =  type_load | type_r | type_i | inst_lui | inst_auipc | jump;

//--------------------------output signal-----------------------//

//output to regfile signal
assign rs1_ren =  type_store | type_load | type_branch | type_i | type_r | inst_jalr;
assign rs2_ren =  type_branch | type_store | type_r;
assign rs1_addr = rs1_ren ? rs1 : 5'd0;
assign rs2_addr = rs2_ren ? rs2 : 5'd0;
assign rd_addr  = rd_wen ? rd : 5'd0;

//decode IMM
wire i_imm_en = type_load | inst_jalr | type_i;
wire j_imm_en = inst_jal;
wire u_imm_en = inst_lui | inst_auipc;
wire s_imm_en = type_store;
wire b_imm_en = type_branch;

wire [31:0] imm;
assign imm = i_imm & {32{i_imm_en}} | j_imm & {32{j_imm_en}} |
	u_imm & {32{u_imm_en}} | s_imm & {32{s_imm_en}} | b_imm & {32{b_imm_en}};

// No load/store in this lab stage.
assign mem_ctl = 4'b0000;

//output to wb signal 
assign wbctl_op = rd_wen;

//-------------------------------output--------------------------//

// output to exu		TODO


endmodule
