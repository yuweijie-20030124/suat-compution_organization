 `include "define.v"
module ysyx_25060170_idu(
	//system input
	input	  wire		       				rst	,	
	
	//ifu input
	input	  wire [`ysyx_25060170_INST]	inst_i	,
	input	  wire [`ysyx_25060170_PC]		pc_i	,
	
	//regfile signal
	output    wire [`ysyx_25060170_REGADDR] rs1_addr ,//
	output    wire				 			rs1_ena  ,//
	input     wire [`ysyx_25060170_REG]     rs1_data ,
	
	output    wire [`ysyx_25060170_REGADDR] rs2_addr ,//
	output    wire						 	rs2_ena  ,//
	input     wire [`ysyx_25060170_REG]     rs2_data ,
	
	output    wire				 			rd_ena  ,//
  	output    wire [`ysyx_25060170_REGADDR] rd_addr ,//
        
	//control out signal
	output    wire [7:0]         			alusrc_o  ,//
	output    wire [3:0]      				lsctl_o   ,//
	output    wire [1:0]     				wbctl_o    ,//
	output    wire            				branch_o   ,//
	output    wire            				jump_o     ,//
	output    wire [3:0]                    csr_ctl    ,//
	
	//id out signal
	output    reg  [`ysyx_25060170_DATA]  	op1 ,//
	output    reg  [`ysyx_25060170_DATA]  	op2 , //
	output    reg  [`ysyx_25060170_IMM]     imm ,//
	output	  wire 	[`ysyx_25060170_REGADDR] idu_dpic_rd_addr,
	output	  wire [`ysyx_25060170_PC]		pc_o,//
	
	output    wire 							magic_flag
);

assign idu_dpic_rd_addr = rd;

//----------------------------------decode---------------------------//
wire   [ 4:0]   rd     ;
wire   [ 4:0]   rs1    ;
wire   [ 4:0]   rs2    ;
assign  rd       =  inst_i [11:7]   ;
assign  rs1      =  inst_i [19:15]  ;
assign  rs2      =  inst_i [24:20]  ;
assign  magic_flag = (inst_i == 32'b0100_0000_0000_0000_0000_0000_0011_0011);

wire imm_ena ;

ysyx_25060170_idu_decoder decode(
	.rst(rst)	,
	.inst(inst_i),
	.rs1_ena(rs1_ena),
	.rs2_ena(rs2_ena),
	.ext_imm(imm)	,
	.imm_ena(imm_ena),
	.jump(jump_o)	,
	.wb_ctl (wbctl_o) ,
 	.mem_ctl(lsctl_o) ,
 	.branch(branch_o) ,
	.alu_ctl(alusrc_o)
);

//-------------------------------output--------------------------//

//output to regfile
assign rs1_addr = rs1_ena ? rs1 : 5'd0 ;
assign rs2_addr = rs2_ena ? rs2 : 5'd0 ;
assign rd_ena  = (rd == 5'd0) ? 1'b0 : (wbctl_o == 2'b00) ? 1'b0 : 1'b1 ;
assign rd_addr = rd_ena ? rd : 5'd0 ;

//out to exu
//rs1
always @(*) begin
  if(rst == `ysyx_25060170_RSTABLE) begin  op1 = `ysyx_25060170_ZERO32   ;   end
  else if(rs1_ena) begin op1 = rs1_data ; end
  else if (alusrc_o == `INST_AUIPC | alusrc_o == `INST_JAL) begin  op1 = pc_i ;  end
	else if (alusrc_o == `INST_CSRRWI | alusrc_o == `INST_CSRRSI | alusrc_o == `INST_CSRRCI) begin op1 ={{27{1'b0}},rs1};end
  else begin op1 = `ysyx_25060170_ZERO32; end
  end
//rs2  
always @(*) begin
  if(rst == `ysyx_25060170_RSTABLE) begin  op2 = `ysyx_25060170_ZERO32   ;   end
  else if(rs2_ena) begin op2 = rs2_data ; end
  else if(imm_ena) begin op2 = imm ; end
  else begin op2 = `ysyx_25060170_ZERO32; end
 end

//csr
reg csr_wr_ena;
reg csr_rd_ena;
reg mret_ena;		//机器模式异常返回
reg ecall_ena;		//环境调用，调用异常请求执行环境

always @(*) begin
	csr_wr_ena = 1'b0;
	csr_rd_ena = 1'b0;
	mret_ena =  1'b0;
	ecall_ena = 1'b0;
	case(alusrc_o)
	`INST_ECALL : begin  ecall_ena = 1'b1;end
		
	`INST_MRET :  begin  mret_ena = 1'b1 ;end
		
	`INST_CSRRW, `INST_CSRRWI : begin
		csr_wr_ena = `ysyx_25060170_WENABLE;
		csr_rd_ena = (rd == 5'd0) ? `ysyx_25060170_RDISABLE : `ysyx_25060170_RENABLE;end
		
	`INST_CSRRS, `INST_CSRRC,
	`INST_CSRRSI, `INST_CSRRCI :  begin 
		csr_wr_ena = (rs1 == 5'd0) ? `ysyx_25060170_WDISABLE : `ysyx_25060170_WENABLE;
		csr_rd_ena = `ysyx_25060170_RENABLE;	end
	default : 	begin
		csr_wr_ena = 1'b0;
		csr_rd_ena = 1'b0;
		mret_ena =  1'b0;
		ecall_ena = 1'b0;
	end
	endcase 
end

assign csr_ctl = {csr_wr_ena, csr_rd_ena, ecall_ena, mret_ena};//csr控制器
 
assign pc_o = rst == `ysyx_25060170_RSTABLE ? `ysyx_25060170_ZERO32 : pc_i	;

endmodule
