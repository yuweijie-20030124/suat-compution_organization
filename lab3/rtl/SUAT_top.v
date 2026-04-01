`include "define.v"


module SUAT_top(
	 input wire              	clk		  
	,input wire              	rst		  
	,input wire [`SUAT_INST] 	tb_if_inst
	,output wire [`SUAT_PC]  	tb_if_pc
	,output wire              	tb_ex_jump
	,output wire [`SUAT_PC]   	tb_ex_jump_pc
	,output wire [`SUAT_DATA] 	tb_ex_res
);

// ifu
wire [`SUAT_INST]                 if_id_inst;
wire [`SUAT_PC]                   if_id_pc;
wire [`SUAT_PC]					  if_id_snpc;

// idu
wire [`SUAT_REGADDR] 		  	id_reg_rs1_addr ;
wire [`SUAT_REGADDR] 		  	id_reg_rs2_addr ;
wire [`SUAT_REGADDR] 		  	id_reg_rd_addr  ;
wire                          	id_reg_rs1_ren	;
wire                          	id_reg_rs2_ren	;

wire [3:0]      		   		id_ls_ctl;
wire           		   		 	id_wb_ctl;
wire [`SUAT_DATA]				data1;
wire [`SUAT_DATA]				data2;
wire [`SUAT_DATA]				data3;
wire [`SUAT_DATA]				data4;

// exu
wire [17:0]						exu_op;
wire [`SUAT_DATA] 	     		exu_data;
wire                            exu_jump;
wire [`SUAT_PC]                 exu_jump_pc;

// wbu
wire [`SUAT_DATA]	   			wb_reg_rd_data;
wire							wb_wen;

// regfile
wire [`SUAT_REG] 				reg_id_rs1_data;
wire [`SUAT_REG] 				reg_id_rs2_data;

SUAT_ifu ifu0(
     .clk     (clk       		)
	,.rst     (rst       		)
	,.jump 	  (exu_jump   		)
	,.jump_pc (exu_jump_pc		)
	,.inst_i  (tb_if_inst		)
	,.inst_o  (if_id_inst		)
	,.pc_o    (if_id_pc  		)
	,.snpc    (if_id_snpc		)
);

SUAT_idu idu1(
     .inst_i	(if_id_inst				)
	,.pc_i	  	(if_id_pc				)
	,.snpc		(if_id_snpc				)

	,.rs1_addr 	(id_reg_rs1_addr		)
	,.rs1_ren	(id_reg_rs1_ren			)
	,.rs1_data	(reg_id_rs1_data		)

	,.rs2_addr	(id_reg_rs2_addr		)
	,.rs2_ren	(id_reg_rs2_ren			)
	,.rs2_data	(reg_id_rs2_data		)

	,.rd_addr	(id_reg_rd_addr			)

	,.exu_op	(exu_op					)
	,.wbctl_op	(id_wb_ctl				)

	,.data1		(data1					)
	,.data2		(data2					)
	,.data3		(data3					)
	,.data4		(data4					)
);

SUAT_exu exu2(
	 .data1       (data1	        )
	,.data2       (data2         	)
	,.data3       (data3         	)
	,.data4       (data4         	)
	,.exu_op	  (exu_op			)
	,.exu_jump	  (exu_jump			)
	,.exu_jump_pc (exu_jump_pc		)
	,.exu_res     (exu_data			)
);

SUAT_wbu wbu4(
	 .wb_ctl	(id_wb_ctl  			)
	,.exu_res	(exu_data 				)
	,.wb_data	(wb_reg_rd_data 		)
	,.wb_wen	(wb_wen					)
);

SUAT_regfile reg5(
	 .clk  		(clk					)
	,.rst  		(rst					)
	,.waddr		(id_reg_rd_addr			)
	,.wdata		(wb_reg_rd_data			)
	,.wen    	(wb_wen 				)
	,.raddr1 	(id_reg_rs1_addr		)
	,.rdata1 	(reg_id_rs1_data		)
	,.ren1  	(id_reg_rs1_ren 		)
	,.raddr2	(id_reg_rs2_addr		)
	,.rdata2	(reg_id_rs2_data		)
	,.ren2 		(id_reg_rs2_ren 		)
);

assign tb_ex_jump    = exu_jump;
assign tb_ex_jump_pc = exu_jump_pc;
assign tb_ex_res     = exu_data;
assign tb_if_pc      = if_id_pc;

endmodule
