`timescale 1ns/1ps

module comprehensive_tb();

reg clk, rst;

wire [31:0] debug_pc;
wire [31:0] debug_gpr0, debug_gpr1, debug_gpr2, debug_gpr3, debug_gpr4, debug_gpr5, debug_gpr6, debug_gpr7;
wire [31:0] debug_gpr8, debug_gpr9, debug_gpr10, debug_gpr11, debug_gpr12, debug_gpr13, debug_gpr14, debug_gpr15;
wire [31:0] debug_gpr16, debug_gpr17, debug_gpr18, debug_gpr19, debug_gpr20, debug_gpr21, debug_gpr22, debug_gpr23;
wire [31:0] debug_gpr24, debug_gpr25, debug_gpr26, debug_gpr27, debug_gpr28, debug_gpr29, debug_gpr30, debug_gpr31;
wire [15:0] debug_lsu_addr;
wire [31:0] debug_lsu_wdata;
wire [3:0] debug_lsu_wren;

int mem_addr;

SUAT_top u_top(
    .clk (clk),
    .rst (rst),
    .debug_pc (debug_pc),
    .debug_gpr0 (debug_gpr0),
    .debug_gpr1 (debug_gpr1),
    .debug_gpr2 (debug_gpr2),
    .debug_gpr3 (debug_gpr3),
    .debug_gpr4 (debug_gpr4),
    .debug_gpr5 (debug_gpr5),
    .debug_gpr6 (debug_gpr6),
    .debug_gpr7 (debug_gpr7),
    .debug_gpr8 (debug_gpr8),
    .debug_gpr9 (debug_gpr9),
    .debug_gpr10 (debug_gpr10),
    .debug_gpr11 (debug_gpr11),
    .debug_gpr12 (debug_gpr12),
    .debug_gpr13 (debug_gpr13),
    .debug_gpr14 (debug_gpr14),
    .debug_gpr15 (debug_gpr15),
    .debug_gpr16 (debug_gpr16),
    .debug_gpr17 (debug_gpr17),
    .debug_gpr18 (debug_gpr18),
    .debug_gpr19 (debug_gpr19),
    .debug_gpr20 (debug_gpr20),
    .debug_gpr21 (debug_gpr21),
    .debug_gpr22 (debug_gpr22),
    .debug_gpr23 (debug_gpr23),
    .debug_gpr24 (debug_gpr24),
    .debug_gpr25 (debug_gpr25),
    .debug_gpr26 (debug_gpr26),
    .debug_gpr27 (debug_gpr27),
    .debug_gpr28 (debug_gpr28),
    .debug_gpr29 (debug_gpr29),
    .debug_gpr30 (debug_gpr30),
    .debug_gpr31 (debug_gpr31),
    .debug_lsu_addr (debug_lsu_addr),
    .debug_lsu_wdata (debug_lsu_wdata),
    .debug_lsu_wren (debug_lsu_wren)
);

reg [31:0] instr_mem [0:16383];
reg [31:0] data_mem [0:16383];
reg [31:0] expected_pc;
reg [31:0] expected_gpr [31:0];
reg [15:0] expected_lsu_addr;
reg [31:0] expected_lsu_wdata;
reg [3:0] expected_lsu_wren;

integer cycle_count;

initial begin
    $readmemh("../rtl/ai.hex", instr_mem);
    for (int i = 0; i < 16384; i++) data_mem[i] = 0;
    expected_pc = 32'h80000000;
    for (int i = 0; i < 32; i++) expected_gpr[i] = 0;
    expected_gpr[0] = 0; // x0 always 0

    clk = 0;
    rst = 1;
    cycle_count = 0;
    #200 rst = 0;

    // Run for enough cycles
    repeat (200) begin
        @(posedge clk);
        cycle_count = cycle_count + 1;
        // Execute expected
        execute_instruction();
        // Compare
        compare();
    end

    $stop;
end

always #5 clk = ~clk;

task automatic execute_instruction();
    int addr;
    reg [31:0] inst;
    reg [6:0] opcode;
    reg [4:0] rd;
    reg [4:0] rs1;
    reg [4:0] rs2;
    reg [2:0] funct3;
    reg [6:0] funct7;
    reg [31:0] imm;
    reg [31:0] result;
    reg [31:0] next_pc;
    reg [31:0] addr_calc;
    reg [31:0] load_data;

    addr = (expected_pc - 32'h80000000) >> 2;
    inst = instr_mem[addr];
    opcode = inst[6:0];
    rd = inst[11:7];
    rs1 = inst[19:15];
    rs2 = inst[24:20];
    funct3 = inst[14:12];
    funct7 = inst[31:25];
    next_pc = expected_pc + 4;

    expected_lsu_addr = 0;
    expected_lsu_wdata = 0;
    expected_lsu_wren = 0;

    case (opcode)
        7'b0110111: begin // lui
            imm = {inst[31:12], 12'b0};
            result = imm;
            expected_gpr[rd] = result;
        end
        7'b0010111: begin // auipc
            imm = {inst[31:12], 12'b0};
            result = expected_pc + imm;
            expected_gpr[rd] = result;
        end
        7'b1101111: begin // jal
            imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
            expected_gpr[rd] = next_pc;
            next_pc = expected_pc + imm;
        end
        7'b1100111: begin // jalr
            imm = {{20{inst[31]}}, inst[31:20]};
            expected_gpr[rd] = next_pc;
            next_pc = (expected_gpr[rs1] + imm) & ~1;
        end
        7'b1100011: begin // branch
            imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
            case (funct3)
                3'b000: if (expected_gpr[rs1] == expected_gpr[rs2]) next_pc = expected_pc + imm; // beq
                3'b001: if (expected_gpr[rs1] != expected_gpr[rs2]) next_pc = expected_pc + imm; // bne
                3'b100: if ($signed(expected_gpr[rs1]) < $signed(expected_gpr[rs2])) next_pc = expected_pc + imm; // blt
                3'b101: if ($signed(expected_gpr[rs1]) >= $signed(expected_gpr[rs2])) next_pc = expected_pc + imm; // bge
                3'b110: if (expected_gpr[rs1] < expected_gpr[rs2]) next_pc = expected_pc + imm; // bltu
                3'b111: if (expected_gpr[rs1] >= expected_gpr[rs2]) next_pc = expected_pc + imm; // bgeu
            endcase
        end
        7'b0000011: begin // load
            imm = {{20{inst[31]}}, inst[31:20]};
            addr_calc = expected_gpr[rs1] + imm;
            mem_addr = (addr_calc >> 2) & 16383;
            load_data = data_mem[mem_addr];
            case (funct3)
                3'b000: result = {{24{load_data[7]}}, load_data[7:0]}; // lb
                3'b010: result = load_data; // lw
                default: result = 0;
            endcase
            expected_gpr[rd] = result;
        end
        7'b0100011: begin // store
            imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
            addr_calc = expected_gpr[rs1] + imm;
            mem_addr = (addr_calc >> 2) & 16383;
            expected_lsu_addr = mem_addr;
            expected_lsu_wdata = expected_gpr[rs2];
            case (funct3)
                3'b000: expected_lsu_wren = 4'b0001; // sb
                3'b010: expected_lsu_wren = 4'b1111; // sw
            endcase
            // Update data_mem
            if (expected_lsu_wren[0]) data_mem[mem_addr][7:0] = expected_lsu_wdata[7:0];
            if (expected_lsu_wren[1]) data_mem[mem_addr][15:8] = expected_lsu_wdata[15:8];
            if (expected_lsu_wren[2]) data_mem[mem_addr][23:16] = expected_lsu_wdata[23:16];
            if (expected_lsu_wren[3]) data_mem[mem_addr][31:24] = expected_lsu_wdata[31:24];
        end
        7'b0010011: begin // I-type ALU
            imm = {{20{inst[31]}}, inst[31:20]};
            case (funct3)
                3'b000: result = expected_gpr[rs1] + imm; // addi
                3'b010: result = $signed(expected_gpr[rs1]) < $signed(imm) ? 1 : 0; // slti
                3'b011: result = expected_gpr[rs1] < imm ? 1 : 0; // sltiu
                3'b100: result = expected_gpr[rs1] ^ imm; // xori
                3'b110: result = expected_gpr[rs1] | imm; // ori
                3'b111: result = expected_gpr[rs1] & imm; // andi
                3'b001: result = expected_gpr[rs1] << imm[4:0]; // slli
                3'b101: if (funct7[5]) result = $signed(expected_gpr[rs1]) >>> imm[4:0]; else result = expected_gpr[rs1] >> imm[4:0]; // srli/srai
            endcase
            expected_gpr[rd] = result;
        end
        7'b0110011: begin // R-type
            case (funct3)
                3'b000: if (funct7[5]) result = expected_gpr[rs1] - expected_gpr[rs2]; else result = expected_gpr[rs1] + expected_gpr[rs2]; // sub/add
                3'b001: result = expected_gpr[rs1] << expected_gpr[rs2][4:0]; // sll
                3'b010: result = $signed(expected_gpr[rs1]) < $signed(expected_gpr[rs2]) ? 1 : 0; // slt
                3'b011: result = expected_gpr[rs1] < expected_gpr[rs2] ? 1 : 0; // sltu
                3'b100: result = expected_gpr[rs1] ^ expected_gpr[rs2]; // xor
                3'b101: if (funct7[5]) result = $signed(expected_gpr[rs1]) >>> expected_gpr[rs2][4:0]; else result = expected_gpr[rs1] >> expected_gpr[rs2][4:0]; // sra/srl
                3'b110: result = expected_gpr[rs1] | expected_gpr[rs2]; // or
                3'b111: result = expected_gpr[rs1] & expected_gpr[rs2]; // and
            endcase
            expected_gpr[rd] = result;
        end
        default: begin
            // Unknown
        end
    endcase
    expected_gpr[0] = 0; // x0
    expected_pc = next_pc;
endtask

task automatic compare();
    if (debug_pc !== expected_pc) $error("PC mismatch at cycle %d: expected %h, got %h", cycle_count, expected_pc, debug_pc);
    if (debug_gpr0 !== expected_gpr[0]) $error("GPR[0] mismatch at cycle %d", cycle_count);
    if (debug_gpr1 !== expected_gpr[1]) $error("GPR[1] mismatch at cycle %d: expected %h, got %h", cycle_count, expected_gpr[1], debug_gpr1);
    if (debug_gpr2 !== expected_gpr[2]) $error("GPR[2] mismatch at cycle %d: expected %h, got %h", cycle_count, expected_gpr[2], debug_gpr2);
    if (debug_gpr3 !== expected_gpr[3]) $error("GPR[3] mismatch at cycle %d: expected %h, got %h", cycle_count, expected_gpr[3], debug_gpr3);
    if (debug_gpr4 !== expected_gpr[4]) $error("GPR[4] mismatch at cycle %d: expected %h, got %h", cycle_count, expected_gpr[4], debug_gpr4);
    if (debug_gpr5 !== expected_gpr[5]) $error("GPR[5] mismatch at cycle %d: expected %h, got %h", cycle_count, expected_gpr[5], debug_gpr5);
    if (debug_gpr6 !== expected_gpr[6]) $error("GPR[6] mismatch at cycle %d: expected %h, got %h", cycle_count, expected_gpr[6], debug_gpr6);
    if (debug_gpr7 !== expected_gpr[7]) $error("GPR[7] mismatch at cycle %d: expected %h, got %h", cycle_count, expected_gpr[7], debug_gpr7);
    // Add more as needed, but for brevity, key ones
    if (expected_lsu_wren != 0) begin
        if (debug_lsu_addr !== expected_lsu_addr) $error("LSU addr mismatch at cycle %d: expected %h, got %h", cycle_count, expected_lsu_addr, debug_lsu_addr);
        if (debug_lsu_wdata !== expected_lsu_wdata) $error("LSU wdata mismatch at cycle %d: expected %h, got %h", cycle_count, expected_lsu_wdata, debug_lsu_wdata);
        if (debug_lsu_wren !== expected_lsu_wren) $error("LSU wren mismatch at cycle %d: expected %h, got %h", cycle_count, expected_lsu_wren, debug_lsu_wren);
    end
endtask

endmodule