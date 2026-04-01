`timescale 1ns/1ps
`include "../rtl/define.v"

module rv32i_supported_instr_tb;

localparam [6:0] OPCODE_LUI    = 7'b0110111;
localparam [6:0] OPCODE_AUIPC  = 7'b0010111;
localparam [6:0] OPCODE_JAL    = 7'b1101111;
localparam [6:0] OPCODE_JALR   = 7'b1100111;
localparam [6:0] OPCODE_BRANCH = 7'b1100011;
localparam [6:0] OPCODE_OPIMM  = 7'b0010011;
localparam [6:0] OPCODE_OP     = 7'b0110011;

localparam [2:0] F3_ADD_SUB = 3'b000;
localparam [2:0] F3_SLL     = 3'b001;
localparam [2:0] F3_SLT     = 3'b010;
localparam [2:0] F3_SLTU    = 3'b011;
localparam [2:0] F3_XOR     = 3'b100;
localparam [2:0] F3_SRL_SRA = 3'b101;
localparam [2:0] F3_OR      = 3'b110;
localparam [2:0] F3_AND     = 3'b111;

localparam [31:0] START_PC    = `SUAT_STARTPC;
localparam integer IMEM_WORDS = 4096;
localparam integer MAX_CYCLES = 30000;

reg clk;
reg rst;
wire [31:0] tb_if_pc;
reg  [31:0] tb_if_inst;
wire tb_ex_jump;
wire [31:0] tb_ex_jump_pc;
wire [31:0] tb_ex_res;

reg [31:0] imem [0:IMEM_WORDS-1];
reg [31:0] model_regs [0:31];
reg [31:0] expected_regs [0:IMEM_WORDS-1][0:31];
reg [31:0] expected_next_pc [0:IMEM_WORDS-1];
reg [31:0] expected_inst [0:IMEM_WORDS-1];
reg        expected_valid [0:IMEM_WORDS-1];

integer i;
integer r;
integer prog_words;
integer step_count;
integer fail_count;
integer done_idx;
integer total_cases;
reg done;

SUAT_top dut (
     .clk          (clk)
    ,.rst          (rst)
    ,.tb_if_inst   (tb_if_inst)
    ,.tb_if_pc     (tb_if_pc)
    ,.tb_ex_jump   (tb_ex_jump)
    ,.tb_ex_jump_pc(tb_ex_jump_pc)
    ,.tb_ex_res    (tb_ex_res)
);

always @(*) begin
    if (^tb_if_pc === 1'bx) tb_if_inst = 32'h00000013;
    else tb_if_inst = imem[tb_if_pc[13:2]];
end

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

function automatic [31:0] curr_pc;
    begin
        curr_pc = START_PC + (prog_words << 2);
    end
endfunction

function automatic [31:0] rv32_r;
    input [6:0] funct7;
    input [4:0] rs2;
    input [4:0] rs1;
    input [2:0] funct3;
    input [4:0] rd;
    input [6:0] opcode;
    begin
        rv32_r = {funct7, rs2, rs1, funct3, rd, opcode};
    end
endfunction

function automatic [31:0] rv32_i;
    input [11:0] imm12;
    input [4:0]  rs1;
    input [2:0]  funct3;
    input [4:0]  rd;
    input [6:0]  opcode;
    begin
        rv32_i = {imm12, rs1, funct3, rd, opcode};
    end
endfunction

function automatic [31:0] rv32_u;
    input [19:0] imm20;
    input [4:0]  rd;
    input [6:0]  opcode;
    begin
        rv32_u = {imm20, rd, opcode};
    end
endfunction

function automatic [31:0] rv32_b;
    input [12:0] imm13;
    input [4:0]  rs2;
    input [4:0]  rs1;
    input [2:0]  funct3;
    input [6:0]  opcode;
    begin
        rv32_b = {imm13[12], imm13[10:5], rs2, rs1, funct3, imm13[4:1], imm13[11], opcode};
    end
endfunction

function automatic [31:0] rv32_j;
    input [20:0] imm21;
    input [4:0]  rd;
    input [6:0]  opcode;
    begin
        rv32_j = {imm21[20], imm21[10:1], imm21[11], imm21[19:12], rd, opcode};
    end
endfunction

function automatic [31:0] signed_slt;
    input [31:0] lhs;
    input [31:0] rhs;
    begin
        signed_slt = ($signed(lhs) < $signed(rhs)) ? 32'd1 : 32'd0;
    end
endfunction

function automatic [31:0] unsigned_slt;
    input [31:0] lhs;
    input [31:0] rhs;
    begin
        unsigned_slt = ($unsigned(lhs) < $unsigned(rhs)) ? 32'd1 : 32'd0;
    end
endfunction

function automatic [31:0] sra_word;
    input [31:0] value;
    input [4:0]  shamt;
    begin
        sra_word = $signed(value) >>> shamt;
    end
endfunction

function automatic branch_truth;
    input [2:0] funct3;
    input [31:0] lhs;
    input [31:0] rhs;
    begin
        case (funct3)
            3'b000: branch_truth = (lhs == rhs);
            3'b001: branch_truth = (lhs != rhs);
            3'b100: branch_truth = ($signed(lhs) <  $signed(rhs));
            3'b101: branch_truth = ($signed(lhs) >= $signed(rhs));
            3'b110: branch_truth = ($unsigned(lhs) <  $unsigned(rhs));
            default:branch_truth = ($unsigned(lhs) >= $unsigned(rhs));
        endcase
    end
endfunction

function automatic [31:0] sample_word;
    input integer idx;
    reg [31:0] mix;
    reg [7:0] b0;
    reg [7:0] b1;
    reg [7:0] b2;
    begin
        case (idx)
            0: sample_word = 32'h00000000;
            1: sample_word = 32'h00000001;
            2: sample_word = 32'hffffffff;
            3: sample_word = 32'h7fffffff;
            4: sample_word = 32'h80000000;
            5: sample_word = 32'h12345678;
            6: sample_word = 32'h87654321;
            7: sample_word = 32'h00000fff;
            8: sample_word = 32'hfffff800;
            9: sample_word = 32'ha5a5a5a5;
            10: sample_word = 32'h5a5a5a5a;
            default: begin
                mix = (32'h1f123bb5 * idx) ^ (32'h9e3779b9 >> (idx % 7));
                b0 = idx[7:0];
                b1 = idx * 3;
                b2 = ~idx;
                mix = mix ^ {b0, b1, b2, 8'hc3};
                case (idx % 5)
                    0: mix = mix ^ 32'h80000000;
                    1: mix = mix & 32'h7fffffff;
                    2: mix = mix ^ 32'h00ff00ff;
                    3: mix = mix + 32'h13579bdf;
                    default: mix = mix - 32'h02468ace;
                endcase
                sample_word = mix;
            end
        endcase
    end
endfunction

function automatic integer sample_imm12;
    input integer idx;
    reg signed [11:0] imm12;
    reg [31:0] tmp_word;
    begin
        case (idx % 10)
            0: imm12 = 12'sd0;
            1: imm12 = 12'sd1;
            2: imm12 = -12'sd1;
            3: imm12 = 12'sd2047;
            4: imm12 = -12'sd2048;
            5: imm12 = 12'sd1023;
            6: imm12 = -12'sd1024;
            default: begin
                tmp_word = sample_word(idx + 29);
                imm12 = tmp_word[11:0];
            end
        endcase
        sample_imm12 = $signed(imm12);
    end
endfunction

function automatic [4:0] sample_shamt;
    input integer idx;
    begin
        case (idx % 8)
            0: sample_shamt = 5'd0;
            1: sample_shamt = 5'd1;
            2: sample_shamt = 5'd4;
            3: sample_shamt = 5'd7;
            4: sample_shamt = 5'd8;
            5: sample_shamt = 5'd15;
            6: sample_shamt = 5'd16;
            default: sample_shamt = 5'd31;
        endcase
    end
endfunction

function automatic [19:0] sample_imm20;
    input integer idx;
    reg [31:0] tmp_word;
    begin
        case (idx % 8)
            0: sample_imm20 = 20'h00000;
            1: sample_imm20 = 20'h00001;
            2: sample_imm20 = 20'h7ffff;
            3: sample_imm20 = 20'h80000;
            4: sample_imm20 = 20'hfffff;
            default: begin
                tmp_word = sample_word(idx + 71);
                sample_imm20 = tmp_word[31:12];
            end
        endcase
    end
endfunction

task automatic model_write;
    input [4:0] rd;
    input [31:0] value;
    begin
        if (rd != 5'd0) model_regs[rd] = value;
        model_regs[0] = 32'd0;
    end
endtask

task automatic record_step;
    input [31:0] inst;
    input [31:0] next_pc;
    begin
        if (prog_words >= IMEM_WORDS) begin
            $fatal(1, "program too large: prog_words=%0d", prog_words);
        end

        imem[prog_words] = inst;
        expected_inst[prog_words] = inst;
        expected_next_pc[prog_words] = next_pc;
        expected_valid[prog_words] = 1'b1;
        for (r = 0; r < 32; r = r + 1) begin
            expected_regs[prog_words][r] = model_regs[r];
        end

        prog_words = prog_words + 1;
        step_count = step_count + 1;
    end
endtask

task automatic emit_raw;
    input [31:0] inst;
    begin
        if (prog_words >= IMEM_WORDS) begin
            $fatal(1, "program too large: prog_words=%0d", prog_words);
        end
        imem[prog_words] = inst;
        expected_inst[prog_words] = inst;
        expected_next_pc[prog_words] = 32'd0;
        expected_valid[prog_words] = 1'b0;
        prog_words = prog_words + 1;
    end
endtask

task automatic exec_addi;
    input [4:0] rd;
    input [4:0] rs1;
    input integer imm;
    reg [31:0] value;
    begin
        value = model_regs[rs1] + $signed(imm);
        model_write(rd, value);
        record_step(rv32_i(imm[11:0], rs1, F3_ADD_SUB, rd, OPCODE_OPIMM), curr_pc() + 32'd4);
    end
endtask

task automatic exec_xori;
    input [4:0] rd;
    input [4:0] rs1;
    input integer imm;
    reg [31:0] value;
    begin
        value = model_regs[rs1] ^ $signed(imm);
        model_write(rd, value);
        record_step(rv32_i(imm[11:0], rs1, F3_XOR, rd, OPCODE_OPIMM), curr_pc() + 32'd4);
    end
endtask

task automatic exec_ori;
    input [4:0] rd;
    input [4:0] rs1;
    input integer imm;
    reg [31:0] value;
    begin
        value = model_regs[rs1] | $signed(imm);
        model_write(rd, value);
        record_step(rv32_i(imm[11:0], rs1, F3_OR, rd, OPCODE_OPIMM), curr_pc() + 32'd4);
    end
endtask

task automatic exec_andi;
    input [4:0] rd;
    input [4:0] rs1;
    input integer imm;
    reg [31:0] value;
    begin
        value = model_regs[rs1] & $signed(imm);
        model_write(rd, value);
        record_step(rv32_i(imm[11:0], rs1, F3_AND, rd, OPCODE_OPIMM), curr_pc() + 32'd4);
    end
endtask

task automatic exec_slti;
    input [4:0] rd;
    input [4:0] rs1;
    input integer imm;
    reg [31:0] value;
    begin
        value = signed_slt(model_regs[rs1], $signed(imm));
        model_write(rd, value);
        record_step(rv32_i(imm[11:0], rs1, F3_SLT, rd, OPCODE_OPIMM), curr_pc() + 32'd4);
    end
endtask

task automatic exec_sltiu;
    input [4:0] rd;
    input [4:0] rs1;
    input integer imm;
    reg [31:0] value;
    begin
        value = unsigned_slt(model_regs[rs1], $signed(imm));
        model_write(rd, value);
        record_step(rv32_i(imm[11:0], rs1, F3_SLTU, rd, OPCODE_OPIMM), curr_pc() + 32'd4);
    end
endtask

task automatic exec_slli;
    input [4:0] rd;
    input [4:0] rs1;
    input [4:0] shamt;
    reg [31:0] value;
    begin
        value = model_regs[rs1] << shamt;
        model_write(rd, value);
        record_step(rv32_i({7'b0000000, shamt}, rs1, F3_SLL, rd, OPCODE_OPIMM), curr_pc() + 32'd4);
    end
endtask

task automatic exec_srli;
    input [4:0] rd;
    input [4:0] rs1;
    input [4:0] shamt;
    reg [31:0] value;
    begin
        value = model_regs[rs1] >> shamt;
        model_write(rd, value);
        record_step(rv32_i({7'b0000000, shamt}, rs1, F3_SRL_SRA, rd, OPCODE_OPIMM), curr_pc() + 32'd4);
    end
endtask

task automatic exec_srai;
    input [4:0] rd;
    input [4:0] rs1;
    input [4:0] shamt;
    reg [31:0] value;
    begin
        value = sra_word(model_regs[rs1], shamt);
        model_write(rd, value);
        record_step(rv32_i({7'b0100000, shamt}, rs1, F3_SRL_SRA, rd, OPCODE_OPIMM), curr_pc() + 32'd4);
    end
endtask

task automatic exec_lui;
    input [4:0] rd;
    input [19:0] imm20;
    begin
        model_write(rd, {imm20, 12'h000});
        record_step(rv32_u(imm20, rd, OPCODE_LUI), curr_pc() + 32'd4);
    end
endtask

task automatic exec_auipc;
    input [4:0] rd;
    input [19:0] imm20;
    reg [31:0] pc_before;
    begin
        pc_before = curr_pc();
        model_write(rd, pc_before + {imm20, 12'h000});
        record_step(rv32_u(imm20, rd, OPCODE_AUIPC), pc_before + 32'd4);
    end
endtask

task automatic exec_add;
    input [4:0] rd;
    input [4:0] rs1;
    input [4:0] rs2;
    begin
        model_write(rd, model_regs[rs1] + model_regs[rs2]);
        record_step(rv32_r(7'b0000000, rs2, rs1, F3_ADD_SUB, rd, OPCODE_OP), curr_pc() + 32'd4);
    end
endtask

task automatic exec_sub;
    input [4:0] rd;
    input [4:0] rs1;
    input [4:0] rs2;
    begin
        model_write(rd, model_regs[rs1] - model_regs[rs2]);
        record_step(rv32_r(7'b0100000, rs2, rs1, F3_ADD_SUB, rd, OPCODE_OP), curr_pc() + 32'd4);
    end
endtask

task automatic exec_sll;
    input [4:0] rd;
    input [4:0] rs1;
    input [4:0] rs2;
    begin
        model_write(rd, model_regs[rs1] << model_regs[rs2][4:0]);
        record_step(rv32_r(7'b0000000, rs2, rs1, F3_SLL, rd, OPCODE_OP), curr_pc() + 32'd4);
    end
endtask

task automatic exec_slt;
    input [4:0] rd;
    input [4:0] rs1;
    input [4:0] rs2;
    begin
        model_write(rd, signed_slt(model_regs[rs1], model_regs[rs2]));
        record_step(rv32_r(7'b0000000, rs2, rs1, F3_SLT, rd, OPCODE_OP), curr_pc() + 32'd4);
    end
endtask

task automatic exec_sltu;
    input [4:0] rd;
    input [4:0] rs1;
    input [4:0] rs2;
    begin
        model_write(rd, unsigned_slt(model_regs[rs1], model_regs[rs2]));
        record_step(rv32_r(7'b0000000, rs2, rs1, F3_SLTU, rd, OPCODE_OP), curr_pc() + 32'd4);
    end
endtask

task automatic exec_xor;
    input [4:0] rd;
    input [4:0] rs1;
    input [4:0] rs2;
    begin
        model_write(rd, model_regs[rs1] ^ model_regs[rs2]);
        record_step(rv32_r(7'b0000000, rs2, rs1, F3_XOR, rd, OPCODE_OP), curr_pc() + 32'd4);
    end
endtask

task automatic exec_srl;
    input [4:0] rd;
    input [4:0] rs1;
    input [4:0] rs2;
    begin
        model_write(rd, model_regs[rs1] >> model_regs[rs2][4:0]);
        record_step(rv32_r(7'b0000000, rs2, rs1, F3_SRL_SRA, rd, OPCODE_OP), curr_pc() + 32'd4);
    end
endtask

task automatic exec_sra;
    input [4:0] rd;
    input [4:0] rs1;
    input [4:0] rs2;
    begin
        model_write(rd, sra_word(model_regs[rs1], model_regs[rs2][4:0]));
        record_step(rv32_r(7'b0100000, rs2, rs1, F3_SRL_SRA, rd, OPCODE_OP), curr_pc() + 32'd4);
    end
endtask

task automatic exec_or;
    input [4:0] rd;
    input [4:0] rs1;
    input [4:0] rs2;
    begin
        model_write(rd, model_regs[rs1] | model_regs[rs2]);
        record_step(rv32_r(7'b0000000, rs2, rs1, F3_OR, rd, OPCODE_OP), curr_pc() + 32'd4);
    end
endtask

task automatic exec_and;
    input [4:0] rd;
    input [4:0] rs1;
    input [4:0] rs2;
    begin
        model_write(rd, model_regs[rs1] & model_regs[rs2]);
        record_step(rv32_r(7'b0000000, rs2, rs1, F3_AND, rd, OPCODE_OP), curr_pc() + 32'd4);
    end
endtask

task automatic build_li;
    input [4:0] rd;
    input [31:0] value;
    reg signed [63:0] val64;
    reg signed [63:0] upper;
    reg signed [63:0] lower;
    begin
        val64 = $signed(value);
        upper = (val64 + 64'sd2048) >>> 12;
        lower = val64 - (upper <<< 12);

        if (upper == 0) begin
            exec_addi(rd, 5'd0, lower);
        end else begin
            exec_lui(rd, upper[19:0]);
            if (lower != 0) begin
                exec_addi(rd, rd, lower);
            end
        end
    end
endtask

task automatic begin_case;
    begin
        total_cases = total_cases + 1;
    end
endtask

task automatic case_lui;
    input [19:0] imm20;
    begin
        begin_case();
        exec_lui(5'd3, imm20);
    end
endtask

task automatic case_auipc;
    input [19:0] imm20;
    begin
        begin_case();
        exec_auipc(5'd3, imm20);
    end
endtask

task automatic case_addi;
    input [31:0] a;
    input integer imm;
    begin
        begin_case();
        build_li(5'd1, a);
        exec_addi(5'd3, 5'd1, imm);
    end
endtask

task automatic case_slti;
    input [31:0] a;
    input integer imm;
    begin
        begin_case();
        build_li(5'd1, a);
        exec_slti(5'd3, 5'd1, imm);
    end
endtask

task automatic case_sltiu;
    input [31:0] a;
    input integer imm;
    begin
        begin_case();
        build_li(5'd1, a);
        exec_sltiu(5'd3, 5'd1, imm);
    end
endtask

task automatic case_xori;
    input [31:0] a;
    input integer imm;
    begin
        begin_case();
        build_li(5'd1, a);
        exec_xori(5'd3, 5'd1, imm);
    end
endtask

task automatic case_ori;
    input [31:0] a;
    input integer imm;
    begin
        begin_case();
        build_li(5'd1, a);
        exec_ori(5'd3, 5'd1, imm);
    end
endtask

task automatic case_andi;
    input [31:0] a;
    input integer imm;
    begin
        begin_case();
        build_li(5'd1, a);
        exec_andi(5'd3, 5'd1, imm);
    end
endtask

task automatic case_slli;
    input [31:0] a;
    input [4:0] shamt;
    begin
        begin_case();
        build_li(5'd1, a);
        exec_slli(5'd3, 5'd1, shamt);
    end
endtask

task automatic case_srli;
    input [31:0] a;
    input [4:0] shamt;
    begin
        begin_case();
        build_li(5'd1, a);
        exec_srli(5'd3, 5'd1, shamt);
    end
endtask

task automatic case_srai;
    input [31:0] a;
    input [4:0] shamt;
    begin
        begin_case();
        build_li(5'd1, a);
        exec_srai(5'd3, 5'd1, shamt);
    end
endtask

task automatic case_add;
    input [31:0] a;
    input [31:0] b;
    begin
        begin_case();
        build_li(5'd1, a);
        build_li(5'd2, b);
        exec_add(5'd3, 5'd1, 5'd2);
    end
endtask

task automatic case_sub;
    input [31:0] a;
    input [31:0] b;
    begin
        begin_case();
        build_li(5'd1, a);
        build_li(5'd2, b);
        exec_sub(5'd3, 5'd1, 5'd2);
    end
endtask

task automatic case_sll;
    input [31:0] a;
    input [31:0] b;
    begin
        begin_case();
        build_li(5'd1, a);
        build_li(5'd2, b);
        exec_sll(5'd3, 5'd1, 5'd2);
    end
endtask

task automatic case_slt;
    input [31:0] a;
    input [31:0] b;
    begin
        begin_case();
        build_li(5'd1, a);
        build_li(5'd2, b);
        exec_slt(5'd3, 5'd1, 5'd2);
    end
endtask

task automatic case_sltu;
    input [31:0] a;
    input [31:0] b;
    begin
        begin_case();
        build_li(5'd1, a);
        build_li(5'd2, b);
        exec_sltu(5'd3, 5'd1, 5'd2);
    end
endtask

task automatic case_xor;
    input [31:0] a;
    input [31:0] b;
    begin
        begin_case();
        build_li(5'd1, a);
        build_li(5'd2, b);
        exec_xor(5'd3, 5'd1, 5'd2);
    end
endtask

task automatic case_srl;
    input [31:0] a;
    input [31:0] b;
    begin
        begin_case();
        build_li(5'd1, a);
        build_li(5'd2, b);
        exec_srl(5'd3, 5'd1, 5'd2);
    end
endtask

task automatic case_sra;
    input [31:0] a;
    input [31:0] b;
    begin
        begin_case();
        build_li(5'd1, a);
        build_li(5'd2, b);
        exec_sra(5'd3, 5'd1, 5'd2);
    end
endtask

task automatic case_or;
    input [31:0] a;
    input [31:0] b;
    begin
        begin_case();
        build_li(5'd1, a);
        build_li(5'd2, b);
        exec_or(5'd3, 5'd1, 5'd2);
    end
endtask

task automatic case_and;
    input [31:0] a;
    input [31:0] b;
    begin
        begin_case();
        build_li(5'd1, a);
        build_li(5'd2, b);
        exec_and(5'd3, 5'd1, 5'd2);
    end
endtask

task automatic case_branch;
    input [2:0] funct3;
    input [31:0] lhs;
    input [31:0] rhs;
    reg taken;
    reg [31:0] pc_before;
    begin
        begin_case();
        build_li(5'd1, lhs);
        build_li(5'd2, rhs);
        pc_before = curr_pc();
        taken = branch_truth(funct3, lhs, rhs);
        record_step(rv32_b(13'd8, 5'd2, 5'd1, funct3, OPCODE_BRANCH), taken ? (pc_before + 32'd8) : (pc_before + 32'd4));
        if (taken) begin
            emit_raw(rv32_i(12'd1, 5'd23, F3_ADD_SUB, 5'd23, OPCODE_OPIMM));
        end else begin
            exec_addi(5'd23, 5'd23, 1);
        end
        exec_addi(5'd24, 5'd24, 1);
    end
endtask

task automatic build_branch_suite;
    input [2:0] funct3;
    input integer per_dir;
    integer idx;
    integer taken_cnt;
    integer nontaken_cnt;
    reg [31:0] lhs;
    reg [31:0] rhs;
    reg cond;
    begin
        taken_cnt = 0;
        nontaken_cnt = 0;
        for (idx = 0; idx < 256; idx = idx + 1) begin
            lhs = sample_word(idx * 3 + funct3 * 17 + 11);
            rhs = sample_word(idx * 5 + funct3 * 29 + 19);
            
            if (idx % 4 == 0) begin
                rhs = lhs;
            end

            cond = branch_truth(funct3, lhs, rhs);
            if (cond && taken_cnt < per_dir) begin
                case_branch(funct3, lhs, rhs);
                taken_cnt = taken_cnt + 1;
            end
            if (!cond && nontaken_cnt < per_dir) begin
                case_branch(funct3, lhs, rhs);
                nontaken_cnt = nontaken_cnt + 1;
            end
        end
        if (taken_cnt < per_dir || nontaken_cnt < per_dir) begin
            $fatal(1, "branch sample shortage funct3=%b taken=%0d not_taken=%0d", funct3, taken_cnt, nontaken_cnt);
        end
    end
endtask

task automatic case_jal;
    input [4:0] rd;
    reg [31:0] pc_before;
    begin
        begin_case();
        pc_before = curr_pc();
        model_write(rd, pc_before + 32'd4);
        record_step(rv32_j(21'd8, rd, OPCODE_JAL), pc_before + 32'd8);
        emit_raw(rv32_i(12'd1, 5'd25, F3_ADD_SUB, 5'd25, OPCODE_OPIMM));
        exec_addi(5'd26, 5'd26, 1);
    end
endtask

task automatic case_jalr;
    input [4:0] rd;
    reg [31:0] auipc_pc;
    reg [31:0] jalr_pc;
    begin
        begin_case();
        auipc_pc = curr_pc();
        exec_auipc(5'd1, 20'd0);
        jalr_pc = curr_pc();
        model_write(rd, jalr_pc + 32'd4);
        record_step(rv32_i(12'd12, 5'd1, F3_ADD_SUB, rd, OPCODE_JALR), auipc_pc + 32'd12);
        emit_raw(rv32_i(12'd1, 5'd27, F3_ADD_SUB, 5'd27, OPCODE_OPIMM));
        exec_addi(5'd28, 5'd28, 1);
    end
endtask

task automatic finish_program;
    reg [31:0] final_pc;
    begin
        final_pc = curr_pc();
        record_step(rv32_j(21'd0, 5'd0, OPCODE_JAL), final_pc);
        done_idx = prog_words - 1;
    end
endtask

task automatic check_step;
    input integer idx;
    input [31:0] next_pc_seen;
    reg step_ok;
    begin
        step_ok = 1'b1;

        if (next_pc_seen !== expected_next_pc[idx]) begin
            step_ok = 1'b0;
            fail_count = fail_count + 1;
            $display("[FAIL] step=%0d pc=0x%08h inst=0x%08h next_pc expected=0x%08h got=0x%08h",
                idx, START_PC + (idx << 2), expected_inst[idx], expected_next_pc[idx], next_pc_seen);
        end

        for (r = 0; r < 32; r = r + 1) begin
            if (dut.reg5.regs[r] !== expected_regs[idx][r]) begin
                step_ok = 1'b0;
                fail_count = fail_count + 1;
                $display("[FAIL] step=%0d pc=0x%08h inst=0x%08h x%0d expected=0x%08h got=0x%08h",
                    idx, START_PC + (idx << 2), expected_inst[idx], r, expected_regs[idx][r], dut.reg5.regs[r]);
            end
        end

        if (step_ok) begin
            $display("[PASS] step=%0d pc=0x%08h inst=0x%08h next_pc=0x%08h",
                idx, START_PC + (idx << 2), expected_inst[idx], next_pc_seen);
        end
    end
endtask

initial begin
    rst = 1'b1;
    tb_if_inst = 32'h00000013;
    prog_words = 0;
    step_count = 0;
    fail_count = 0;
    done_idx = 0;
    total_cases = 0;
    done = 1'b0;

    for (i = 0; i < IMEM_WORDS; i = i + 1) begin
        imem[i] = 32'h00000013;
        expected_valid[i] = 1'b0;
        expected_next_pc[i] = 32'd0;
        expected_inst[i] = 32'h00000013;
        for (r = 0; r < 32; r = r + 1) begin
            expected_regs[i][r] = 32'd0;
        end
    end

    for (i = 0; i < 32; i = i + 1) begin
        model_regs[i] = 32'd0;
    end

    build_li(5'd23, 32'd0);
    build_li(5'd24, 32'd0);
    build_li(5'd25, 32'd0);
    build_li(5'd26, 32'd0);
    build_li(5'd27, 32'd0);
    build_li(5'd28, 32'd0);

    for (i = 0; i < 12; i = i + 1) begin
        case_lui(sample_imm20(i));
        case_auipc(sample_imm20(i + 13));
    end

    for (i = 0; i < 12; i = i + 1) begin
        case_addi(sample_word(i + 31), sample_imm12(i + 41));
        case_slti(sample_word(i + 43), sample_imm12(i + 59));
        case_sltiu(sample_word(i + 53), sample_imm12(i + 71));
        case_xori(sample_word(i + 61), sample_imm12(i + 83));
        case_ori(sample_word(i + 73), sample_imm12(i + 97));
        case_andi(sample_word(i + 89), sample_imm12(i + 109));
    end

    for (i = 0; i < 10; i = i + 1) begin
        case_slli(sample_word(i + 121), sample_shamt(i));
        case_srli(sample_word(i + 137), sample_shamt(i + 5));
        case_srai(sample_word(i + 149), sample_shamt(i + 9));
    end

    for (i = 0; i < 12; i = i + 1) begin
        case_add(sample_word(i + 161), sample_word(i + 173));
        case_sub(sample_word(i + 181), sample_word(i + 193));
        case_sll(sample_word(i + 211), sample_word(i + 223));
        case_slt(sample_word(i + 227), sample_word(i + 239));
        case_sltu(sample_word(i + 251), sample_word(i + 263));
        case_xor(sample_word(i + 271), sample_word(i + 283));
        case_srl(sample_word(i + 293), sample_word(i + 307));
        case_sra(sample_word(i + 311), sample_word(i + 317));
        case_or(sample_word(i + 331), sample_word(i + 347));
        case_and(sample_word(i + 353), sample_word(i + 367));
    end

    build_branch_suite(3'b000, 8);
    build_branch_suite(3'b001, 8);
    build_branch_suite(3'b100, 8);
    build_branch_suite(3'b101, 8);
    build_branch_suite(3'b110, 8);
    build_branch_suite(3'b111, 8);

    case_jal(5'd3);
    case_jal(5'd4);
    case_jal(5'd5);
    case_jal(5'd0);
    case_jal(5'd0);

    case_jalr(5'd6);
    case_jalr(5'd7);
    case_jalr(5'd8);
    case_jalr(5'd0);
    case_jalr(5'd0);

    finish_program();

    #20;
    rst = 1'b0;
end

initial begin
    integer cycles;
    integer retire_idx;
    reg [31:0] retire_pc;

    @(negedge rst);
    retire_pc = START_PC;

    for (cycles = 0; cycles < MAX_CYCLES; cycles = cycles + 1) begin
        @(posedge clk);
        #1;

        retire_idx = (retire_pc - START_PC) >> 2;
        if (retire_idx < 0 || retire_idx >= IMEM_WORDS) begin
            $fatal(1, "retire pc out of range: pc=0x%08h idx=%0d", retire_pc, retire_idx);
        end

        if (!expected_valid[retire_idx]) begin
            $fatal(1, "unexpected execution at pc=0x%08h idx=%0d inst=0x%08h", retire_pc, retire_idx, imem[retire_idx]);
        end

        check_step(retire_idx, tb_if_pc);

        if (retire_idx == done_idx) begin
            if (fail_count == 0) begin
                $display("[SUMMARY] rv32i supported diff-style test passed.");
                $display("[INFO] total_cases=%0d retired_steps=%0d program_words=%0d", total_cases, step_count, prog_words);
            end else begin
                $fatal(1, "[SUMMARY] rv32i supported diff-style test failed, fail_count=%0d", fail_count);
            end
            done = 1'b1;
            $finish;
        end

        retire_pc = tb_if_pc;
    end

    if (!done) begin
        $fatal(1, "timeout: rv32i supported diff-style test did not finish");
    end
end

endmodule
