`include "define.v"

module SUAT_top(
	 input wire              	clk		  
	,input wire              	rst
	// Debug outputs
	,output wire [`SUAT_PC]   debug_pc
	,output wire [`SUAT_REG]  debug_gpr0
	,output wire [`SUAT_REG]  debug_gpr1
	,output wire [`SUAT_REG]  debug_gpr2
	,output wire [`SUAT_REG]  debug_gpr3
	,output wire [`SUAT_REG]  debug_gpr4
	,output wire [`SUAT_REG]  debug_gpr5
	,output wire [`SUAT_REG]  debug_gpr6
	,output wire [`SUAT_REG]  debug_gpr7
	,output wire [`SUAT_REG]  debug_gpr8
	,output wire [`SUAT_REG]  debug_gpr9
	,output wire [`SUAT_REG]  debug_gpr10
	,output wire [`SUAT_REG]  debug_gpr11
	,output wire [`SUAT_REG]  debug_gpr12
	,output wire [`SUAT_REG]  debug_gpr13
	,output wire [`SUAT_REG]  debug_gpr14
	,output wire [`SUAT_REG]  debug_gpr15
	,output wire [`SUAT_REG]  debug_gpr16
	,output wire [`SUAT_REG]  debug_gpr17
	,output wire [`SUAT_REG]  debug_gpr18
	,output wire [`SUAT_REG]  debug_gpr19
	,output wire [`SUAT_REG]  debug_gpr20
	,output wire [`SUAT_REG]  debug_gpr21
	,output wire [`SUAT_REG]  debug_gpr22
	,output wire [`SUAT_REG]  debug_gpr23
	,output wire [`SUAT_REG]  debug_gpr24
	,output wire [`SUAT_REG]  debug_gpr25
	,output wire [`SUAT_REG]  debug_gpr26
	,output wire [`SUAT_REG]  debug_gpr27
	,output wire [`SUAT_REG]  debug_gpr28
	,output wire [`SUAT_REG]  debug_gpr29
	,output wire [`SUAT_REG]  debug_gpr30
	,output wire [`SUAT_REG]  debug_gpr31
	,output wire [15:0]       debug_lsu_addr
	,output wire [`SUAT_DATA] debug_lsu_wdata
	,output wire [3:0]        debug_lsu_wren
);

// ifu
wire [`SUAT_INST]                 if_id_inst;
wire [`SUAT_PC]                   if_id_pc;
wire [`SUAT_PC]					  if_id_snpc;
wire [15:0]                       if_sram_addr;
wire [`SUAT_INST]                 if_sram_rdata;

// idu
wire [`SUAT_REGADDR] 		  	id_reg_rs1_addr ;
wire [`SUAT_REGADDR] 		  	id_reg_rs2_addr ;
wire [`SUAT_REGADDR] 		  	id_reg_rd_addr  ;
wire                          	id_reg_rs1_ren	;
wire                          	id_reg_rs2_ren	;

wire [2:0]     		   		 	id_wb_ctl;
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

// lsu
wire [`SUAT_DATA]                 ls_wb_data;
wire [15:0]                       ls_sram_addr;
wire [`SUAT_DATA]                 ls_sram_wdata;
wire [3:0]                        ls_sram_wren;
wire                              ls_sram_cs;
wire [`SUAT_DATA]                 ls_sram_rdata;
wire [3:0]                        lsu_op;
wire [3:0]                        lsu_wren_raw;
wire [`SUAT_DATA]                 lsu_wdata_raw;
wire [`SUAT_DATA]                 lsu_rdata_raw;
wire                              inst_sb;
wire                              inst_sh;
wire                              inst_sw;
wire                              inst_lb;
wire                              inst_lh;
wire                              inst_lw;
wire                              inst_lbu;
wire                              inst_lhu;
wire                              mem_load;
wire                              mem_store;
wire [1:0]                        ls_byte_off;
wire [7:0]                        ls_load_byte;
wire [15:0]                       ls_load_half;
wire [3:0]                        sh_wren;
wire [`SUAT_DATA]                 sh_wdata;

// regfile
wire [`SUAT_REG] 				reg_id_rs1_data;
wire [`SUAT_REG] 				reg_id_rs2_data;

SUAT_ifu ifu0(
     .clk     (clk       		)
	,.rst     (rst       		)
	,.jump 	  (exu_jump   		)
	,.jump_pc (exu_jump_pc		)
	,.inst_i  (if_sram_rdata  )
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
	,.lsu_op	(lsu_op					)

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

SUAT_lsu lsu3(
 .addr		(exu_data			)
,.wdata_i	(reg_id_rs2_data	)
,.rdata_i	(ls_sram_rdata		)
,.lsu_op	(lsu_op				)
,.WREN		(lsu_wren_raw		)
,.wdata_o	(lsu_wdata_raw		)
,.rdata_o	(lsu_rdata_raw		)
);

SUAT_wbu wbu4(
	 .wb_ctl	(id_wb_ctl  			)
	,.exu_res	(exu_data 				)
	,.lsu_res	(ls_wb_data 			)
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

SUAT_sram imem6(
	 .CLK	(clk				)
	,.ADDR	(if_id_pc[15:2]		)
	,.WDATA	(`SUAT_ZERO32		)
	,.WREN	(4'b0000			)
	,.RDATA	(if_sram_rdata		)
);

SUAT_sram mem6(
	 .CLK	(clk				)
	,.ADDR	(lsu_rdata_raw[15:2])
	,.WDATA	(lsu_wdata_raw		)
	,.WREN	(lsu_wren_raw		)
	,.RDATA	(ls_sram_rdata		)
);

// Debug assignments
assign debug_pc = if_id_pc;
assign debug_lsu_addr = ls_sram_addr;
assign debug_lsu_wdata = ls_sram_wdata;
assign debug_lsu_wren = ls_sram_wren;

assign debug_gpr0 = reg5.regs[0];
assign debug_gpr1 = reg5.regs[1];
assign debug_gpr2 = reg5.regs[2];
assign debug_gpr3 = reg5.regs[3];
assign debug_gpr4 = reg5.regs[4];
assign debug_gpr5 = reg5.regs[5];
assign debug_gpr6 = reg5.regs[6];
assign debug_gpr7 = reg5.regs[7];
assign debug_gpr8 = reg5.regs[8];
assign debug_gpr9 = reg5.regs[9];
assign debug_gpr10 = reg5.regs[10];
assign debug_gpr11 = reg5.regs[11];
assign debug_gpr12 = reg5.regs[12];
assign debug_gpr13 = reg5.regs[13];
assign debug_gpr14 = reg5.regs[14];
assign debug_gpr15 = reg5.regs[15];
assign debug_gpr16 = reg5.regs[16];
assign debug_gpr17 = reg5.regs[17];
assign debug_gpr18 = reg5.regs[18];
assign debug_gpr19 = reg5.regs[19];
assign debug_gpr20 = reg5.regs[20];
assign debug_gpr21 = reg5.regs[21];
assign debug_gpr22 = reg5.regs[22];
assign debug_gpr23 = reg5.regs[23];
assign debug_gpr24 = reg5.regs[24];
assign debug_gpr25 = reg5.regs[25];
assign debug_gpr26 = reg5.regs[26];
assign debug_gpr27 = reg5.regs[27];
assign debug_gpr28 = reg5.regs[28];
assign debug_gpr29 = reg5.regs[29];
assign debug_gpr30 = reg5.regs[30];
assign debug_gpr31 = reg5.regs[31];

endmodule
