`include "define.v"

module SUAT_top(
	 input wire              	clk		  
	,input wire              	rst
	// Debug outputs
	,output wire [`SUAT_PC]   debug_pc
	,output wire [15:0]       debug_lsu_addr
	,output wire [`SUAT_DATA] debug_lsu_wdata
	,output wire [3:0]        debug_lsu_wren
);

// ifu
wire [`SUAT_INST]                 if_id_inst;
wire [`SUAT_PC]                   if_id_pc;
wire [`SUAT_PC]					  if_id_snpc;
wire [`SUAT_INST]                 if_sram_rdata;

// idu
wire [`SUAT_REGADDR] 		  	id_reg_rs1_addr ;
wire [`SUAT_REGADDR] 		  	id_reg_rs2_addr ;
wire [`SUAT_REGADDR] 		  	id_reg_rd_addr  ;
wire                          	id_reg_rs1_ren	;
wire                          	id_reg_rs2_ren	;

wire [TODO:0]     		   		id_wb_ctl;
wire [`SUAT_DATA]				data1;
wire [`SUAT_DATA]				data2;
wire [`SUAT_DATA]				data3;
wire [`SUAT_DATA]				data4;

// exu
wire [TODO:0]					exu_op;
wire [`SUAT_DATA]				exu_addr;		
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
wire [`SUAT_DATA]                 ls_sram_rdata;
wire [TODO:0]                     lsu_op;
wire [3:0]                        lsu_wren_raw;
wire [`SUAT_DATA]                 lsu_wdata_raw;
wire [`SUAT_DATA]                 lsu_rdata_raw;

// regfile
wire [`SUAT_REG] 				reg_id_rs1_data;
wire [`SUAT_REG] 				reg_id_rs2_data;

assign ls_wb_data   = lsu_rdata_raw;
assign ls_sram_wdata = lsu_wdata_raw;
assign ls_sram_wren = lsu_wren_raw;

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
	,.exu_addr    (exu_addr			)
	,.exu_data    (exu_data			)
);

SUAT_lsu lsu3(
 .addr_i	(exu_addr			)
,.wdata_i	(exu_data			)
,.rdata_i	(ls_sram_rdata		)
,.lsu_op	(lsu_op				)
,.WREN		(lsu_wren_raw		)
,.addr_o	(ls_sram_addr		)
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
	,.ADDR	(ls_sram_addr[15:2])
	,.WDATA	(ls_sram_wdata		)
	,.WREN	(ls_sram_wren		)
	,.RDATA	(ls_sram_rdata		)
);

// Debug assignments
assign debug_pc = if_id_pc;
assign debug_lsu_addr = (ls_sram_wren != 4'b0000) ? ls_sram_addr : 16'h0000;
assign debug_lsu_wdata = (ls_sram_wren != 4'b0000) ? ls_sram_wdata : `SUAT_ZERO32;
assign debug_lsu_wren = ls_sram_wren;

endmodule
