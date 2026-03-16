`timescale 1ns/1ps

module tb_ALU_Regfile;

    localparam [6:0] OPCODE_OP      = 7'b0110011;
    localparam [6:0] OPCODE_OP_IMM  = 7'b0010011;
    localparam [6:0] OPCODE_LUI     = 7'b0110111;
    localparam [6:0] OPCODE_AUIPC   = 7'b0010111;
    localparam [6:0] OPCODE_JAL     = 7'b1101111;
    localparam [6:0] OPCODE_JALR    = 7'b1100111;

    reg clk;
    reg rst;

    reg [31:0] tb_pc;
    reg [31:0] tb_inst;

    reg [31:0] expected_reg [0:31];

    wire [31:0] rfile [0:31];

    integer fail_count;

    SUAT_top top (
         .clk           (clk        )
        ,.rst           (rst        )
        ,.tb_id_pc      (tb_pc      )
        ,.tb_id_inst    (tb_inst    )
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // map regfile outputs to an array for easy checking
    assign rfile[0]  = top.reg5.regs[0 ];
    assign rfile[1]  = top.reg5.regs[1 ];
    assign rfile[2]  = top.reg5.regs[2 ];
    assign rfile[3]  = top.reg5.regs[3 ];
    assign rfile[4]  = top.reg5.regs[4 ];
    assign rfile[5]  = top.reg5.regs[5 ];
    assign rfile[6]  = top.reg5.regs[6 ];
    assign rfile[7]  = top.reg5.regs[7 ];
    assign rfile[8]  = top.reg5.regs[8 ];
    assign rfile[9]  = top.reg5.regs[9 ];
    assign rfile[10] = top.reg5.regs[10];
    assign rfile[11] = top.reg5.regs[11];
    assign rfile[12] = top.reg5.regs[12];
    assign rfile[13] = top.reg5.regs[13];
    assign rfile[14] = top.reg5.regs[14];
    assign rfile[15] = top.reg5.regs[15];
    assign rfile[16] = top.reg5.regs[16];
    assign rfile[17] = top.reg5.regs[17];
    assign rfile[18] = top.reg5.regs[18];
    assign rfile[19] = top.reg5.regs[19];
    assign rfile[20] = top.reg5.regs[20];
    assign rfile[21] = top.reg5.regs[21];
    assign rfile[22] = top.reg5.regs[22];
    assign rfile[23] = top.reg5.regs[23];
    assign rfile[24] = top.reg5.regs[24];
    assign rfile[25] = top.reg5.regs[25];
    assign rfile[26] = top.reg5.regs[26];
    assign rfile[27] = top.reg5.regs[27];
    assign rfile[28] = top.reg5.regs[28];
    assign rfile[29] = top.reg5.regs[29];
    assign rfile[30] = top.reg5.regs[30];
    assign rfile[31] = top.reg5.regs[31];

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
            unsigned_slt = (lhs < rhs) ? 32'd1 : 32'd0;
        end
    endfunction

    function automatic [31:0] sra_word;
        input [31:0] value;
        input [4:0]  shamt;
        begin
            sra_word = $signed(value) >>> shamt;
        end
    endfunction

    task automatic check_reg;
        input integer idx;
        input string  label;
        begin
            if (rfile[idx] !== expected_reg[idx]) begin
                fail_count = fail_count + 1;
                $display("[FAIL] %s x%0d expected=0x%08h got=0x%08h", label, idx, expected_reg[idx], rfile[idx]);
            end
            else begin
                $display("[PASS] %s x%0d = 0x%08h", label, idx, rfile[idx]);
            end
        end
    endtask

    task automatic run_case;
        input [31:0] inst;
        input [4:0]  rd;
        input [31:0] exp_val;
        input string label;
        begin
            tb_inst = inst;
            if (rd != 5'd0) begin
                expected_reg[rd] = exp_val;
            end

            @(posedge clk);
            #1;

            if (rd != 5'd0) begin
                check_reg(rd, label);
            end
            check_reg(0, {label, " / x0"});

            tb_pc = tb_pc + 32'd4;
        end
    endtask

    // Reset
    initial begin
        rst = 1;
        #20;
        rst = 0;
    end

    initial begin
        integer i;

        tb_pc = 0;
        tb_inst = 32'h00000013;
        fail_count = 0;

        for (i=0; i<32; i=i+1) expected_reg[i] = 0;

        @(negedge rst);
        @(negedge clk);

        run_case(rv32_i(12'd15,              5'd0, 3'b000, 5'd1,  OPCODE_OP_IMM), 5'd1,  32'd15,                         "ADDI x1, x0, 15");
        run_case(rv32_i(12'hffc,             5'd0, 3'b000, 5'd2,  OPCODE_OP_IMM), 5'd2,  32'hffff_fffc,                 "ADDI x2, x0, -4");
        run_case(rv32_r(7'b0000000, 5'd1,    5'd1, 3'b000, 5'd3,  OPCODE_OP),     5'd3,  expected_reg[1] + expected_reg[1], "ADD x3, x1, x1");
        run_case(rv32_r(7'b0100000, 5'd2,    5'd3, 3'b000, 5'd4,  OPCODE_OP),     5'd4,  expected_reg[3] - expected_reg[2], "SUB x4, x3, x2");
        run_case(rv32_i(12'h055,             5'd4, 3'b100, 5'd5,  OPCODE_OP_IMM), 5'd5,  expected_reg[4] ^ 32'h0000_0055, "XORI x5, x4, 0x55");
        run_case(rv32_i(12'h0f0,             5'd5, 3'b111, 5'd6,  OPCODE_OP_IMM), 5'd6,  expected_reg[5] & 32'h0000_00f0, "ANDI x6, x5, 0x0f0");
        run_case(rv32_i(12'h00a,             5'd6, 3'b110, 5'd7,  OPCODE_OP_IMM), 5'd7,  expected_reg[6] | 32'h0000_000a, "ORI x7, x6, 0x00a");
        run_case(rv32_i({7'b0000000, 5'd2},  5'd7, 3'b001, 5'd8,  OPCODE_OP_IMM), 5'd8,  expected_reg[7] << 2,           "SLLI x8, x7, 2");
        run_case(rv32_i({7'b0000000, 5'd3},  5'd8, 3'b101, 5'd9,  OPCODE_OP_IMM), 5'd9,  expected_reg[8] >> 3,           "SRLI x9, x8, 3");
        run_case(rv32_i({7'b0100000, 5'd1},  5'd2, 3'b101, 5'd10, OPCODE_OP_IMM), 5'd10, sra_word(expected_reg[2], 5'd1), "SRAI x10, x2, 1");
        run_case(rv32_r(7'b0000000, 5'd1,    5'd2, 3'b010, 5'd11, OPCODE_OP),     5'd11, signed_slt(expected_reg[2], expected_reg[1]),  "SLT x11, x2, x1");
        run_case(rv32_r(7'b0000000, 5'd1,    5'd2, 3'b011, 5'd12, OPCODE_OP),     5'd12, unsigned_slt(expected_reg[2], expected_reg[1]),"SLTU x12, x2, x1");
        run_case(rv32_i(12'hfff,             5'd10,3'b010, 5'd13, OPCODE_OP_IMM), 5'd13, signed_slt(expected_reg[10], 32'hffff_ffff),  "SLTI x13, x10, -1");
        run_case(rv32_i(12'd16,              5'd1, 3'b011, 5'd14, OPCODE_OP_IMM), 5'd14, unsigned_slt(expected_reg[1], 32'd16),         "SLTIU x14, x1, 16");
        run_case(rv32_i(12'd123,             5'd0, 3'b000, 5'd0,  OPCODE_OP_IMM), 5'd0,  32'd0,                          "ADDI x0, x0, 123");
        run_case(rv32_r(7'b0000000, 5'd11,   5'd1, 3'b001, 5'd19, OPCODE_OP),     5'd19, expected_reg[1] << expected_reg[11][4:0],  "SLL x19, x1, x11");
        run_case(rv32_r(7'b0000000, 5'd11,   5'd8, 3'b101, 5'd20, OPCODE_OP),     5'd20, expected_reg[8] >> expected_reg[11][4:0],  "SRL x20, x8, x11");
        run_case(rv32_r(7'b0100000, 5'd11,   5'd10,3'b101, 5'd21, OPCODE_OP),     5'd21, sra_word(expected_reg[10], expected_reg[11][4:0]), "SRA x21, x10, x11");
        run_case(rv32_r(7'b0000000, 5'd16,   5'd15,3'b100, 5'd22, OPCODE_OP),     5'd22, expected_reg[15] ^ expected_reg[16],       "XOR x22, x15, x16");
        run_case(rv32_r(7'b0000000, 5'd14,   5'd19,3'b110, 5'd23, OPCODE_OP),     5'd23, expected_reg[19] | expected_reg[14],       "OR x23, x19, x14");
        run_case(rv32_r(7'b0000000, 5'd18,   5'd17,3'b000, 5'd24, OPCODE_OP),     5'd24, expected_reg[17] + expected_reg[18],       "ADD x24, x17, x18");
        run_case(rv32_r(7'b0100000, 5'd3,    5'd24,3'b000, 5'd25, OPCODE_OP),     5'd25, expected_reg[24] - expected_reg[3],        "SUB x25, x24, x3");

        tb_inst = 32'h00000013;
        @(posedge clk);
        #1;

        for (i=0; i<32; i=i+1) begin
            if (rfile[i] !== expected_reg[i])
                $display("[FAIL] FINAL x%0d: expected 0x%08h, got 0x%08h", i, expected_reg[i], rfile[i]);
            else
                $display("[PASS] FINAL x%0d: 0x%08h", i, rfile[i]);
        end

        if (fail_count == 0)
            $display("[SUMMARY] All complex ALU/regfile testcases passed.");
        else
            $fatal(1, "[SUMMARY] %0d step checks failed.", fail_count);

        $finish;
    end

endmodule
