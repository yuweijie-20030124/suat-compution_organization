`include "define.v"

module SUAT_top(
	 input wire              	clk		  
	,input wire              	rst
	,input wire                 rx_pad
	,output wire                tx_pad
);

// ifu
wire [`SUAT_INST]               if_inst_o;
wire [`SUAT_PC]                 if_pc_o;
wire [`SUAT_PC]                 if_snpc_o;
wire                            if_valid_o;
wire [`SUAT_INST]               iram_rdata;

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
wire [4:0]                      id_lsu_op;
wire [2:0]     		   		 	id_wbu_op;

// exu
wire [`SUAT_DATA]				exu_addr;
wire [`SUAT_DATA] 	     		exu_data;
wire                            exu_jump;
wire [`SUAT_PC]                 exu_jump_pc;

// mem
wire [`SUAT_DATA]               mem_wb_data;
wire [31:0]                     mem_addr;
wire [`SUAT_DATA]               mem_wdata;
wire [3:0]                      mem_wren;
wire 						    mem_rden;

// wbu
wire [`SUAT_DATA]	   			wb_rd_data;
wire							wb_wen;

// regfile
wire [`SUAT_REG] 				rf_rs1_data;
wire [`SUAT_REG] 				rf_rs2_data;
wire                            rf_rd_wen;
wire [`SUAT_DATA]				rf_rd_data;

// data sram

// Pipeline control signals
wire id_allow_in, ex_allow_in, mem_allow_in, wb_allow_in;
wire flush;
wire wbu_commit;
wire [31:0] flush_pc;

// Pipeline registers
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
reg [4:0]  id_ex_lsu_op;
reg [2:0]  id_ex_wbu_op;
reg [4:0]  id_ex_rd_addr;

reg        ex_mem_valid;
reg [31:0] ex_mem_addr;
reg [31:0] ex_mem_data;
reg [4:0]  ex_mem_lsu_op;
reg [2:0]  ex_mem_wbu_op;
reg [4:0]  ex_mem_rd_addr;

reg        mem_wb_valid;
reg [31:0] mem_wb_exu_data;
reg [31:0] mem_wb_lsu_data;
reg [2:0]  mem_wb_wbu_op;
reg [4:0]  mem_wb_rd_addr;

reg [2:0] state;
localparam S_IF  = 3'd0;
localparam S_ID  = 3'd1;
localparam S_EX  = 3'd2;
localparam S_MEM = 3'd3;
localparam S_WB  = 3'd4;

always @(posedge clk) begin
    if (rst) begin
        state <= S_IF;
    end else begin
        case (state)
            S_IF:  state <= S_ID;
            S_ID:  state <= S_EX;
            S_EX:  state <= S_MEM;
            S_MEM: state <= S_WB;
            S_WB:  state <= S_IF;
            default: state <= S_IF;
        endcase
    end
end

assign id_allow_in  = (state == S_ID);
assign ex_allow_in  = (state == S_EX);
assign mem_allow_in = (state == S_MEM);
assign wb_allow_in  = (state == S_WB);

SUAT_ifu ifu0(
     .clk     		(clk       		)
	,.rst     		(rst       		)
	,.flush   		(flush   		)
	,.flush_pc 		(flush_pc		)
	,.id_allow_in	(id_allow_in	)
	,.inst_i  		(iram_rdata  	)
	,.inst_o  		(if_inst_o		)
	,.pc_o    		(if_pc_o  		)
	,.snpc_o   		(if_snpc_o		)
	,.if_valid_o	(if_valid_o		)
);

