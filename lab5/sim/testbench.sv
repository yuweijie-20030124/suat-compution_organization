`timescale 1ns/1ps

`ifndef TEST_ROOT
// TODO: change this to your own path
`define TEST_ROOT "yourpath/suat-compution_organization/lab5"
`endif

module testbench;

    localparam integer CLK_PERIOD_NS = 10;
    localparam integer IRAM_WORDS    = 64 * 1024 / 4;
    localparam integer DRAM_WORDS    = 64 * 1024 / 4;
    localparam integer MAX_STEPS     = 4096;
    localparam integer DEFAULT_STEPS = 200;
    localparam integer TIMEOUT_CYCLES = 20000;
    localparam integer PATH_BITS     = 4096;
    localparam integer NAME_BITS     = 8 * 32;
    localparam integer TRACE_BITS    = 8 * 1024;

    reg clk;
    reg rst;

    integer i;
    integer commit_idx;
    integer test_steps;
    integer cycle_count;
    integer error_count;
    integer fetch_head;
    integer fetch_tail;
    integer mem_head;
    integer mem_tail;
    integer verbose;
    integer dump_all_regs;
    integer first_error_reported;
    integer plusarg_dummy;
    reg commit_sample;
    reg [31:0] commit_retired_pc_sample;
    reg [31:0] commit_next_pc_sample;
    reg [31:0] commit_inst_sample;
    reg [31:0] commit_wb_data_sample;
    reg [31:0] commit_fetch_next_pc_sample;
    reg [31:0] commit_fetch_next_inst_sample;
    reg [31:0] commit_rs1_data_sample;
    reg [31:0] commit_rs2_data_sample;

    reg [PATH_BITS-1:0] prog_hex_file;
    reg [PATH_BITS-1:0] db_dir;
    reg [PATH_BITS-1:0] db_pc_file;
    reg [PATH_BITS-1:0] db_retired_pc_file;
    reg [PATH_BITS-1:0] db_inst_file;
    reg [PATH_BITS-1:0] db_regs_file;
    reg [PATH_BITS-1:0] db_lsu_file;
    reg [PATH_BITS-1:0] db_trace_file;

    reg [31:0]   gold_pc          [0:MAX_STEPS-1];
    reg [31:0]   gold_retired_pc  [0:MAX_STEPS-1];
    reg [31:0]   gold_inst        [0:MAX_STEPS-1];
    reg [1023:0] gold_regs        [0:MAX_STEPS-1];
    reg [55:0]   gold_lsu         [0:MAX_STEPS-1];

    reg [31:0] fetch_pc_queue   [0:MAX_STEPS-1];
    reg [31:0] fetch_inst_queue [0:MAX_STEPS-1];
    reg [55:0] mem_lsu_queue    [0:MAX_STEPS-1];

    wire        rtl_commit = u_top.wbu_commit;

    wire [15:0] rtl_lsu_addr16_now = u_top.ls_addr;
    wire [3:0]  rtl_lsu_wen_now    = u_top.ls_wren;
    wire        rtl_lsu_ren_now    = u_top.ex_mem_valid & (u_top.ls_wren == 4'h0);
    wire [31:0] rtl_lsu_store_data = u_top.ls_wdata;
    wire [55:0] rtl_lsu_pkt_now    = {
        rtl_lsu_addr16_now,
        (rtl_lsu_wen_now != 4'h0) ? rtl_lsu_store_data : 32'h00000000,
        rtl_lsu_wen_now,
        3'b000,
        rtl_lsu_ren_now
    };

    SUAT_top u_top(
         .clk (clk)
        ,.rst (rst)
    );

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS / 2) clk = ~clk;
    end

    initial begin
        prog_hex_file = {`TEST_ROOT, "/sim/random_rv32i_200.hex"};
        db_dir        = {`TEST_ROOT, "/sim/database"};
        test_steps    = DEFAULT_STEPS;
        verbose       = 0;
        dump_all_regs = 0;

        plusarg_dummy = $value$plusargs("PROG_HEX=%s", prog_hex_file);
        plusarg_dummy = $value$plusargs("DB_DIR=%s", db_dir);
        plusarg_dummy = $value$plusargs("TEST_STEPS=%d", test_steps);
        plusarg_dummy = $value$plusargs("VERBOSE=%d", verbose);
        plusarg_dummy = $value$plusargs("DUMP_ALL_REGS=%d", dump_all_regs);

        db_pc_file         = {db_dir, "/difftest_pc.hex"};
        db_retired_pc_file = {db_dir, "/difftest_retired_pc.hex"};
        db_inst_file       = {db_dir, "/difftest_inst.hex"};
        db_regs_file       = {db_dir, "/difftest_regs.hex"};
        db_lsu_file        = {db_dir, "/difftest_lsu.hex"};
        db_trace_file      = {db_dir, "/difftest_trace.txt"};

        if (test_steps <= 0 || test_steps > MAX_STEPS) begin
            $display("[DIFFTEST][FATAL] illegal TEST_STEPS=%0d, MAX_STEPS=%0d", test_steps, MAX_STEPS);
            $fatal(1);
        end

        rst         = 1'b1;
        commit_idx  = 0;
        fetch_head  = 0;
        fetch_tail  = 0;
        mem_head    = 0;
        mem_tail    = 0;
        cycle_count = 0;
        error_count = 0;
        first_error_reported = 0;
        commit_sample = 1'b0;
        commit_retired_pc_sample = 32'h0;
        commit_next_pc_sample = 32'h0;
        commit_inst_sample = 32'h0;
        commit_wb_data_sample = 32'h0;

        init_memories();
        load_database();

        $display("[DIFFTEST] program hex : %s", prog_hex_file);
        $display("[DIFFTEST] database dir: %s", db_dir);
        $display("[DIFFTEST] steps       : %0d", test_steps);

        repeat (8) @(posedge clk);
        #4 rst = 1'b0;
        $display("[DIFFTEST] reset released");
    end

    always @(negedge clk) begin
        if (rst) begin
            commit_sample <= 1'b0;
            commit_retired_pc_sample <= 32'h0;
            commit_next_pc_sample <= 32'h0;
            commit_inst_sample <= 32'h0;
            commit_wb_data_sample <= 32'h0;
            commit_fetch_next_pc_sample <= 32'h0;
            commit_fetch_next_inst_sample <= 32'h0;
            commit_rs1_data_sample <= 32'h0;
            commit_rs2_data_sample <= 32'h0;
        end
        else begin
            if (u_top.id_allow_in) begin
                if (fetch_tail >= MAX_STEPS) begin
                    $display("[DIFFTEST][FATAL] fetch queue overflow");
                    $fatal(1);
                end
                fetch_pc_queue[fetch_tail] = u_top.if_pc_o;
                fetch_inst_queue[fetch_tail] = u_top.iram_rdata;
                fetch_tail = fetch_tail + 1;
            end

            if (u_top.ex_mem_valid && u_top.ex_mem_lsu_op != 4'h0) begin
                if (mem_tail >= MAX_STEPS) begin
                    $display("[DIFFTEST][FATAL] memory access queue overflow");
                    $fatal(1);
                end
                mem_lsu_queue[mem_tail] = rtl_lsu_pkt_now;
                mem_tail = mem_tail + 1;
            end

            commit_sample <= rtl_commit;
            if (rtl_commit) begin
                if (fetch_head >= fetch_tail) begin
                    $display("[DIFFTEST][FATAL] commit without a fetched instruction");
                    $fatal(1);
                end
                commit_retired_pc_sample <= fetch_pc_queue[fetch_head];
                commit_inst_sample <= fetch_inst_queue[fetch_head];
                commit_rs1_data_sample <= (fetch_inst_queue[fetch_head][19:15] == 5'd0) ?
                    32'h00000000 : u_top.reg5.regs[fetch_inst_queue[fetch_head][19:15]];
                commit_rs2_data_sample <= (fetch_inst_queue[fetch_head][24:20] == 5'd0) ?
                    32'h00000000 : u_top.reg5.regs[fetch_inst_queue[fetch_head][24:20]];
                if (fetch_head + 1 < fetch_tail) begin
                    commit_next_pc_sample <= fetch_pc_queue[fetch_head + 1];
                    commit_fetch_next_pc_sample <= fetch_pc_queue[fetch_head + 1];
                    commit_fetch_next_inst_sample <= fetch_inst_queue[fetch_head + 1];
                end
                else begin
                    // Fallback when next fetch has not entered queue yet in this half-cycle.
                    commit_next_pc_sample <= u_top.if_pc_o;
                    commit_fetch_next_pc_sample <= u_top.if_pc_o;
                    commit_fetch_next_inst_sample <= u_top.iram_rdata;
                end
                fetch_head = fetch_head + 1;
                commit_wb_data_sample <= u_top.wb_rd_data;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst) begin
            cycle_count <= cycle_count + 1;
            if (cycle_count > TIMEOUT_CYCLES) begin
                $display("[DIFFTEST][FATAL] timeout after %0d cycles, commits=%0d/%0d",
                    TIMEOUT_CYCLES, commit_idx, test_steps);
                $fatal(1);
            end
        end
    end

    always @(posedge clk) begin
        if (!rst && commit_sample === 1'b1) begin
            #1;
            compare_commit(commit_idx);
            commit_idx = commit_idx + 1;

            if (commit_idx == test_steps) begin
                if (error_count == 0) begin
                    $display("[DIFFTEST][PASS] all %0d committed instructions matched golden database", test_steps);
                end
                else begin
                    $display("[DIFFTEST][FAIL] %0d mismatches found in %0d committed instructions",
                        error_count, test_steps);
                    $fatal(1);
                end
                $finish;
            end
        end
    end

    task init_memories;
        begin
            for (i = 0; i < IRAM_WORDS; i = i + 1) begin
                u_top.imem6.sram[i] = 32'h00000000;
            end
            for (i = 0; i < DRAM_WORDS; i = i + 1) begin
                u_top.dmem7.sram[i] = 32'h00000000;
            end

            $readmemh(prog_hex_file, u_top.imem6.sram, 0, test_steps - 1);
        end
    endtask

    task load_database;
        begin
            for (i = 0; i < MAX_STEPS; i = i + 1) begin
                gold_pc[i]         = 32'hxxxxxxxx;
                gold_retired_pc[i] = 32'hxxxxxxxx;
                gold_inst[i]       = 32'hxxxxxxxx;
                gold_regs[i]       = {1024{1'bx}};
                gold_lsu[i]        = 56'hxxxxxxxxxxxxxx;
            end

            $readmemh(db_pc_file,         gold_pc,         0, test_steps - 1);
            $readmemh(db_retired_pc_file, gold_retired_pc, 0, test_steps - 1);
            $readmemh(db_inst_file,       gold_inst,       0, test_steps - 1);
            $readmemh(db_regs_file,       gold_regs,       0, test_steps - 1);
            $readmemh(db_lsu_file,        gold_lsu,        0, test_steps - 1);
        end
    endtask

    function [31:0] expand_wen_mask;
        input [3:0] wen;
        begin
            expand_wen_mask = {
                {8{wen[3]}},
                {8{wen[2]}},
                {8{wen[1]}},
                {8{wen[0]}}
            };
        end
    endfunction

    function [31:0] load_data_mask;
        input [31:0] inst;
        begin
            case (inst[14:12])
                3'b000: load_data_mask = 32'h000000ff; // lb
                3'b010: load_data_mask = 32'hffffffff; // lw
                default: load_data_mask = 32'hffffffff;
            endcase
        end
    endfunction

    function [31:0] lsu_data_mask;
        input [31:0] inst;
        input [3:0]  wen;
        input [3:0]  ren;
        begin
            if (wen != 4'h0) begin
                lsu_data_mask = expand_wen_mask(wen);
            end
            else if (ren != 4'h0) begin
                lsu_data_mask = load_data_mask(inst);
            end
            else begin
                lsu_data_mask = 32'h00000000;
            end
        end
    endfunction

    task compare_commit;
        input integer idx;
        reg [31:0] exp_next_pc;
        reg [31:0] exp_retired_pc;
        reg [31:0] exp_inst;
        reg [15:0] exp_lsu_addr16;
        reg [31:0] exp_lsu_data;
        reg [3:0]  exp_lsu_wen;
        reg [3:0]  exp_lsu_ren;
        reg [15:0] rtl_lsu_addr16;
        reg [31:0] rtl_lsu_data;
        reg [3:0]  rtl_lsu_wen;
        reg [3:0]  rtl_lsu_ren;
        reg [31:0] rtl_reg_data;
        reg [31:0] exp_reg_data;
        integer error_count_before;
        integer reg_idx;
        begin
            error_count_before = error_count;
            exp_next_pc    = gold_pc[idx];
            exp_retired_pc = gold_retired_pc[idx];
            exp_inst       = gold_inst[idx];

            exp_lsu_addr16 = gold_lsu[idx][55:40];
            exp_lsu_data   = gold_lsu[idx][39:8];
            exp_lsu_wen    = gold_lsu[idx][7:4];
            exp_lsu_ren    = gold_lsu[idx][3:0];

            if ((exp_lsu_wen != 4'h0) || (exp_lsu_ren != 4'h0)) begin
                if (mem_head >= mem_tail) begin
                    if (first_error_reported == 0) begin
                        $display("[DIFFTEST][ERROR] commit=%0d expected LSU access, but RTL memory queue is empty", idx + 1);
                    end
                    error_count = error_count + 1;
                    rtl_lsu_addr16 = 16'hxxxx;
                    rtl_lsu_wen    = 4'hx;
                    rtl_lsu_ren    = 4'hx;
                    rtl_lsu_data   = 32'hxxxxxxxx;
                    stop_on_error(
                        idx,
                        error_count_before,
                        exp_retired_pc,
                        exp_next_pc,
                        exp_inst,
                        exp_lsu_addr16,
                        exp_lsu_data,
                        exp_lsu_wen,
                        exp_lsu_ren,
                        rtl_lsu_addr16,
                        rtl_lsu_data,
                        rtl_lsu_wen,
                        rtl_lsu_ren
                    );
                end
                else begin
                    rtl_lsu_addr16 = mem_lsu_queue[mem_head][55:40];
                    rtl_lsu_wen    = mem_lsu_queue[mem_head][7:4];
                    rtl_lsu_ren    = mem_lsu_queue[mem_head][3:0];
                    rtl_lsu_data   = (rtl_lsu_ren != 4'h0) ? commit_wb_data_sample : mem_lsu_queue[mem_head][39:8];
                    mem_head = mem_head + 1;
                end
            end
            else begin
                rtl_lsu_addr16 = 16'h0000;
                rtl_lsu_wen    = 4'h0;
                rtl_lsu_ren    = 4'h0;
                rtl_lsu_data   = 32'h00000000;
            end

            if (verbose != 0) begin
                $display("[DIFFTEST] commit=%0d retired_pc=0x%08x inst=0x%08x",
                    idx + 1, commit_retired_pc_sample, commit_inst_sample);
            end

            check32(idx, "retired_pc", exp_retired_pc, commit_retired_pc_sample);
            stop_on_error(idx, error_count_before, exp_retired_pc, exp_next_pc, exp_inst,
                exp_lsu_addr16, exp_lsu_data, exp_lsu_wen, exp_lsu_ren,
                rtl_lsu_addr16, rtl_lsu_data, rtl_lsu_wen, rtl_lsu_ren);
            check32(idx, "next_pc",    exp_next_pc,    commit_next_pc_sample);
            stop_on_error(idx, error_count_before, exp_retired_pc, exp_next_pc, exp_inst,
                exp_lsu_addr16, exp_lsu_data, exp_lsu_wen, exp_lsu_ren,
                rtl_lsu_addr16, rtl_lsu_data, rtl_lsu_wen, rtl_lsu_ren);
            check32(idx, "inst",       exp_inst,       commit_inst_sample);
            stop_on_error(idx, error_count_before, exp_retired_pc, exp_next_pc, exp_inst,
                exp_lsu_addr16, exp_lsu_data, exp_lsu_wen, exp_lsu_ren,
                rtl_lsu_addr16, rtl_lsu_data, rtl_lsu_wen, rtl_lsu_ren);
            check16(idx, "lsu_addr16", exp_lsu_addr16, rtl_lsu_addr16);
            stop_on_error(idx, error_count_before, exp_retired_pc, exp_next_pc, exp_inst,
                exp_lsu_addr16, exp_lsu_data, exp_lsu_wen, exp_lsu_ren,
                rtl_lsu_addr16, rtl_lsu_data, rtl_lsu_wen, rtl_lsu_ren);
            check4 (idx, "lsu_wen",    exp_lsu_wen,    rtl_lsu_wen);
            stop_on_error(idx, error_count_before, exp_retired_pc, exp_next_pc, exp_inst,
                exp_lsu_addr16, exp_lsu_data, exp_lsu_wen, exp_lsu_ren,
                rtl_lsu_addr16, rtl_lsu_data, rtl_lsu_wen, rtl_lsu_ren);
            check4 (idx, "lsu_ren",    exp_lsu_ren,    rtl_lsu_ren);
            stop_on_error(idx, error_count_before, exp_retired_pc, exp_next_pc, exp_inst,
                exp_lsu_addr16, exp_lsu_data, exp_lsu_wen, exp_lsu_ren,
                rtl_lsu_addr16, rtl_lsu_data, rtl_lsu_wen, rtl_lsu_ren);
            check_lsu_data(idx, exp_inst, exp_lsu_data, rtl_lsu_data, exp_lsu_wen, exp_lsu_ren);
            stop_on_error(idx, error_count_before, exp_retired_pc, exp_next_pc, exp_inst,
                exp_lsu_addr16, exp_lsu_data, exp_lsu_wen, exp_lsu_ren,
                rtl_lsu_addr16, rtl_lsu_data, rtl_lsu_wen, rtl_lsu_ren);

            for (reg_idx = 0; reg_idx < 32; reg_idx = reg_idx + 1) begin
                exp_reg_data = gold_regs[idx][reg_idx * 32 +: 32];
                rtl_reg_data = (reg_idx == 0) ? 32'h00000000 : u_top.reg5.regs[reg_idx];
                check_reg(idx, reg_idx, exp_reg_data, rtl_reg_data);
                stop_on_error(idx, error_count_before, exp_retired_pc, exp_next_pc, exp_inst,
                    exp_lsu_addr16, exp_lsu_data, exp_lsu_wen, exp_lsu_ren,
                    rtl_lsu_addr16, rtl_lsu_data, rtl_lsu_wen, rtl_lsu_ren);
            end
        end
    endtask

    task stop_on_error;
        input integer idx;
        input integer error_count_before;
        input [31:0]  exp_retired_pc;
        input [31:0]  exp_next_pc;
        input [31:0]  exp_inst;
        input [15:0]  exp_lsu_addr16;
        input [31:0]  exp_lsu_data;
        input [3:0]   exp_lsu_wen;
        input [3:0]   exp_lsu_ren;
        input [15:0]  rtl_lsu_addr16;
        input [31:0]  rtl_lsu_data;
        input [3:0]   rtl_lsu_wen;
        input [3:0]   rtl_lsu_ren;
        begin
            if ((error_count != error_count_before) && (first_error_reported == 0)) begin
                first_error_reported = 1;
                dump_fail_trace(
                    idx,
                    exp_retired_pc,
                    exp_next_pc,
                    exp_inst,
                    exp_lsu_addr16,
                    exp_lsu_data,
                    exp_lsu_wen,
                    exp_lsu_ren,
                    rtl_lsu_addr16,
                    rtl_lsu_data,
                    rtl_lsu_wen,
                    rtl_lsu_ren
                );
                $display("[DIFFTEST][STOP] first failing commit=%0d", idx + 1);
                $fatal(1);
            end
        end
    endtask

    task check_lsu_data;
        input integer idx;
        input [31:0] inst;
        input [31:0] exp;
        input [31:0] got;
        input [3:0]  wen;
        input [3:0]  ren;
        reg [31:0] mask;
        reg [31:0] exp_masked;
        reg [31:0] got_masked;
        begin
            mask = lsu_data_mask(inst, wen, ren);
            exp_masked = exp & mask;
            got_masked = got & mask;
            if (got_masked !== exp_masked) begin
                error_count = error_count + 1;
                if (first_error_reported == 0) begin
                    $display("[DIFFTEST][ERROR] commit=%0d lsu_data(masked) mismatch: mask=0x%08x expected=0x%08x got=0x%08x",
                        idx + 1, mask, exp_masked, got_masked);
                end
            end
        end
    endtask

    task check32;
        input integer idx;
        input [NAME_BITS-1:0] name;
        input [31:0]  exp;
        input [31:0]  got;
        begin
            if (got !== exp) begin
                error_count = error_count + 1;
                if (first_error_reported == 0) begin
                    $display("[DIFFTEST][ERROR] commit=%0d %s mismatch: expected=0x%08x got=0x%08x",
                        idx + 1, name, exp, got);
                end
            end
        end
    endtask

    task check16;
        input integer idx;
        input [NAME_BITS-1:0] name;
        input [15:0]  exp;
        input [15:0]  got;
        begin
            if (got !== exp) begin
                error_count = error_count + 1;
                if (first_error_reported == 0) begin
                    $display("[DIFFTEST][ERROR] commit=%0d %s mismatch: expected=0x%04x got=0x%04x",
                        idx + 1, name, exp, got);
                end
            end
        end
    endtask

    task check4;
        input integer idx;
        input [NAME_BITS-1:0] name;
        input [3:0]   exp;
        input [3:0]   got;
        begin
            if (got !== exp) begin
                error_count = error_count + 1;
                if (first_error_reported == 0) begin
                    $display("[DIFFTEST][ERROR] commit=%0d %s mismatch: expected=0x%x got=0x%x",
                        idx + 1, name, exp, got);
                end
            end
        end
    endtask

    task check_reg;
        input integer idx;
        input integer reg_idx;
        input [31:0]  exp;
        input [31:0]  got;
        begin
            if (got !== exp) begin
                error_count = error_count + 1;
                if (first_error_reported == 0) begin
                    $display("[DIFFTEST][ERROR] commit=%0d x%0d mismatch: expected=0x%08x got=0x%08x",
                        idx + 1, reg_idx, exp, got);
                end
            end
        end
    endtask

    task dump_fail_trace;
        input integer idx;
        input [31:0]  exp_retired_pc;
        input [31:0]  exp_next_pc;
        input [31:0]  exp_inst;
        input [15:0]  exp_lsu_addr16;
        input [31:0]  exp_lsu_data;
        input [3:0]   exp_lsu_wen;
        input [3:0]   exp_lsu_ren;
        input [15:0]  rtl_lsu_addr16;
        input [31:0]  rtl_lsu_data;
        input [3:0]   rtl_lsu_wen;
        input [3:0]   rtl_lsu_ren;
        integer reg_idx;
        reg [31:0] exp_reg_data;
        reg [31:0] rtl_reg_data;
        reg [31:0] exp_lsu_mask;
        reg [31:0] rtl_lsu_mask;
        begin
            exp_lsu_mask = lsu_data_mask(exp_inst, exp_lsu_wen, exp_lsu_ren);
            rtl_lsu_mask = lsu_data_mask(commit_inst_sample, rtl_lsu_wen, rtl_lsu_ren);
            $display("--------------------------------------------------------------------------------");
            $display("[DIFFTEST][TRACE] commit=%0d time=%0t cycle=%0d", idx + 1, $time, cycle_count);
            $display("[DIFFTEST][TRACE] GOLD retired_pc=0x%08x next_pc=0x%08x inst=0x%08x",
                exp_retired_pc, exp_next_pc, exp_inst);
            $display("[DIFFTEST][TRACE] RTL  retired_pc=0x%08x next_pc=0x%08x inst=0x%08x",
                commit_retired_pc_sample, commit_next_pc_sample, commit_inst_sample);
            $display("[DIFFTEST][TRACE] RTL  fetch_next_pc=0x%08x fetch_next_inst=0x%08x rs1_before=0x%08x rs2_before=0x%08x",
                commit_fetch_next_pc_sample, commit_fetch_next_inst_sample,
                commit_rs1_data_sample, commit_rs2_data_sample);
            $display("[DIFFTEST][TRACE] GOLD lsu addr16=0x%04x data=0x%08x wen=0x%x ren=0x%x",
                exp_lsu_addr16, exp_lsu_data, exp_lsu_wen, exp_lsu_ren);
            $display("[DIFFTEST][TRACE] GOLD lsu mask=0x%08x masked_data=0x%08x",
                exp_lsu_mask, exp_lsu_data & exp_lsu_mask);
            $display("[DIFFTEST][TRACE] RTL  lsu addr16=0x%04x data=0x%08x wen=0x%x ren=0x%x",
                rtl_lsu_addr16, rtl_lsu_data, rtl_lsu_wen, rtl_lsu_ren);
            $display("[DIFFTEST][TRACE] RTL  lsu mask=0x%08x masked_data=0x%08x",
                rtl_lsu_mask, rtl_lsu_data & rtl_lsu_mask);

            $display("[DIFFTEST][TRACE] RTL  if  fetch_valid=%b iram_pc=0x%08x iram_inst=0x%08x if_id_valid=%b if_id_pc=0x%08x if_id_inst=0x%08x",
                u_top.id_allow_in, u_top.if_pc_o, u_top.iram_rdata,
                u_top.if_id_valid, u_top.if_id_pc, u_top.if_id_inst);
            $display("[DIFFTEST][TRACE] RTL  ex  jump=%b jump_pc=0x%08x ex_valid=%b ex_addr=0x%08x ex_data=0x%08x",
                u_top.exu_jump, u_top.exu_jump_pc, u_top.ex_mem_valid,
                u_top.ex_mem_addr, u_top.ex_mem_data);
            $display("[DIFFTEST][TRACE] RTL  mem valid=%b addr16=0x%04x rdata=0x%08x wdata=0x%08x wren=0x%x",
                u_top.ex_mem_valid, u_top.ls_addr[15:0], u_top.ls_sram_rdata,
                u_top.ls_wdata, u_top.ls_wren);
            $display("[DIFFTEST][TRACE] RTL  wb  commit=%b wen=%b rd=x%0d data=0x%08x",
                u_top.wbu_commit, u_top.wb_wen, u_top.mem_wb_rd_addr, u_top.wb_rd_data);
            $display("[DIFFTEST][TRACE] queue fetch_head=%0d fetch_tail=%0d mem_head=%0d mem_tail=%0d",
                fetch_head, fetch_tail, mem_head, mem_tail);

            if (fetch_head > 0) begin
                $display("[DIFFTEST][TRACE] queue retired_fetch[%0d] pc=0x%08x inst=0x%08x",
                    fetch_head - 1, fetch_pc_queue[fetch_head - 1], fetch_inst_queue[fetch_head - 1]);
            end
            if (fetch_head < fetch_tail) begin
                $display("[DIFFTEST][TRACE] queue next_fetch[%0d] pc=0x%08x inst=0x%08x",
                    fetch_head, fetch_pc_queue[fetch_head], fetch_inst_queue[fetch_head]);
            end

            dump_golden_trace_file(idx);

            if (dump_all_regs != 0) begin
                $display("[DIFFTEST][TRACE] register snapshot after this commit:");
                for (reg_idx = 0; reg_idx < 32; reg_idx = reg_idx + 1) begin
                    exp_reg_data = gold_regs[idx][reg_idx * 32 +: 32];
                    rtl_reg_data = (reg_idx == 0) ? 32'h00000000 : u_top.reg5.regs[reg_idx];
                    if (rtl_reg_data !== exp_reg_data) begin
                        $display("[DIFFTEST][TRACE] x%0d expected=0x%08x got=0x%08x  MISMATCH",
                            reg_idx, exp_reg_data, rtl_reg_data);
                    end
                    else begin
                        $display("[DIFFTEST][TRACE] x%0d expected=0x%08x got=0x%08x",
                            reg_idx, exp_reg_data, rtl_reg_data);
                    end
                end
            end
            else begin
                $display("[DIFFTEST][TRACE] add +DUMP_ALL_REGS=1 to print all 32 registers");
            end
            $display("--------------------------------------------------------------------------------");
        end
    endtask

    task dump_golden_trace_file;
        input integer idx;
        integer trace_fd;
        integer line_idx;
        integer line_ret;
        integer meta_line;
        integer regs_line;
        reg [TRACE_BITS-1:0] trace_line;
        begin
            meta_line = idx * 2;
            regs_line = meta_line + 1;
            trace_fd = $fopen(db_trace_file, "r");
            if (trace_fd == 0) begin
                $display("[DIFFTEST][TRACE] cannot open golden trace file: %s", db_trace_file);
            end
            else begin
                for (line_idx = 0; line_idx <= regs_line; line_idx = line_idx + 1) begin
                    line_ret = $fgets(trace_line, trace_fd);
                    if (line_ret == 0) begin
                        $display("[DIFFTEST][TRACE] golden trace ended before commit=%0d", idx + 1);
                        line_idx = regs_line + 1;
                    end
                    else if (line_idx == meta_line) begin
                        $display("[DIFFTEST][TRACE] GOLD trace: %s", trace_line);
                    end
                    else if ((line_idx == regs_line) && (dump_all_regs != 0)) begin
                        $display("[DIFFTEST][TRACE] GOLD regs : %s", trace_line);
                    end
                end
                $fclose(trace_fd);
            end
        end
    endtask

endmodule
