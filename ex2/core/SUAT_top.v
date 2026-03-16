module SUAT_top(
	 input wire              	clk		  
	,input wire              	rst		  
	,input wire [`SUAT_INST] 	tb_id_inst
	,input wire [`SUAT_PC] 	 	tb_id_pc
);

// idu
wire [`SUAT_REGADDR] 		  	id_reg_rs1_addr ;
wire [`SUAT_REGADDR] 		  	id_reg_rs2_addr ;
wire [`SUAT_REGADDR] 		  	id_reg_rd_addr  ;
wire                          	id_reg_rs1_ena	;
wire                          	id_reg_rs2_ena	;
wire                          	id_reg_rd_ena	;

wire [`SUAT_IMM]     		   	id_ex_imm		;
wire            		   		id_ex_branch    ;
wire            		   		id_ex_jump      ;
wire [3:0]      		   		id_ls_ctl  	    ;
wire [1:0]      		   		id_wb_ctl    	;
wire [9:0]						id_ex_alu_sel;
wire [`SUAT_PC]    		   		id_ex_pc    	;
wire [`SUAT_DATA] 		   		id_ex_op1 ;
wire [`SUAT_DATA] 		   		id_ex_op2 ;
wire [3:0]                     	id_ex_csrctl;

// exu
wire [`SUAT_DATA] 	     		ex_aludata;

// wbu
wire [`SUAT_DATA]	   			wb_reg_rd_data;

// regfile
wire [`SUAT_REG] 				reg_id_rs1_data;
wire [`SUAT_REG] 				reg_id_rs2_data;

SUAT_idu idu1(
     .inst_i	(tb_id_inst				)
	,.pc_i	  	(tb_id_pc				)

	,.rs1_addr 	(id_reg_rs1_addr		)
	,.rs1_ena	(id_reg_rs1_ena			)
	,.rs1_data	(reg_id_rs1_data		)

	,.rs2_addr	(id_reg_rs2_addr		)
	,.rs2_ena	(id_reg_rs2_ena			)
	,.rs2_data	(reg_id_rs2_data		)

	,.rd_ena	(id_reg_rd_ena			)
	,.rd_addr	(id_reg_rd_addr			)

	,.alusrc_o	(id_ex_alu_sel			)
	,.lsctl_o	(id_ls_ctl				)
	,.wbctl_o	(id_wb_ctl				)
	,.branch_o	(id_ex_branch			)
	,.jump_o	(id_ex_jump				)

	,.op1		(id_ex_op1				)
	,.op2		(id_ex_op2				)
	,.imm		(id_ex_imm				)
	,.pc_o		(id_ex_pc				)
);

SUAT_alu alu2(
	 .src1  	(id_ex_op1				)
	,.src2  	(id_ex_op2				)
	,.alu_op 	(id_ex_alu_sel			)
	,.alu_res	(ex_aludata				)
);

SUAT_wbu wbu4(
	 .rst		(rst					)	
	,.wb_ctl	(id_wb_ctl  			)
	,.exu_res	(ex_aludata 			)
	,.wb_data	(wb_reg_rd_data 		)
);

SUAT_regfile reg5(
	 .clk  		(clk					)
	,.rst  		(rst					)
	,.waddr		(id_reg_rd_addr			)
	,.wdata		(wb_reg_rd_data			)
	,.wen    	(id_reg_rd_ena 			)
	,.raddr1 	(id_reg_rs1_addr		)
	,.rdata1 	(reg_id_rs1_data		)
	,.ren1  	(id_reg_rs1_ena 		)
	,.raddr2	(id_reg_rs2_addr		)
	,.rdata2	(reg_id_rs2_data		)
	,.ren2 		(id_reg_rs2_ena 		)
);

endmodule
