module SUAT_idu_decoder(
	input  wire   [`SUAT_INST]	    			inst	
	,output wire						        rs1_ena	
	,output wire						        rs2_ena	
	,output wire						        jump	
	,output wire  [1:0]          				wb_ctl  
	,output reg   [3:0]          				mem_ctl 
	,output wire                 				branch  
	,output reg   [`SUAT_IMM]		 			ext_imm 
	,output wire						        imm_ena	
    ,output wire	 [9:0]					    alu_ctl	
);

wire [6:0] opcode ;
wire [2:0] funct3 ;

/* verilator lint_off UNUSEDSIGNAL */
wire [6:0] funct7 ;
/* verilator lint_on UNUSEDSIGNAL */

wire [11:0] i_imm ;
wire [20:1] j_imm ;
wire [19:0] u_imm ;
wire [11:0] s_imm ;
wire [12:1] b_imm ;


assign opcode = inst[6:0];
assign funct3 = inst[14:12];
assign funct7 = inst[31:25]  ;

assign i_imm = inst[31:20];
assign {j_imm[20],j_imm[10:1],j_imm[11],j_imm[19:12]} = inst[31:12];
assign u_imm = inst[31:12];
assign s_imm = {inst[31:25], inst[11:7]} ;
assign {b_imm[12] , b_imm[10:5] , b_imm[4:1] , b_imm[11]} = {inst[31:25] , inst[11:7]} ;

wire [7:0] inst_type;

//-----------------------------------decode--------------------------------//

assign inst_type[7] = (opcode[6:2] == `SUAT_SYSTEM)       ;
assign inst_type[6] = (opcode[6:2] == `SUAT_OP32)   ;
assign inst_type[5] = (opcode[6:2] == `SUAT_OPIMM32)   ;
assign inst_type[4] = (opcode[6:2] == `SUAT_OPIMM)    ;
assign inst_type[3] = (opcode[6:2] == `SUAT_OP)    ;
assign inst_type[2] = (opcode[6:2] == `SUAT_BRANCH)    ;
assign inst_type[1] = (opcode[6:2] == `SUAT_LOAD) & (opcode[1:0] == 2'b11)     ;
assign inst_type[0] = (opcode[6:2] == `SUAT_STORE)     ;

wire inst_lui   = (opcode[6:2] == `SUAT_LUI)    ;
wire inst_auipc = (opcode[6:2] == `SUAT_AUIPC)  ;
wire inst_jal   = (opcode[6:2] == `SUAT_JAL)    ;
wire inst_jalr  = (opcode[6:2] == `SUAT_JALR)   ;

wire inst_sb    = inst_type[0] &  ~funct3[2] & ~funct3[1] & ~funct3[0]   ;
wire inst_sh    = inst_type[0] &  ~funct3[2] & ~funct3[1] &  funct3[0]   ;
wire inst_sw    = inst_type[0] &  ~funct3[2] &  funct3[1] & ~funct3[0]   ;
wire inst_sd    = inst_type[0] &  ~funct3[2] &  funct3[1] &  funct3[0]   ;

wire inst_lb    = inst_type[1] &  ~funct3[2] & ~funct3[1] & ~funct3[0]   ;
wire inst_lh    = inst_type[1] &  ~funct3[2] & ~funct3[1] &  funct3[0]   ;
wire inst_lw    = inst_type[1] &  ~funct3[2] &  funct3[1] & ~funct3[0]   ;
wire inst_ld    = inst_type[1] &  ~funct3[2] &  funct3[1] &  funct3[0]   ;
wire inst_lbu   = inst_type[1] &   funct3[2] & ~funct3[1] & ~funct3[0]   ;
wire inst_lhu   = inst_type[1] &   funct3[2] & ~funct3[1] &  funct3[0]   ;
wire inst_lwu   = inst_type[1] &   funct3[2] &  funct3[1] & ~funct3[0]   ;

wire inst_beq   = inst_type[2] & ~funct3[2] & ~funct3[1] & ~funct3[0]   ;
wire inst_bne   = inst_type[2] & ~funct3[2] & ~funct3[1] &  funct3[0]   ;
wire inst_blt   = inst_type[2] &  funct3[2] & ~funct3[1] & ~funct3[0]   ;
wire inst_bge   = inst_type[2] &  funct3[2] & ~funct3[1] &  funct3[0]   ;
wire inst_bltu  = inst_type[2] &  funct3[2] &  funct3[1] & ~funct3[0]   ;
wire inst_bgeu  = inst_type[2] &  funct3[2] &  funct3[1] &  funct3[0]   ;

