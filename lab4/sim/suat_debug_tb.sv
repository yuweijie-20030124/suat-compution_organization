`timescale 1ns/1ps
`include "../rtl/define.v"

module suat_debug_tb;

reg clk;
reg rst;

wire [`SUAT_PC]   tb_if_pc;
wire              tb_ex_jump;
wire [`SUAT_PC]   tb_ex_jump_pc;
wire [`SUAT_DATA] tb_ex_res;

SUAT_top dut (
     .clk          (clk)
    ,.rst          (rst)
    ,.tb_if_pc     (tb_if_pc)
    ,.tb_ex_jump   (tb_ex_jump)
    ,.tb_ex_jump_pc(tb_ex_jump_pc)
    ,.tb_ex_res    (tb_ex_res)
);

localparam [31:0] START_PC = `SUAT_STARTPC;
localparam integer TRACE_DEPTH = 16;

integer cycle_count;
integer run_cycles;
integer fail_count;
integer warn_count;
reg verbose;
reg trace_all;
reg dump_end_trace;
integer load_stall_count;
reg load_store_program;

integer hist_cycle [0:TRACE_DEPTH-1];
reg [31:0] hist_pc [0:TRACE_DEPTH-1];
reg [31:0] hist_inst [0:TRACE_DEPTH-1];
reg [31:0] hist_ex_res [0:TRACE_DEPTH-1];
reg [4:0]  hist_rd [0:TRACE_DEPTH-1];
reg        hist_wen [0:TRACE_DEPTH-1];
reg [31:0] hist_wdata [0:TRACE_DEPTH-1];
reg [3:0]  hist_ls_ctl [0:TRACE_DEPTH-1];
reg [3:0]  hist_wren [0:TRACE_DEPTH-1];
reg [15:0] hist_daddr [0:TRACE_DEPTH-1];
reg [31:0] hist_dwdata [0:TRACE_DEPTH-1];
reg [31:0] hist_drdata [0:TRACE_DEPTH-1];
reg        hist_valid [0:TRACE_DEPTH-1];

always begin
    #5 clk = ~clk;
end

function automatic has_x1;
    input value;
    begin
        has_x1 = (value !== 1'b0) && (value !== 1'b1);
    end
endfunction

function automatic has_x4;
    input [3:0] value;
    begin
        has_x4 = (^value === 1'bx);
    end
endfunction

function automatic has_x5;
    input [4:0] value;
    begin
        has_x5 = (^value === 1'bx);
    end
endfunction

function automatic has_x16;
    input [15:0] value;
    begin
        has_x16 = (^value === 1'bx);
    end
endfunction

function automatic has_x32;
    input [31:0] value;
    begin
        has_x32 = (^value === 1'bx);
    end
endfunction

function automatic [79:0] inst_name;
    input [31:0] inst;
    reg [6:0] opcode;
    reg [2:0] funct3;
    reg [6:0] funct7;
    begin
        opcode = inst[6:0];
        funct3 = inst[14:12];
        funct7 = inst[31:25];

        if (inst == 32'h00000013) begin
            inst_name = "NOP       ";
        end else begin
            case (opcode)
                7'b0110111: inst_name = "LUI       ";
                7'b0010111: inst_name = "AUIPC     ";
                7'b1101111: inst_name = "JAL       ";
                7'b1100111: inst_name = "JALR      ";
                7'b1100011: begin
                    case (funct3)
                        3'b000: inst_name = "BEQ       ";
                        3'b001: inst_name = "BNE       ";
                        3'b100: inst_name = "BLT       ";
                        3'b101: inst_name = "BGE       ";
                        3'b110: inst_name = "BLTU      ";
                        3'b111: inst_name = "BGEU      ";
                        default: inst_name = "BR?       ";
                    endcase
                end
                7'b0000011: begin
                    case (funct3)
                        3'b000: inst_name = "LB        ";
                        3'b001: inst_name = "LH        ";
                        3'b010: inst_name = "LW        ";
                        3'b100: inst_name = "LBU       ";
                        3'b101: inst_name = "LHU       ";
                        default: inst_name = "LOAD?     ";
                    endcase
                end
                7'b0100011: begin
                    case (funct3)
                        3'b000: inst_name = "SB        ";
                        3'b001: inst_name = "SH        ";
                        3'b010: inst_name = "SW        ";
                        default: inst_name = "STORE?    ";
                    endcase
                end
                7'b0010011: begin
                    case (funct3)
                        3'b000: inst_name = "ADDI      ";
                        3'b010: inst_name = "SLTI      ";
                        3'b011: inst_name = "SLTIU     ";
                        3'b100: inst_name = "XORI      ";
                        3'b110: inst_name = "ORI       ";
                        3'b111: inst_name = "ANDI      ";
                        3'b001: inst_name = "SLLI      ";
                        3'b101: inst_name = funct7[5] ? "SRAI      " : "SRLI      ";
                        default: inst_name = "OPIMM?    ";
                    endcase
                end
                7'b0110011: begin
                    case (funct3)
                        3'b000: inst_name = funct7[5] ? "SUB       " : "ADD       ";
                        3'b001: inst_name = "SLL       ";
                        3'b010: inst_name = "SLT       ";
                        3'b011: inst_name = "SLTU      ";
                        3'b100: inst_name = "XOR       ";
                        3'b101: inst_name = funct7[5] ? "SRA       " : "SRL       ";
                        3'b110: inst_name = "OR        ";
                        3'b111: inst_name = "AND       ";
                        default: inst_name = "OP?       ";
                    endcase
                end
                default: inst_name = "UNKNOWN   ";
            endcase
        end
    end
endfunction

task automatic save_trace;
    integer slot;
    begin
        slot = cycle_count % TRACE_DEPTH;
        hist_cycle[slot]  = cycle_count;
        hist_pc[slot]     = tb_if_pc;
        hist_inst[slot]   = dut.if_id_inst;
        hist_ex_res[slot] = tb_ex_res;
        hist_rd[slot]     = dut.id_reg_rd_addr;
        hist_wen[slot]    = dut.reg_wen;
        hist_wdata[slot]  = dut.wb_reg_rd_data;
        hist_ls_ctl[slot] = dut.id_ls_ctl;
        hist_wren[slot]   = dut.ls_sram_wren;
        hist_daddr[slot]  = dut.ls_sram_addr;
        hist_dwdata[slot] = dut.ls_sram_wdata;
        hist_drdata[slot] = dut.ls_sram_rdata;
        hist_valid[slot]  = 1'b1;
    end
endtask

task automatic dump_recent_trace;
    integer n;
    integer slot;
    begin
        $display("[DEBUG] recent cycles:");
        for (n = TRACE_DEPTH - 1; n >= 0; n = n - 1) begin
            slot = (cycle_count - n) % TRACE_DEPTH;
            if (slot < 0) begin
                slot = slot + TRACE_DEPTH;
            end
            if (hist_valid[slot]) begin
                $display("  cyc=%0d pc=0x%08h inst=0x%08h %-10s rd=x%0d wen=%0b wdata=0x%08h ex=0x%08h ls=%b daddr=%0d wren=%b dw=0x%08h dr=0x%08h",
                    hist_cycle[slot], hist_pc[slot], hist_inst[slot], inst_name(hist_inst[slot]),
                    hist_rd[slot], hist_wen[slot], hist_wdata[slot], hist_ex_res[slot],
                    hist_ls_ctl[slot], hist_daddr[slot], hist_wren[slot],
                    hist_dwdata[slot], hist_drdata[slot]);
            end
        end
    end
endtask

task automatic fail_now;
    input [2047:0] msg;
    begin
        fail_count = fail_count + 1;
        $display("[FAIL] cycle=%0d %0s", cycle_count, msg);
        dump_recent_trace();
        $fatal(1, "[SUMMARY] suat_debug_tb failed, fail_count=%0d warn_count=%0d", fail_count, warn_count);
    end
endtask

task automatic warn_now;
    input [2047:0] msg;
    begin
        warn_count = warn_count + 1;
        $display("[WARN] cycle=%0d %0s", cycle_count, msg);
    end
endtask

task automatic print_cycle_trace;
    begin
        $display("[TRACE] cyc=%0d pc=0x%08h idx=%0d inst=0x%08h %-10s valid=%0b stall=%0b jump=%0b jpc=0x%08h rs1=x%0d:0x%08h rs2=x%0d:0x%08h rd=x%0d wen=%0b wb=0x%08h ex=0x%08h ls=%b dcs=%0b daddr=%0d wren=%b dw=0x%08h dr=0x%08h",
            cycle_count,
            tb_if_pc,
            (tb_if_pc - START_PC) >> 2,
            dut.if_id_inst,
            inst_name(dut.if_id_inst),
            dut.ifu0.inst_valid | dut.ifu0.hold_valid,
            dut.load_stall,
            tb_ex_jump,
            tb_ex_jump_pc,
            dut.id_reg_rs1_addr,
            dut.reg_id_rs1_data,
            dut.id_reg_rs2_addr,
            dut.reg_id_rs2_data,
            dut.id_reg_rd_addr,
            dut.reg_wen,
            dut.wb_reg_rd_data,
            tb_ex_res,
            dut.id_ls_ctl,
            dut.ls_sram_cs,
            dut.ls_sram_addr,
            dut.ls_sram_wren,
            dut.ls_sram_wdata,
            dut.ls_sram_rdata);
    end
endtask

task automatic check_reg;
    input integer idx;
    input [31:0] expected;
    input [2047:0] hint;
    begin
        if (dut.reg5.regs[idx] !== expected) begin
            fail_count = fail_count + 1;
            $display("[FAIL] x%0d expected=0x%08h got=0x%08h", idx, expected, dut.reg5.regs[idx]);
            $display("[HINT] %0s", hint);
        end else begin
            $display("[PASS] x%0d = 0x%08h", idx, expected);
        end
    end
endtask

task automatic check_mem;
    input integer idx;
    input [31:0] expected;
    input [2047:0] hint;
    begin
        if (dut.mem6.BRAM[idx] !== expected) begin
            fail_count = fail_count + 1;
            $display("[FAIL] BRAM[%0d] expected=0x%08h got=0x%08h", idx, expected, dut.mem6.BRAM[idx]);
            $display("[HINT] %0s", hint);
        end else begin
            $display("[PASS] BRAM[%0d] = 0x%08h", idx, expected);
        end
    end
endtask

task automatic final_random_check;
    begin
        $display("[INFO] final check for rtl/test_mem.hex randomized debug program");

        check_reg(1,  32'h12345678, "x1 is built by LUI+ADDI. Check IDU immediate decode, ALU add, WBU select, and regfile write.");
        check_reg(2,  32'h12345678, "x2 is loaded by LW. If BRAM[256] is correct, check load stall, SRAM D_RDATA timing, LSU load path, and WBU load select.");
        check_reg(3,  32'h00000078, "LB low byte should sign-extend 0x78. Check LSU byte select and sign extension.");
        check_reg(4,  32'h00000012, "LB byte offset 3 should read the high byte of 0x12345678.");
        check_reg(5,  32'h800001c0, "x5 is JAL link data. Check JAL writeback uses PC+4.");
        check_reg(6,  32'h800001c8, "x6 is AUIPC PC data before JALR. Check AUIPC uses current PC plus immediate.");
        check_reg(7,  32'h800001d0, "x7 is JALR link data. Check JALR writeback uses PC+4.");
        check_reg(8,  32'hffffffff, "ADDI -1 failed. Check I-type immediate sign extension.");
        check_reg(9,  32'hffffffff, "LB from byte 0xff should sign-extend to 0xffffffff.");
        check_reg(10, 32'h000000ff, "LBU from byte 0xff should zero-extend to 0x000000ff.");
        check_reg(11, 32'hfffff800, "ADDI -2048 failed. Check 12-bit immediate sign extension.");
        check_reg(12, 32'hfffff800, "LH from halfword 0xf800 should sign-extend.");
        check_reg(13, 32'h0000f800, "LHU from halfword 0xf800 should zero-extend.");
        check_reg(14, 32'h00000078, "SB offset 5 or LB offset 5 failed. Check byte write mask and byte select.");
        check_reg(15, 32'h00005678, "SH offset 6 or LHU offset 6 failed. Check halfword write mask and halfword select.");
        check_reg(16, 32'h12345679, "Final ADDI x16,x2,1 failed. If x2 is correct, check ADDI/ALU/writeback.");
        check_reg(17, 32'h00000400, "x17 is the data base 0x400. If it fails, inspect reset release, first fetch, rd_addr, wb_wen, and regfile write.");
        check_reg(18, 32'h0001f234, "x18 is rebuilt by LUI+ADDI before SH. Check U/I immediate handling.");
        check_reg(19, 32'ha5a55a5a, "x19 is loaded by LW from BRAM[259]. Check extra SW/LW path.");
        check_reg(20, 32'h0000005a, "x20 is LB from byte 0x5a. Check LB byte select/sign extension.");
        check_reg(21, 32'h000000a5, "x21 is LBU from byte 0xa5. Check LBU zero extension.");
        check_reg(22, 32'hffffa5a5, "x22 is LH from halfword 0xa5a5. Check LH sign extension.");
        check_reg(23, 32'h0000a5a5, "x23 is LHU from halfword 0xa5a5. Check LHU zero extension.");
        check_reg(24, 32'h0000007e, "x24 is LBU after SB offset 20. Check SB byte mask.");
        check_reg(25, 32'hffffff80, "x25 is LB after SB value 0x80. Check LB sign extension.");
        check_reg(26, 32'h00000080, "x26 is LBU after SB value 0x80. Check LBU zero extension.");
        check_reg(27, 32'h0000f234, "x27 is LHU after SH offset 22. Check SH high-half mask and LHU.");
        check_reg(28, 32'hfffff234, "x28 is LH after SH offset 22. Check LH sign extension.");
        check_reg(29, 32'h00000008, "x29 is the branch/jump pass counter. Check BEQ/BNE/BLT/BGE/BLTU/BGEU/JAL/JALR control flow.");
        check_reg(30, 32'h00000000, "x30 is the branch/jump fail counter. It should stay zero if all skipped paths were skipped.");
        check_reg(31, 32'h800001b4, "x31 is JAL link data. Check JAL target and PC+4 writeback.");

        check_mem(256, 32'h12345678, "SW should write full word to data base 0x400. Check x17, LSU address alu_res[17:2], WREN=1111, and BRAM write port.");
        check_mem(257, 32'h567878ff, "SB/SH byte enables should preserve untouched bytes. Check byte lane masks in LSU and BRAM byte writes.");
        check_mem(258, 32'h0000f800, "SH should write halfword 0xf800 at data base+8. Check halfword mask and address bit handling.");
        check_mem(259, 32'ha5a55a5a, "Extra SW/LW signature word failed. Check full-word store/load path.");
        check_mem(261, 32'hf234807e, "Mixed SB/SB/SH signature failed. Check byte lanes 0, 1, and high-half SH.");
    end
endtask

task automatic check_runtime_health;
    begin
        if (has_x32(tb_if_pc)) begin
            fail_now("PC is X/Z. Check reset, IFU PC register, and clock driving.");
        end

        if (tb_if_pc[1:0] !== 2'b00) begin
            fail_now("PC is not 4-byte aligned. Check jump/branch target calculation.");
        end

        if (tb_if_pc < START_PC) begin
            fail_now("PC is below START_PC 0x80000000. Check IFU reset PC and jump target.");
        end

        if (has_x1(dut.ifu0.inst_valid | dut.ifu0.hold_valid)) begin
            fail_now("IFU valid signal is X/Z. Check IFU reset assignments.");
        end

        if ((dut.ifu0.inst_valid | dut.ifu0.hold_valid) && has_x32(dut.if_id_inst)) begin
            fail_now("instruction is X/Z while IFU says valid. Check test_mem.hex loading, BRAM address, and BRAM read timing.");
        end

        if (has_x5(dut.id_reg_rd_addr) || has_x4(dut.id_ls_ctl) || has_x1(dut.id_wb_ctl)) begin
            fail_now("IDU control output has X/Z. Check opcode/funct decode defaults.");
        end

        if (dut.reg5.regs[0] !== 32'h00000000) begin
            fail_now("x0 changed. Regfile must keep x0 hardwired to zero.");
        end

        if (dut.load_stall) begin
            load_stall_count = load_stall_count + 1;
            if (load_stall_count > 2) begin
                fail_now("load_stall is stuck high for more than 2 cycles. Check load_wait or load-use stall logic.");
            end
        end else begin
            load_stall_count = 0;
        end

        if (dut.ls_sram_cs && has_x16(dut.ls_sram_addr)) begin
            fail_now("LSU BRAM address is X/Z during memory access. Check EXU alu_res and LSU address selection.");
        end

        if (dut.ls_sram_wren != 4'b0000) begin
            if (dut.ls_sram_addr < 16'd32) begin
                warn_now("store is writing the low BRAM region that normally holds instructions. If this is unexpected, check the base register and store immediate.");
            end

            case (dut.id_ls_ctl)
                4'b0001: begin
                    if (dut.ls_sram_wren != 4'b0001 &&
                        dut.ls_sram_wren != 4'b0010 &&
                        dut.ls_sram_wren != 4'b0100 &&
                        dut.ls_sram_wren != 4'b1000) begin
                        fail_now("SB generated an invalid byte write mask.");
                    end
                end
                4'b0010: begin
                    if (dut.ls_sram_wren != 4'b0011 &&
                        dut.ls_sram_wren != 4'b1100) begin
                        fail_now("SH generated an invalid halfword write mask.");
                    end
                end
                4'b0100: begin
                    if (dut.ls_sram_wren != 4'b1111) begin
                        fail_now("SW generated an invalid word write mask.");
                    end
                end
                default: begin
                    fail_now("store has nonzero WREN but IDU/LSU store control is not SB/SH/SW.");
                end
            endcase
        end
    end
endtask

initial begin
    integer i;

    clk = 1'b0;
    rst = 1'b1;
    cycle_count = 0;
    run_cycles = 260;
    fail_count = 0;
    warn_count = 0;
    verbose = 1;
    trace_all = 0;
    dump_end_trace = 0;
    load_stall_count = 0;

    if ($value$plusargs("cycles=%d", run_cycles)) begin
        $display("[INFO] run_cycles=%0d", run_cycles);
    end
    if ($test$plusargs("quiet")) begin
        verbose = 0;
    end
    if ($test$plusargs("trace_all")) begin
        trace_all = 1;
    end
    if ($test$plusargs("dump_end_trace")) begin
        dump_end_trace = 1;
    end
    if ($test$plusargs("vcd")) begin
        $dumpfile("suat_debug_tb.vcd");
        $dumpvars(0, suat_debug_tb);
    end

    for (i = 0; i < TRACE_DEPTH; i = i + 1) begin
        hist_valid[i] = 1'b0;
    end

    #1;
    load_store_program =
        (dut.mem6.BRAM[0]  === 32'h40000893) &&
        (dut.mem6.BRAM[1]  === 32'h123450b7) &&
        (dut.mem6.BRAM[2]  === 32'h67808093) &&
        (dut.mem6.BRAM[3]  === 32'h0018a023);

    $display("[INFO] suat_debug_tb start");
    $display("[INFO] BRAM[0..7] = %08h %08h %08h %08h %08h %08h %08h %08h",
        dut.mem6.BRAM[0], dut.mem6.BRAM[1], dut.mem6.BRAM[2], dut.mem6.BRAM[3],
        dut.mem6.BRAM[4], dut.mem6.BRAM[5], dut.mem6.BRAM[6], dut.mem6.BRAM[7]);

    if (has_x32(dut.mem6.BRAM[0])) begin
        fail_now("BRAM[0] is X/Z after initialization. Check SUAT_sram_dual $readmemh path and whether test_mem.hex was added to simulation.");
    end

    if (!load_store_program) begin
        $display("[INFO] BRAM does not match the default randomized debug program. Runtime trace will run, final scoreboarding is skipped.");
    end

    repeat (4) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    $display("[INFO] reset released at %0t", $time);

    repeat (run_cycles) @(posedge clk);
    #1;

    if (load_store_program) begin
        final_random_check();
    end

    if (fail_count == 0) begin
        if (dump_end_trace) begin
            dump_recent_trace();
        end
        $display("[SUMMARY] suat_debug_tb passed, warn_count=%0d cycles=%0d", warn_count, cycle_count);
    end else begin
        $fatal(1, "[SUMMARY] suat_debug_tb failed, fail_count=%0d warn_count=%0d", fail_count, warn_count);
    end

    $finish;
end

always @(posedge clk) begin
    #1;
    if (rst != `SUAT_RSTABLE) begin
        cycle_count = cycle_count + 1;
        save_trace();
        check_runtime_health();

        if (verbose && (trace_all ||
            dut.reg_wen ||
            dut.ls_sram_cs ||
            tb_ex_jump ||
            dut.load_stall ||
            cycle_count < 8)) begin
            print_cycle_trace();
        end
    end
end

endmodule