// if2id register
always @(posedge clk) begin
	if (rst == `SUAT_RSTABLE) begin
		if_id_valid <= 0;
		if_id_pc <= `SUAT_ZERO32;
		if_id_inst <= `SUAT_ZERO32;
		if_id_snpc <= `SUAT_ZERO32;
	end
	else if (flush) begin
		if_id_valid <= 0;
	end
	else if (id_allow_in) begin
		if_id_valid <= 1;
		if_id_pc <= if_pc_o;
		if_id_inst <= if_inst_o;
		if_id_snpc <= if_snpc_o;
	end
	else begin
		if_id_valid <= 0;
	end
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
	else if (flush) begin
		id_ex_valid <= 0;
	end
	else if (ex_allow_in) begin
		id_ex_valid <= if_id_valid;
		id_ex_data1 <= id_data1;
		id_ex_data2 <= id_data2;
		id_ex_data3 <= id_data3;
		id_ex_data4 <= id_data4;
		id_ex_exu_op <= id_exu_op;
		id_ex_lsu_op <= id_lsu_op;
		id_ex_wbu_op <= id_wbu_op;
		id_ex_rd_addr <= id_rd_addr;
	end
	else begin
		id_ex_valid <= 0;
	end
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
	else if (mem_allow_in) begin
		ex_mem_valid <= id_ex_valid;
		ex_mem_addr <= exu_addr;
		ex_mem_data <= exu_data;
		ex_mem_lsu_op <= id_ex_lsu_op;
		ex_mem_wbu_op <= id_ex_wbu_op;
		ex_mem_rd_addr <= id_ex_rd_addr;
	end
	else begin
		ex_mem_valid <= 0;
	end
end

assign flush = exu_jump & id_ex_valid; // 只有当 id_ex_valid 时才允许跳转
assign flush_pc = exu_jump_pc;

wire [3:0]  ls_wren;
wire        ls_rden;
wire [31:0] ls_addr;
wire [31:0] ls_wdata;
wire [31:0] mem_rdata;

assign mem_wren = ex_mem_valid ? ls_wren : 4'b0000;
assign mem_rden = ex_mem_valid ? ls_rden : 1'b0;
assign mem_addr  = ls_addr;
assign mem_wdata = ls_wdata;

SUAT_mem mem3(
 .addr_i	(ex_mem_addr		)
,.wdata_i	(ex_mem_data		)
,.rdata_i	(mem_rdata		)
,.lsu_op	(ex_mem_lsu_op		)
,.WREN		(ls_wren			)
,.RDEN		(ls_rden			)
,.addr_o	(ls_addr			)
,.wdata_o	(ls_wdata			)
,.rdata_o	(mem_wb_data			)
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
	else if (wb_allow_in) begin
		mem_wb_valid <= ex_mem_valid;
		mem_wb_exu_data <= ex_mem_data;
		mem_wb_lsu_data <= mem_wb_data;
		mem_wb_wbu_op <= ex_mem_wbu_op;
		mem_wb_rd_addr <= ex_mem_rd_addr;
	end
	else begin
		mem_wb_valid <= 0;
	end
end

assign wbu_commit = mem_wb_valid;
assign rf_rd_wen = mem_wb_valid & wb_wen;
assign rf_rd_data = wb_rd_data;

SUAT_wbu wbu4(
	 .wbu_op		(mem_wb_wbu_op			)
	,.exu_res		(mem_wb_exu_data 		)
	,.lsu_res		(mem_wb_lsu_data 		)
	,.wb_data		(wb_rd_data 			)
	,.wb_wen		(wb_wen					)
);

SUAT_regfile reg5(
	 .clk  		(clk					)
	,.rst  		(rst					)
	,.waddr		(mem_wb_rd_addr			)
	,.wdata		(rf_rd_data				)
	,.wen    	(rf_rd_wen 				)
	,.raddr1 	(id_rs1_addr		)
	,.rdata1 	(rf_rs1_data		)
	,.ren1  	(id_rs1_ren 		)
	,.raddr2	(id_rs2_addr		)
	,.rdata2	(rf_rs2_data		)
	,.ren2 		(id_rs2_ren 		)
);

wire imem_rden = (if_pc_o[31:16] == 16'h8000) & if_valid_o;

wire [31:0] imem2c_data_i;
wire [31:0] dmem2c_data_i;
wire [31:0] uart2c_data_i;

wire [3:0]  c2dmem_wren_o;
wire [3:0]  c2uart_wren_o;
wire        c2imem_rden_o;
wire        c2dmem_rden_o;
wire        c2uart_rden_o;

SUAT_imem imem6(
	 .CLK	(clk				)
	,.ADDR1 (if_pc_o[15:2]      )
	,.RDEN1 (imem_rden          )
	,.ADDR2 (ls_addr[15:2]		)
	,.WREN2	(4'b0000			)
	,.WDATA2(`SUAT_ZERO32		)
	,.RDEN2 (c2imem_rden_o		)
	,.RDATA1(iram_rdata			)
	,.RDATA2(imem2c_data_i		)
);

mux u_mux(
     .addr_i			(mem_addr[31:16])
    ,.wren_i			(mem_wren		)
    ,.rden_i			(mem_rden		)
	,.imem2c_data_i		(imem2c_data_i	)
    ,.dmem2c_data_i		(dmem2c_data_i	)
    ,.uart2c_data_i		(uart2c_data_i	)
    ,.c2dmem_wren_o		(c2dmem_wren_o	)
    ,.c2uart_wren_o		(c2uart_wren_o	)
    ,.c2imem_rden_o		(c2imem_rden_o	)
    ,.c2dmem_rden_o		(c2dmem_rden_o	)
    ,.c2uart_rden_o		(c2uart_rden_o	)
    ,.rdata				(mem_rdata		)
);

SUAT_dmem dmem7(
	 .CLK	(clk				)
	,.ADDR	(ls_addr[15:2]		)
	,.WDATA	(ls_wdata			)
	,.WREN	(c2dmem_wren_o		)
	,.RDEN  (c2dmem_rden_o		)
	,.RDATA	(dmem2c_data_i		)
);

uart u_uart(
   .CLK			(clk			)
  ,.RST		    (rst			)
  ,.ADDR		(ls_addr[15:0]	)
  ,.WDATA		(ls_wdata		)
  ,.WREN		(c2uart_wren_o	)
  ,.RDEN		(c2uart_rden_o	)
  ,.RDATA		(uart2c_data_i	)
  ,.rx_pad		(rx_pad			)
  ,.tx_pad		(tx_pad			)
);

endmodule