wire inst_add   = inst_type[3] & ~funct3[2] & ~funct3[1] & ~funct3[0] & ~funct7[5] & ~funct7[0];
wire inst_sub   = inst_type[3] & ~funct3[2] & ~funct3[1] & ~funct3[0] &  funct7[5] & ~funct7[0];
wire inst_sll   = inst_type[3] & ~funct3[2] & ~funct3[1] &  funct3[0] & ~funct7[0] ;
wire inst_slt   = inst_type[3] & ~funct3[2] &  funct3[1] & ~funct3[0] & ~funct7[0] ;
wire inst_sltu  = inst_type[3] & ~funct3[2] &  funct3[1] &  funct3[0] & ~funct7[0]  ;
wire inst_xor   = inst_type[3] &  funct3[2] & ~funct3[1] & ~funct3[0] & ~funct7[0] ;
wire inst_srl   = inst_type[3] &  funct3[2] & ~funct3[1] &  funct3[0] & ~funct7[5] & ~funct7[0];
wire inst_sra   = inst_type[3] &  funct3[2] & ~funct3[1] &  funct3[0] &  funct7[5] & ~funct7[0];
wire inst_or    = inst_type[3] &  funct3[2] &  funct3[1] & ~funct3[0] & ~funct7[0] ;
wire inst_and   = inst_type[3] &  funct3[2] &  funct3[1] &  funct3[0] & ~funct7[0]  ;
wire inst_div   = inst_type[3] &  funct3[2] & ~funct3[1] & ~funct3[0]  & funct7[0] ;
wire inst_divu  = inst_type[3] &  funct3[2] & ~funct3[1] &  funct3[0]  & funct7[0] ;
wire inst_mul   = inst_type[3] &  ~funct3[2] & ~funct3[1] & ~funct3[0] & funct7[0] ;
wire inst_mulh  = inst_type[3] &  ~funct3[2] & ~funct3[1] &  funct3[0] & funct7[0] ;
wire inst_mulhsu= inst_type[3] &  ~funct3[2] &  funct3[1] & ~funct3[0] & funct7[0] ;
wire inst_mulhu = inst_type[3] &  ~funct3[2] &  funct3[1] &  funct3[0] & funct7[0] ;
wire inst_rem   = inst_type[3] &  funct3[2] &  funct3[1] & ~funct3[0]  & funct7[0] ;
wire inst_remu  = inst_type[3] &  funct3[2] &  funct3[1] &  funct3[0]  & funct7[0] ;

wire inst_addi  = inst_type[4] & ~funct3[2] & ~funct3[1] & ~funct3[0]   ;
wire inst_slti  = inst_type[4] & ~funct3[2] &  funct3[1] & ~funct3[0]   ;
wire inst_sltiu = inst_type[4] & ~funct3[2] &  funct3[1] &  funct3[0]   ;
wire inst_xori  = inst_type[4] &  funct3[2] & ~funct3[1] & ~funct3[0]   ;
wire inst_ori   = inst_type[4] &  funct3[2] &  funct3[1] & ~funct3[0]   ;
wire inst_andi  = inst_type[4] &  funct3[2] &  funct3[1] &  funct3[0]   ;
wire inst_slli  = inst_type[4] & ~funct3[2] & ~funct3[1] &  funct3[0]   ;
wire inst_srli  = inst_type[4] &  funct3[2] & ~funct3[1] &  funct3[0] & ~i_imm[10]   ;
wire inst_srai  = inst_type[4] &  funct3[2] & ~funct3[1] &  funct3[0] &  i_imm[10]   ;

