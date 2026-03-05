`include "define.v"

module ysyx_25060170_csr(
  input wire                        clk           ,   //
  input wire                        rst           ,
  input wire [3:0]                  csr_ctl       ,  // {csr_wr_ena, csr_rd_ena, ecall_ena, mret_ena}
  input wire [11:0]                 csr_addr      ,
  input wire [`ysyx_25060170_REG]   mcause_value  ,
  input wire [`ysyx_25060170_DATA]  write_csr_data,
  output wire [`ysyx_25060170_DATA] read_csr_data ,
  output wire [`ysyx_25060170_REG]  mstatus_o     ,
  output wire [`ysyx_25060170_REG]  mepc_o        ,
  output wire [`ysyx_25060170_REG]  mtvec_o       ,
  output wire [`ysyx_25060170_REG]  mcause_o      
);

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 0X300 mstatus
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire mstatus_rd = (csr_addr == 12'h300) && csr_ctl[2];
wire mstatus_wr = (csr_addr == 12'h300) && csr_ctl[3];
reg mstatus_mie;
reg mstatus_mpie;
reg [1:0] mstatus_mpp;
reg [`ysyx_25060170_REG] mstatus;  // 删除初始赋值

wire mstatus_ie_ena = mstatus_wr | csr_ctl[1] | csr_ctl[0];

wire mie_set = csr_ctl[1] ? 1'b0 : 
               csr_ctl[0] ? mstatus_mpie : 
                            mstatus_wr ? write_csr_data[3] :
                            mstatus_mie;

wire mpie_set = csr_ctl[1] ? mstatus_mie :
                csr_ctl[0] ? 1'b1 :
                            mstatus_wr ? write_csr_data[7] :
                            mstatus_mpie;

wire [1:0] mpp_set = csr_ctl[1] ? 2'b11 : 
                      csr_ctl[0] ? 2'b00 :
                                   mstatus_wr ? write_csr_data[14:13] :
                                   mstatus_mpp;

always@(posedge clk) begin
  if(rst == `ysyx_25060170_RSTABLE) begin 
    mstatus <= `ysyx_25060170_ZERO32;  // 复位时初始化
  end
  else if(mstatus_ie_ena) begin 
    mstatus_mie <= mie_set;
    mstatus_mpie <= mpie_set;
    mstatus_mpp <= mpp_set; 
  end
  else begin 
    mstatus <= mstatus;
  end
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 0x305 mtvec
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire mtvec_rd = ((csr_addr == 12'h305) && csr_ctl[2]) | csr_ctl[1];
wire mtvec_wr = ((csr_addr == 12'h305) && csr_ctl[3]);

reg [31:2] mtvec_base;  // 修改为32位寄存器
always@(posedge clk) begin
  if(rst == `ysyx_25060170_RSTABLE) begin 
    mtvec_base <= 30'd0;  // 32位
  end
  else if(mtvec_wr) begin 
    mtvec_base <= write_csr_data[31:2];  // 修改为32位基址
  end
  else begin 
    mtvec_base <= mtvec_base; 
  end
end

wire [1:0] mtvec_mode;
assign mtvec_mode = 2'b00;
wire [`ysyx_25060170_REG] mtvec = {mtvec_base, mtvec_mode};

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 0x341 mepc
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire mepc_rd = ((csr_addr == 12'h341) && csr_ctl[2]) | csr_ctl[0];
wire mepc_wr = ((csr_addr == 12'h341) && csr_ctl[3]) | csr_ctl[1];

reg [`ysyx_25060170_REG] mepc;
always@(posedge clk) begin
  if(rst == `ysyx_25060170_RSTABLE) begin 
    mepc <= `ysyx_25060170_ZERO32; 
  end
  else if(mepc_wr) begin 
    mepc <= write_csr_data; 
  end
  else begin 
    mepc <= mepc;
  end
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 0x342 mcause
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire mcause_rd = ((csr_addr == 12'h342) && csr_ctl[2]);
wire mcause_wr = ((csr_addr == 12'h342) && csr_ctl[3]);
reg [`ysyx_25060170_REG] mcause;

always@(posedge clk) begin
  if(rst == `ysyx_25060170_RSTABLE) begin 
    mcause <= `ysyx_25060170_ZERO32; 
  end
  else if(mcause_wr) begin 
    mcause <= write_csr_data; 
  end
  else if(csr_ctl[1]) begin 
    mcause <= mcause_value; 
  end
  else begin 
    mcause <= mcause;
  end
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Read CSR Data
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
assign read_csr_data = mstatus_rd ? mstatus :
                       mepc_rd    ? mepc   :
                       mtvec_rd   ? mtvec  : 
                       mcause_rd  ? mcause :
                       `ysyx_25060170_ZERO32;

assign mstatus_o = mstatus;
assign mepc_o    = mepc   ;
assign mtvec_o   = mtvec  ;
assign mcause_o  = mcause ;

endmodule

