`timescale 1ns/1ps
`include "../rtl/define.v"

module lab4_reference_tb;

localparam [31:0] START_PC = `SUAT_STARTPC;
// 保持老师给定的 ai.hex 作为唯一指令源，database 只保存它对应的期望退休轨迹。
localparam integer AI_IMAGE_WORDS = 171;
localparam integer TRACE_STEPS = 42;
localparam [31:0] HALT_PC = 32'h800000a4;
localparam integer CYCLE_BUDGET = 80;
localparam integer MEM_DEPTH = (1 << 14);

reg clk;
reg rst;

wire [31:0] debug_pc;
wire [15:0] debug_lsu_addr;
wire [31:0] debug_lsu_wdata;
wire [3:0] debug_lsu_wren;

reg [31:0] instr_mem [0:MEM_DEPTH-1];
reg [31:0] trace_retired_pc [0:TRACE_STEPS-1];
reg [31:0] trace_debug_pc [0:TRACE_STEPS-1];
reg [1023:0] trace_gpr_packed [0:TRACE_STEPS-1];
reg [51:0] trace_lsu_packed [0:TRACE_STEPS-1];

reg [31:0] expected_gpr [0:31];
reg [31:0] expected_pc;
reg [31:0] retired_pc;
reg [31:0] retired_inst;
reg [15:0] expected_lsu_addr;
reg [31:0] expected_lsu_wdata;
reg [3:0] expected_lsu_wren;
reg [15:0] sampled_lsu_addr;
reg [31:0] sampled_lsu_wdata;
reg [3:0] sampled_lsu_wren;

integer cycle_count;
integer i;
integer reg_idx;
integer trace_idx;

SUAT_top u_top(
    .clk            (clk),
    .rst            (rst),
    .debug_pc       (debug_pc),
    .debug_lsu_addr (debug_lsu_addr),
    .debug_lsu_wdata(debug_lsu_wdata),
    .debug_lsu_wren (debug_lsu_wren)
);

task init_program;
    begin
        // imem 继续跑原始 ai.hex；dmem 必须手工清零，否则 mem6 也会把 ai.hex 当数据镜像装进去。
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            instr_mem[i] = 32'h00000013;
            u_top.imem6.sram[i] = 32'h00000013;
            u_top.mem6.sram[i] = 32'h00000000;
        end

        // Vivado GUI 可能从工程目录或 xsim.dir 启动，这里把镜像路径写死，避免相对路径失效。
        $readmemh("your_abs_path/lab4/rtl/test.hex", instr_mem, 0, AI_IMAGE_WORDS - 1);
        for (i = 0; i < AI_IMAGE_WORDS; i = i + 1) begin
            u_top.imem6.sram[i] = instr_mem[i];
        end
    end
endtask

task init_trace_database;
    begin
        // 轨迹数据库同样改成绝对路径，这样 GUI 仿真时 expected 值不会再读成 x。
        $readmemh("your_abs_path/lab4/sim/database/difftest_retired_pc.hex", trace_retired_pc, 0, TRACE_STEPS - 1);
        $readmemh("your_abs_path/lab4/sim/database/difftest_pc.hex", trace_debug_pc, 0, TRACE_STEPS - 1);
        $readmemh("your_abs_path/lab4/sim/database/difftest_regs.hex", trace_gpr_packed, 0, TRACE_STEPS - 1);
        $readmemh("your_abs_path/lab4/sim/database/difftest_lsu.hex", trace_lsu_packed, 0, TRACE_STEPS - 1);
    end
endtask

task init_expected_state;
    begin
        expected_pc = START_PC;
        retired_pc = START_PC;
        retired_inst = 32'h00000013;
        expected_lsu_addr = 16'h0000;
        expected_lsu_wdata = 32'h00000000;
        expected_lsu_wren = 4'b0000;
        sampled_lsu_addr = 16'h0000;
        sampled_lsu_wdata = 32'h00000000;
        sampled_lsu_wren = 4'b0000;
        for (i = 0; i < 32; i = i + 1) begin
            expected_gpr[i] = 32'h00000000;
        end
    end
endtask

task load_expected_step;
    input integer idx;
    reg [1023:0] regs_line;
    reg [51:0] lsu_line;
    begin
        retired_pc = trace_retired_pc[idx];
        retired_inst = instr_mem[(trace_retired_pc[idx] - START_PC) >> 2];
        expected_pc = trace_debug_pc[idx];
        regs_line = trace_gpr_packed[idx];
        lsu_line = trace_lsu_packed[idx];

        for (reg_idx = 0; reg_idx < 32; reg_idx = reg_idx + 1) begin
            expected_gpr[reg_idx] = regs_line[(reg_idx * 32) +: 32];
        end

        expected_lsu_wren = lsu_line[3:0];
        expected_lsu_wdata = lsu_line[35:4];
        expected_lsu_addr = lsu_line[51:36];
    end
endtask

task capture_lsu_debug;
    begin
        // 单周期机的 LSU 写信号在时钟沿前有效，这里先抓拍，避免顶层为了 debug 再多打一拍。
        sampled_lsu_addr = debug_lsu_addr;
        sampled_lsu_wdata = debug_lsu_wdata;
        sampled_lsu_wren = debug_lsu_wren;
    end
endtask

task fail_pc;
    begin
        $display("[FAIL] cycle=%0d retired_pc=%h inst=%h expected_pc=%h actual_pc=%h", cycle_count, retired_pc, retired_inst, expected_pc, debug_pc);
        $finish;
    end
endtask

task fail_gpr;
    input integer reg_num;
    input [31:0] expected_value;
    input [31:0] actual_value;
    begin
        $display("[FAIL] cycle=%0d retired_pc=%h inst=%h gpr[%0d] expected=%h actual=%h", cycle_count, retired_pc, retired_inst, reg_num, expected_value, actual_value);
        $finish;
    end
endtask

task fail_lsu;
    input [8*12-1:0] field_name;
    input [31:0] expected_value;
    input [31:0] actual_value;
    begin
        $display("[FAIL] cycle=%0d retired_pc=%h inst=%h lsu_%0s expected=%h actual=%h", cycle_count, retired_pc, retired_inst, field_name, expected_value, actual_value);
        $finish;
    end
endtask

`define CHECK_GPR(REG_IDX) \
    if (u_top.reg5.regs[REG_IDX] !== expected_gpr[REG_IDX]) begin \
        fail_gpr(REG_IDX, expected_gpr[REG_IDX], u_top.reg5.regs[REG_IDX]); \
    end

