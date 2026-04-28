`include "define.v"

module SUAT_top(
	 input wire              	clk		  
	,input wire              	rst
);

// ifu
wire [`SUAT_INST]                 if_inst_o;
wire [`SUAT_PC]                   if_pc_o;
wire [`SUAT_PC]					  if_snpc_o;
wire [`SUAT_INST]                 iram_rdata;

// idu
wire [`SUAT_REGADDR] 		  	id_rs1_addr ;
wire [`SUAT_REGADDR] 		  	id_rs2_addr ;
wire [`SUAT_REGADDR] 		  	id_rd_addr  ;
wire                          	id_rs1_ren	;
wire                          	id_rs2_ren	;

wire [`SUAT_DATA]				id_data1;
wire [`SUAT_DATA]				id_data2;
wire [`SUAT_DATA]				id_data3;
wire [`SUAT_DATA]				id_data4;
wire [17:0]						id_exu_op;
wire [3:0]                      id_lsu_op;
wire [2:0]     		   		 	id_wbu_op;

// exu
wire [`SUAT_DATA]				exu_addr;
wire [`SUAT_DATA] 	     		exu_data;
wire                            exu_jump;
wire [`SUAT_PC]                 exu_jump_pc;

// lsu
wire [`SUAT_DATA]                 ls_wb_data;
wire [31:0]                       ls_addr;
wire [`SUAT_DATA]                 ls_wdata;
wire [3:0]                        ls_wren;

// wbu
wire [`SUAT_DATA]	   			wb_rd_data;
wire							wb_wen;

// regfile
wire [`SUAT_REG] 				rf_rs1_data;
wire [`SUAT_REG] 				rf_rs2_data;
wire                            rf_rd_wen;
wire [`SUAT_DATA]				rf_rd_data;

// data sram
wire [15:0]	ls_sram_addr;
wire [31:0] ls_sram_wdata;
wire [3:0]	ls_sram_wren;
wire [31:0] ls_sram_rdata;

assign ls_sram_addr = ls_addr[15:0];
assign ls_sram_wdata = ls_wdata;
assign ls_sram_wren = (ls_wren & {4{ex_mem_valid}});

// control signals
wire jump;
wire wbu_commit;
wire [31:0] jump_pc;

// registers
reg        if_id_valid;
reg [31:0] if_id_pc;
reg [31:0] if_id_inst;
reg [31:0] if_id_snpc;

reg        id_ex_valid;
reg [31:0] id_ex_data1;
reg [31:0] id_ex_data2;
reg [31:0] id_ex_data3;
reg [31:0] id_ex_data4;
reg [17:0] id_ex_exu_op;
reg [3:0]  id_ex_lsu_op;
reg [2:0]  id_ex_wbu_op;
reg [4:0]  id_ex_rd_addr;

reg        ex_mem_valid;
reg [31:0] ex_mem_addr;
reg [31:0] ex_mem_data;
reg [3:0]  ex_mem_lsu_op;
reg [2:0]  ex_mem_wbu_op;
reg [4:0]  ex_mem_rd_addr;

reg        mem_wb_valid;
reg [31:0] mem_wb_exu_data;
reg [31:0] mem_wb_lsu_data;
reg [2:0]  mem_wb_wbu_op;
reg [4:0]  mem_wb_rd_addr;

/*
reg [2:0] state;
localparam S_IF  = 3'd0;
localparam S_ID  = 3'd1;
localparam S_EX  = 3'd2;
localparam S_MEM = 3'd3;
localparam S_WB  = 3'd4;
*/

// You can use the FSM to control the state transitions of the multi-cycle processor.

SUAT_ifu ifu0(
     .clk     		(clk       		)
	,.rst     		(rst       		)
	,.jump   		(jump   		)
	,.jump_pc 		(jump_pc		)
	,.id_allow_in	(id_allow_in	)
	,.inst_i  		(iram_rdata  	)
	,.inst_o  		(if_inst_o		)
	,.pc_o    		(if_pc_o  		)
	,.snpc_o   		(if_snpc_o		)
);

// if2id register
always @(posedge clk) begin
	if (rst == `SUAT_RSTABLE) begin
		if_id_valid <= 0;
		if_id_pc <= `SUAT_ZERO32;
		if_id_inst <= `SUAT_ZERO32;
		if_id_snpc <= `SUAT_ZERO32;
	end
	// TODO
end

SUAT_idu idu1(
     .inst_i	(if_id_inst				)
	,.pc_i	  	(if_id_pc				)
	,.snpc		(if_id_snpc				)

	,.rs1_addr 	(id_rs1_addr			)
	,.rs1_ren	(id_rs1_ren				)
	,.rs1_data	(rf_rs1_data			)

	,.rs2_addr	(id_rs2_addr			)
	,.rs2_ren	(id_rs2_ren				)
	,.rs2_data	(rf_rs2_data			)

	,.rd_addr	(id_rd_addr				)

	,.exu_op	(id_exu_op				)
	,.wbu_op	(id_wbu_op				)
	,.lsu_op	(id_lsu_op				)

	,.data1		(id_data1				)
	,.data2		(id_data2				)
	,.data3		(id_data3				)
	,.data4		(id_data4				)
);

// id2ex register
always @(posedge clk) begin
	if (rst == `SUAT_RSTABLE) begin
		id_ex_valid <= 0;
		id_ex_data1 <= `SUAT_ZERO32;
		id_ex_data2 <= `SUAT_ZERO32;
		id_ex_data3 <= `SUAT_ZERO32;
		id_ex_data4 <= `SUAT_ZERO32;
		id_ex_exu_op <= 0;
		id_ex_lsu_op <= 0;
		id_ex_wbu_op <= 0;
		id_ex_rd_addr <= 0;
	end
	// TODO
