`include "define.v"

module ysyx_25060170_exu(
    input wire          clk,
    input wire          rst,
    input wire [`ysyx_25060170_DATA] op1,
    input wire [`ysyx_25060170_DATA] op2,
    input wire [`ysyx_25060170_IMM] imm,
    input wire [`ysyx_25060170_PC] pc_i,
    input wire            jump_i,
    input wire [ 7:0]     alu_sel,
    input wire            branch_i,
    input wire [3:0]      csr_ctl,
    
    output wire [`ysyx_25060170_REG] store_data,//
    output wire [`ysyx_25060170_PC] jump_pc_o,//
    output wire ex_pcsrc_o,//
    output reg [`ysyx_25060170_DATA] exu_res,//
	  output wire [`ysyx_25060170_REG]  csr_ex_mstatus     ,//
	  output wire [`ysyx_25060170_REG]  csr_ex_mepc        ,//
	  output wire [`ysyx_25060170_REG]  csr_ex_mtvec       ,//
	  output wire [`ysyx_25060170_REG]  csr_ex_mcause      //
);

// 32-bit operations
wire [`ysyx_25060170_DATA] op1_add_op2 = op1 + op2;

wire [`ysyx_25060170_DATA] op1_sub_op2 = $signed(op1) - $signed(op2);

// SLT / SLTI / SLTIU
wire op1_lt_op2 = (op1[31] && ~op2[31]) || (~op1[31] && ~op2[31] && op1_sub_op2[31]) || (op1[31] && op2[31] && op1_sub_op2[31]);

// SRA / SRAI
wire [`ysyx_25060170_DATA] op1_sra_op2 = $signed(op1) >>> op2[4:0];  // 32-bit shift uses [4:0]

// MUL / MULH
wire [63:0] mul = $signed(op1) * $signed(op2);  // 32x32=64 multiplication
wire [`ysyx_25060170_DATA] op1_mul_op2 = mul[31:0];  // 32-bit result
wire [`ysyx_25060170_DATA] op1_mulh_op2 = mul[63:32];  // 32-bit upper half

// DIV / DIVU
wire [`ysyx_25060170_DATA] div = $signed(op1) / $signed(op2);

// REM / REMU
wire [`ysyx_25060170_DATA] rem = $signed(op1) % $signed(op2);

reg [`ysyx_25060170_DATA] alu_res;