wire inst_ecall  = inst_type[7] & ~funct3[2] & ~funct3[1] & ~funct3[0] && (i_imm == 12'd0)         ;
wire inst_mret   = inst_type[7] & ~funct3[2] & ~funct3[1] & ~funct3[0] & funct7[3] & funct7[4];
wire inst_csrrw  = inst_type[7] & ~funct3[2] & ~funct3[1] &  funct3[0]   ;
wire inst_csrrs  = inst_type[7] & ~funct3[2] &  funct3[1] & ~funct3[0]   ;
wire inst_csrrc  = inst_type[7] & ~funct3[2] &  funct3[1] &  funct3[0]   ;
wire inst_csrrwi = inst_type[7] &  funct3[2] & ~funct3[1] &  funct3[0]   ;
wire inst_csrrsi = inst_type[7] &  funct3[2] &  funct3[1] & ~funct3[0]   ;
wire inst_csrrci = inst_type[7] &  funct3[2] &  funct3[1] &  funct3[0]   ;
wire inst_ebreak = inst_type[7] & ~funct3[2] & ~funct3[1] & ~funct3[0] && (i_imm == 12'd1)         ;

assign alu_ctl[9] = inst_sltu | inst_slt | inst_sltiu | inst_slti;
assign alu_ctl[8] = inst_xor | inst_xori;
assign alu_ctl[7] = inst_or | inst_ori;
assign alu_ctl[6] = inst_and | inst_andi;
assign alu_ctl[5] = inst_sltu | inst_slt | inst_sub | inst_sltiu | inst_slti;
assign alu_ctl[4] = inst_sltu | inst_sltiu;
assign alu_ctl[3] = inst_add | inst_sub | inst_addi;
assign alu_ctl[2] = inst_srl | inst_sra | inst_sll | inst_srli | inst_srai | inst_slli;
assign alu_ctl[1] = inst_sra | inst_srai;
assign alu_ctl[0] = inst_srl | inst_sra | inst_srli | inst_srai;

wire inst_csr   = inst_csrrw | inst_csrrs | inst_csrrc ;

//--------------------------output signal-----------------------//

//output to regfile signal
assign rs1_ena =  inst_type[6] | inst_type[5] | inst_type[4] | inst_type[3] | inst_type[2] | inst_type[1] | inst_type[0] | inst_jalr | inst_csr | inst_ecall;
assign rs2_ena =  inst_type[6] | inst_type[3] | inst_type[2] | inst_type[0] ;


//output to ifu singal
assign branch = inst_type[2];
assign jump = inst_jal | inst_jalr;

//Extend IMM
always @(*) begin
	if (inst_type[1] | inst_type[4] | inst_type[5] | inst_type[7] | inst_jalr) begin
		ext_imm = {{20{i_imm[11]}}, i_imm}; // i_imm扩展为32位
	end
	else if (inst_lui | inst_auipc) begin
		ext_imm = {u_imm, 12'b0}; // u_imm扩展为32位
	end
	else if (inst_jal) begin
		ext_imm = {{11{j_imm[20]}}, j_imm[20:1], 1'b0}; // j_imm扩展为32位，注意左移1位
	end
	else if (inst_type[0]) begin
		ext_imm = {{20{s_imm[11]}}, s_imm}; // s_imm扩展为32位
	end
	else if (inst_type[2]) begin
		ext_imm = {{19{b_imm[12]}}, b_imm, 1'b0}; // b_imm扩展为32位，注意左移1位
	end
	else begin
		ext_imm = `SUAT_ZERO32; // 默认值
	end
end

assign imm_ena =  inst_type[0] | inst_type[1] | inst_type[2] | inst_type[4] | inst_type[5] | inst_type[7] |  inst_lui | inst_auipc  ;

//output to mem signal
always @(*) begin
  case(alu_ctl) 
    `INST_SB : begin mem_ctl = 4'b0001; end
    `INST_SH : begin mem_ctl = 4'b0010; end
    `INST_SW : begin mem_ctl = 4'b0100; end
    `INST_SD : begin mem_ctl = 4'b0101; end
    `INST_LB : begin mem_ctl = 4'b1001; end
    `INST_LH : begin mem_ctl = 4'b1010; end
    `INST_LW : begin mem_ctl = 4'b1011; end
    `INST_LD : begin mem_ctl = 4'b1100; end
    `INST_LBU: begin mem_ctl = 4'b1101; end
    `INST_LHU: begin mem_ctl = 4'b1110; end
    `INST_LWU: begin mem_ctl = 4'b1111; end
     default : begin mem_ctl = 4'b0000; end
  endcase
end


//output to wb signal 
assign wb_ctl = (inst_type[1] ) ? 2'b01 : (( inst_type[7] | inst_type[6] | inst_type[5] |inst_type[4] | inst_type[3] | inst_lui | inst_auipc | jump) ? 2'b10 : 2'b00 ) ;



endmodule