end

SUAT_exu exu2(
	 .data1       (id_ex_data1	        )
	,.data2       (id_ex_data2         	)
	,.data3       (id_ex_data3         	)
	,.data4       (id_ex_data4         	)
	,.exu_op	  (id_ex_exu_op			)
	,.exu_jump	  (exu_jump				)
	,.exu_jump_pc (exu_jump_pc			)
	,.exu_addr    (exu_addr				)
	,.exu_data    (exu_data				)
);

// ex2mem register
always @(posedge clk) begin
	if (rst == `SUAT_RSTABLE) begin
		ex_mem_valid <= 0;
		ex_mem_addr <= `SUAT_ZERO32;
		ex_mem_data <= `SUAT_ZERO32;
		ex_mem_lsu_op <= 0;
		ex_mem_wbu_op <= 0;
		ex_mem_rd_addr <= 0;
	end
	// TODO
end

assign jump =;
assign jump_pc =;

SUAT_mem mem3(
 .addr_i	(ex_mem_addr		)
,.wdata_i	(ex_mem_data		)
,.rdata_i	(ls_sram_rdata		)
,.lsu_op	(ex_mem_lsu_op		)
,.WREN		(ls_wren		)
,.addr_o	(ls_addr		)
,.wdata_o	(ls_wdata		)
,.rdata_o	(ls_wb_data			)
);

// mem2wb register
always @(posedge clk) begin
	if (rst == `SUAT_RSTABLE) begin
		mem_wb_valid <= 0;
		mem_wb_exu_data <= `SUAT_ZERO32;
		mem_wb_lsu_data <= `SUAT_ZERO32;
		mem_wb_wbu_op <= 0;
		mem_wb_rd_addr <= 0;
	end
	// TODO
end

assign wbu_commit = ;

SUAT_wbu wbu4(
	 .wbu_op		(mem_wb_wbu_op			)
	,.exu_res		(mem_wb_exu_data 		)
	,.mem_res		(mem_wb_lsu_data 		)
	,.wb_data		(wb_rd_data 			)
	,.wb_wen		(wb_wen					)
);

SUAT_regfile reg5(
	 .clk  		(clk				)
	,.rst  		(rst				)
	,.waddr		(			)
	,.wdata		(			)
	,.wen    	( 			)
	,.raddr1 	(id_rs1_addr		)
	,.rdata1 	(rf_rs1_data		)
	,.ren1  	(id_rs1_ren 		)
	,.raddr2	(id_rs2_addr		)
	,.rdata2	(rf_rs2_data		)
	,.ren2 		(id_rs2_ren 		)
);

SUAT_sram imem6(
	 .CLK	(clk				)
	,.ADDR	(if_pc_o[15:2]		)
	,.WDATA	(`SUAT_ZERO32		)
	,.WREN	(4'b0000			)
	,.RDATA	(iram_rdata			)
);

SUAT_sram dmem7(
	 .CLK	(clk				)
	,.ADDR	(ls_sram_addr[15:2])
	,.WDATA	(ls_sram_wdata		)
	,.WREN	(ls_sram_wren		)
	,.RDATA	(ls_sram_rdata		)
);

endmodule