always@(*) begin
  if(rst == `ysyx_25060170_RSTABLE) begin
    alu_res = `ysyx_25060170_ZERO32;
  end
  else begin
    case(alu_sel)
      `INST_ADDI, `INST_ADD,
      `INST_LUI, `INST_AUIPC: begin alu_res = op1_add_op2; end

      `INST_LB, `INST_LH,
      `INST_LW, `INST_LBU,
      `INST_LHU, `INST_SB,
      `INST_SH, `INST_SW: begin alu_res = op1 + imm; end

      `INST_SUB: begin alu_res = op1_sub_op2; end

      `INST_SLTI, `INST_SLT: begin alu_res = {31'd0, op1_lt_op2}; end
      `INST_SLTIU, `INST_SLTU: begin alu_res = {31'd0, (op1 < op2)}; end
      `INST_SRAI, `INST_SRA: begin alu_res = op1_sra_op2; end
      `INST_XORI, `INST_XOR: begin alu_res = op1 ^ op2; end
      `INST_ORI, `INST_OR: begin alu_res = op1 | op2; end
      `INST_ANDI, `INST_AND: begin alu_res = op1 & op2; end
      `INST_SLLI, `INST_SLL: begin alu_res = op1 << op2[4:0]; end  // 32-bit shift uses [4:0]
      `INST_SRLI, `INST_SRL: begin alu_res = op1 >> op2[4:0]; end  // 32-bit shift uses [4:0]
      `INST_JAL, `INST_JALR: begin alu_res = pc_i + 32'd4; end
      `INST_EBREAK: begin alu_res = op1; end

      `INST_MUL: begin alu_res = op1_mul_op2; end
      `INST_MULH: begin alu_res = op1_mulh_op2; end

      `INST_DIV, `INST_DIVU: begin alu_res = div; end

      `INST_REM, `INST_REMU: begin alu_res = rem; end

      default: begin
        alu_res = `ysyx_25060170_ZERO32;
      end
    endcase
  end
end

reg ex_branch;

always @(*) begin
  if(~branch_i) begin
    ex_branch = `ysyx_25060170_BRANCHDISABLE;
  end
  else begin
    case (alu_sel)
      `INST_BEQ: begin ex_branch = (op1 == op2) ? `ysyx_25060170_BRANCHABLE : `ysyx_25060170_BRANCHDISABLE; end
      `INST_BNE: begin ex_branch = (op1 != op2) ? `ysyx_25060170_BRANCHABLE : `ysyx_25060170_BRANCHDISABLE; end
      `INST_BLTU: begin ex_branch = (op1 < op2) ? `ysyx_25060170_BRANCHABLE : `ysyx_25060170_BRANCHDISABLE; end
      `INST_BGEU: begin ex_branch = (op1 >= op2) ? `ysyx_25060170_BRANCHABLE : `ysyx_25060170_BRANCHDISABLE; end
      `INST_BLT: begin ex_branch = (op1_lt_op2) ? `ysyx_25060170_BRANCHABLE : `ysyx_25060170_BRANCHDISABLE; end
      `INST_BGE: begin ex_branch = (~op1_lt_op2) ? `ysyx_25060170_BRANCHABLE : `ysyx_25060170_BRANCHDISABLE; end
      default: begin ex_branch = `ysyx_25060170_BRANCHDISABLE; end
    endcase
  end
end

// Out to IFU
assign ex_pcsrc_o = jump_i | ex_branch | csr_ctl[1] | csr_ctl[0];
assign jump_pc_o = (alu_sel == `INST_JAL | branch_i) ? pc_i + imm :
                   (alu_sel == `INST_JALR) ? (op1 + imm) & ~32'd1 :  // JALR clears least significant bit
                   (csr_ctl[1] | csr_ctl[0]) ? read_csr_data :
                   `ysyx_25060170_ZERO32;

// Out to LSU
assign store_data = op2;

// CSR
wire [11:0] csr_addr = (csr_ctl != 4'd0) ? imm[11:0] : 12'd0;
wire [`ysyx_25060170_DATA] read_csr_data;
reg [`ysyx_25060170_DATA] write_csr_data;
reg [`ysyx_25060170_REG] mcause_value;


wire [`ysyx_25060170_DATA] set_data = read_csr_data | op1;
wire [`ysyx_25060170_DATA] clear_data = read_csr_data & (~op1);


always @(*) begin
  write_csr_data = `ysyx_25060170_ZERO32;
  mcause_value = `ysyx_25060170_ZERO32;
  case(alu_sel)
    `INST_ECALL: begin write_csr_data = pc_i; mcause_value = 32'd11; end

    `INST_CSRRW, `INST_CSRRWI: begin write_csr_data = op1; end

    `INST_CSRRS, `INST_CSRRSI: begin write_csr_data = set_data; end

    `INST_CSRRC, `INST_CSRRCI: begin write_csr_data = clear_data; end

    default: begin
      write_csr_data = `ysyx_25060170_ZERO32;
      mcause_value = `ysyx_25060170_ZERO32;
    end
  endcase
end

ysyx_25060170_csr csr_operate(
    .clk(clk),  //
    .rst(rst),  //
    .csr_ctl(csr_ctl),//
    .csr_addr(csr_addr),//
    .mcause_value(mcause_value),//
    .read_csr_data(read_csr_data),//
    .write_csr_data(write_csr_data),//
	.mstatus_o(csr_ex_mstatus),
	.mepc_o   (csr_ex_mepc   ),
	.mtvec_o  (csr_ex_mtvec  ),
	.mcause_o (csr_ex_mcause )
);

// Out to WBU
assign exu_res = (csr_ctl != 4'd0) ? read_csr_data : alu_res;

endmodule