task compare_state;
    begin
        if (debug_pc !== expected_pc) begin
            fail_pc;
        end

        for(int i=0;i < 32; i = i+1) begin
            `CHECK_GPR(i);
        end


        if (sampled_lsu_wren !== expected_lsu_wren) begin
            fail_lsu("wren", {28'h0, expected_lsu_wren}, {28'h0, sampled_lsu_wren});
        end
        if (sampled_lsu_addr !== expected_lsu_addr) begin
            fail_lsu("addr", {16'h0, expected_lsu_addr}, {16'h0, sampled_lsu_addr});
        end
        if (sampled_lsu_wdata !== expected_lsu_wdata) begin
            fail_lsu("wdata", expected_lsu_wdata, sampled_lsu_wdata);
        end
    end
endtask

always #5 clk = ~clk;

initial begin
    clk = 1'b0;
    rst = 1'b1;
    cycle_count = 0;
    trace_idx = 0;

    // 等 SRAM 自身的 initial 先把 ai.hex 装进去，再由 TB 接管 dmem 清零与 imem 对齐，避免 0 时刻竞争。
    #1 init_program();
    init_trace_database();
    init_expected_state();

    repeat (4) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    #1 capture_lsu_debug();

    while (cycle_count < TRACE_STEPS && cycle_count < CYCLE_BUDGET) begin
        @(posedge clk);
        cycle_count = cycle_count + 1;
        trace_idx = cycle_count - 1;
        load_expected_step(trace_idx);
        #1 compare_state();

        if (cycle_count == TRACE_STEPS) begin
            // 这 42 步轨迹的最后一条就是 ai.hex 的 halt 自环，走到这里说明原始用例整条退休路径完全对齐。
            $display("[PASS] checked %0d test.hex steps, halt_pc=%h, all architectural states matched.", cycle_count, HALT_PC);
            $finish;
        end

        @(negedge clk);
        #1 capture_lsu_debug();
    end

    $display("[FAIL] simulation exceeded cycle budget, cycle_count=%0d debug_pc=%h", cycle_count, debug_pc);
    $finish;
end

endmodule
