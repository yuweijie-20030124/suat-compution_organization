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
localparam integer DMEM_WORDS = (1 << 14);

integer cycle_count;
integer run_cycles;
integer fail_count;
integer warn_count;
integer load_stall_count;
integer imem_loaded_words;
integer retired_step_count;

reg verbose;
reg trace_all;
reg compact_trace;
reg dump_end_trace;
reg load_store_program;
reg expanded_rv32i_program;
reg low_dmem_warned;
reg saw_terminal_self_loop;
integer last_trace_cycle;
reg step_check_enable;
reg [31:0] model_regs [0:31];
reg [31:0] model_dmem [0:DMEM_WORDS-1];
reg [31:0] model_pc;

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
reg [31:0] shadow_dmem [0:DMEM_WORDS-1];
reg        last_store_valid [0:DMEM_WORDS-1];
integer    last_store_cycle [0:DMEM_WORDS-1];
reg [31:0] last_store_pc [0:DMEM_WORDS-1];
reg [31:0] last_store_inst [0:DMEM_WORDS-1];
reg [3:0]  last_store_wren [0:DMEM_WORDS-1];
reg [31:0] last_store_wdata [0:DMEM_WORDS-1];
reg [31:0] last_store_after [0:DMEM_WORDS-1];
reg        pending_store_check_valid;
integer    pending_store_issue_cycle;
integer    pending_store_addr_idx;
reg [31:0] pending_store_pc;
reg [31:0] pending_store_inst;
reg [31:0] pending_store_addr;
reg [3:0]  pending_store_ls_ctl;
reg [1:0]  pending_store_byte_off;
reg [31:0] pending_store_rs2_data;
reg [3:0]  pending_store_expected_wren;
reg [31:0] pending_store_expected_wdata;
reg [31:0] pending_store_prior_word;
reg [31:0] pending_store_expected_word;

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

function automatic [7:0] word_byte;
    input [31:0] word;
    input [1:0]  byte_off;
    begin
        case (byte_off)
            2'b00: word_byte = word[7:0];
            2'b01: word_byte = word[15:8];
            2'b10: word_byte = word[23:16];
            default: word_byte = word[31:24];
        endcase
    end
endfunction

function automatic [31:0] signext_byte;
    input [7:0] value;
    begin
        signext_byte = {{24{value[7]}}, value};
    end
endfunction

function automatic [31:0] zeroext_byte;
    input [7:0] value;
    begin
        zeroext_byte = {24'b0, value};
    end
endfunction

function automatic [15:0] word_half;
    input [31:0] word;
    input        half_sel;
    begin
        word_half = half_sel ? word[31:16] : word[15:0];
    end
endfunction

function automatic [31:0] signext_half;
    input [15:0] value;
    begin
        signext_half = {{16{value[15]}}, value};
    end
endfunction

function automatic [31:0] zeroext_half;
    input [15:0] value;
    begin
        zeroext_half = {16'b0, value};
    end
endfunction

function automatic [31:0] ref_shift_word;
    input [31:0] word;
    input [1:0]  byte_off;
    begin
        case (byte_off)
            2'b00: ref_shift_word = word;
            2'b01: ref_shift_word = {8'h00,  word[31:8]};
            2'b10: ref_shift_word = {16'h0000, word[31:16]};
            default: ref_shift_word = {24'h000000, word[31:24]};
        endcase
    end
endfunction

function automatic [79:0] lsctl_name;
    input [3:0] ls_ctl;
    begin
        case (ls_ctl)
            4'b0000: lsctl_name = "NONE      ";
            4'b0001: lsctl_name = "SB        ";
            4'b0010: lsctl_name = "SH        ";
            4'b0100: lsctl_name = "SW        ";
            4'b1001: lsctl_name = "LB        ";
            4'b1010: lsctl_name = "LH        ";
            4'b1011: lsctl_name = "LW        ";
            4'b1101: lsctl_name = "LBU       ";
            4'b1110: lsctl_name = "LHU       ";
            default: lsctl_name = "LS?       ";
        endcase
    end
endfunction

function automatic [31:0] imm_i32;
    input [31:0] inst;
    begin
        imm_i32 = {{20{inst[31]}}, inst[31:20]};
    end
endfunction

function automatic [31:0] imm_s32;
    input [31:0] inst;
    begin
        imm_s32 = {{20{inst[31]}}, inst[31:25], inst[11:7]};
    end
endfunction

function automatic [31:0] imm_b32;
    input [31:0] inst;
    begin
        imm_b32 = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
    end
endfunction

function automatic [31:0] imm_u32;
    input [31:0] inst;
    begin
        imm_u32 = {inst[31:12], 12'b0};
    end
endfunction

function automatic [31:0] imm_j32;
    input [31:0] inst;
    begin
        imm_j32 = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
    end
endfunction

function automatic [31:0] sra32;
    input [31:0] value;
    input [4:0]  shamt;
    begin
        sra32 = $signed(value) >>> shamt;
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

task automatic print_trace_legend;
    begin
        $display("[INFO] trace legend:");
        $display("       cyc=cycle, pc=current PC, inst=instruction word, rd=destination register, wen=regfile write enable");
        $display("       wdata=register writeback data, ex=EXU result or effective address, ls=load/store control code");
        $display("       daddr=data memory word address, wren=byte write mask, dw=data written to memory, dr=data read from memory");
        $display("       note: wren/dw are the current instruction's store request signals; DMEM array updates are checked on the next cycle");
        $display("       default behavior prints every cycle; use +compact_trace to print only key cycles and show omitted-cycle counts");
    end
endtask

task automatic print_skipped_cycles;
    input integer skipped_cycles;
    begin
        if (skipped_cycles > 0) begin
            $display("[TRACE] ... skipped %0d quiet cycle(s) with no reg write, memory access, or jump", skipped_cycles);
        end
    end
endtask

task automatic fail_lsu_now;
    input [2047:0] msg;
    integer inst_idx;
    begin
        inst_idx = (tb_if_pc - START_PC) >> 2;
        fail_count = fail_count + 1;
        $display("[FAIL][LSU] cycle=%0d %0s", cycle_count, msg);
        $display("[FAIL][LSU] pc=0x%08h idx=%0d test_mem_line=%0d inst=0x%08h %-10s ex_addr=0x%08h daddr=%0d ls_ctl=%b(%-10s) wb=0x%08h raw_rdata=0x%08h",
            tb_if_pc, inst_idx, inst_idx + 1, dut.if_id_inst, inst_name(dut.if_id_inst), tb_ex_res, dut.ls_sram_addr, dut.id_ls_ctl, lsctl_name(dut.id_ls_ctl),
            dut.wb_reg_rd_data, dut.ls_sram_rdata);
        dump_recent_trace();
        $fatal(1, "[SUMMARY] suat_debug_tb failed, fail_count=%0d warn_count=%0d", fail_count, warn_count);
    end
endtask

task automatic fail_step_now;
    input [2047:0] msg;
    begin
        fail_count = fail_count + 1;
        $display("[FAIL][STEP] cycle=%0d retired_step=%0d %0s", cycle_count, retired_step_count, msg);
        dump_recent_trace();
        $fatal(1, "[SUMMARY] suat_debug_tb failed, fail_count=%0d warn_count=%0d", fail_count, warn_count);
    end
endtask

task automatic explain_load_failure;
    input [31:0] expected_word;
    input [7:0]  expected_byte;
    input [31:0] expected_shift;
    input [31:0] expected_load;
    input [31:0] actual_shift;
    input [31:0] actual_lsu_raw;
    input [31:0] actual_wb;
    begin
        $display("[DEBUG][LOAD][MODEL] mem_word=0x%08h byte_off=%0d selected_byte=0x%02h expected_shift=0x%08h expected_load=0x%08h",
            expected_word, tb_ex_res[1:0], expected_byte, expected_shift, expected_load);
        $display("[DEBUG][LOAD][DUT  ] rdata_i=0x%08h shift_rdata=0x%08h lsu_rdata_raw=0x%08h wb=0x%08h",
            dut.ls_sram_rdata, actual_shift, actual_lsu_raw, actual_wb);

        if (dut.ls_sram_rdata === expected_word) begin
            $display("[CHECK][LOAD] Stage 1 SRAM read: PASS");
        end else begin
            $display("[CHECK][LOAD] Stage 1 SRAM read: FAIL");
            $display("[LOOK HERE] DMEM contents or LSU address path. Inspect SUAT_top address selection and memory timing first.");
        end

        if (actual_shift === expected_shift) begin
            $display("[CHECK][LOAD] Stage 2 byte alignment/right shift: PASS");
        end else begin
            $display("[CHECK][LOAD] Stage 2 byte alignment/right shift: FAIL");
            $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_lsu.v around right_shifter and addr[1:0].");
        end

        if (actual_lsu_raw === expected_load) begin
            $display("[CHECK][LOAD] Stage 3 LSU load formatting: PASS");
        end else begin
            $display("[CHECK][LOAD] Stage 3 LSU load formatting: FAIL");
            if ((actual_lsu_raw[31:8] === {24{expected_byte[7]}}) &&
                (actual_lsu_raw[7:0] == 8'h00) &&
                (expected_byte != 8'h00)) begin
                $display("[DIAGNOSIS] High 24 bits are the correct sign extension, but the low 8 bits were zeroed.");
                $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_lsu.v:25-27");
                $display("[EXPECT ] LB should use {{24{shift_rdata[7]}}, shift_rdata[7:0]}");
                $display("[SYMPTOM] Current behavior matches {{24{shift_rdata[7]}}, 8'b0}");
            end else if (actual_lsu_raw == {24'b0, expected_byte}) begin
                $display("[DIAGNOSIS] The selected byte is correct, but sign extension is missing.");
                $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_lsu.v load formatting for LB.");
            end else begin
                $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_lsu.v load formatting logic.");
            end
        end

        if (actual_wb === actual_lsu_raw) begin
            $display("[CHECK][LOAD] Stage 4 writeback select: PASS");
        end else begin
            $display("[CHECK][LOAD] Stage 4 writeback select: FAIL");
            $display("[LOOK HERE] SUAT_wbu or top-level load writeback muxing.");
        end
    end
endtask

task automatic print_word_bytes;
    input [255:0] tag;
    input [31:0]  word;
    begin
        $display("%0s bytes[3:0] = {%02h, %02h, %02h, %02h}",
            tag, word[31:24], word[23:16], word[15:8], word[7:0]);
    end
endtask

task automatic print_last_store_context;
    input integer addr_idx;
    integer store_idx;
    begin
        if (addr_idx < 0 || addr_idx >= DMEM_WORDS) begin
            $display("[DEBUG][STORE] address %0d is outside tracked DMEM range.", addr_idx);
        end else if (last_store_valid[addr_idx]) begin
            store_idx = (last_store_pc[addr_idx] - START_PC) >> 2;
            $display("[DEBUG][STORE] most recent modeled writer to DMEM[%0d]: cycle=%0d pc=0x%08h idx=%0d line=%0d inst=0x%08h %-10s",
                addr_idx, last_store_cycle[addr_idx], last_store_pc[addr_idx], store_idx, store_idx + 1,
                last_store_inst[addr_idx], inst_name(last_store_inst[addr_idx]));
            $display("[DEBUG][STORE] modeled_wren=%b modeled_wdata=0x%08h modeled_word_after=0x%08h",
                last_store_wren[addr_idx], last_store_wdata[addr_idx], last_store_after[addr_idx]);
            print_word_bytes("[DEBUG][STORE] modeled word after", last_store_after[addr_idx]);
        end else begin
            $display("[DEBUG][STORE] no prior modeled store has written DMEM[%0d] yet.", addr_idx);
        end
    end
endtask

task automatic check_pending_store_commit;
    reg [31:0] actual_word_after;
    integer inst_idx;
    begin
        if (pending_store_check_valid) begin
            actual_word_after = dut.mem6.sram[pending_store_addr_idx];
            if (actual_word_after !== pending_store_expected_word) begin
                inst_idx = (pending_store_pc - START_PC) >> 2;
                $display("[DEBUG][STORE][REQ  ] issue_cycle=%0d commit_check_cycle=%0d op=%-10s pc=0x%08h idx=%0d line=%0d inst=0x%08h",
                    pending_store_issue_cycle, cycle_count, lsctl_name(pending_store_ls_ctl),
                    pending_store_pc, inst_idx, inst_idx + 1, pending_store_inst);
                $display("[DEBUG][STORE][REQ  ] addr=0x%08h word_addr=%0d byte_off=%0d rs2=0x%08h expected_wren=%b expected_wdata=0x%08h",
                    pending_store_addr, pending_store_addr_idx, pending_store_byte_off,
                    pending_store_rs2_data, pending_store_expected_wren, pending_store_expected_wdata);
                $display("[DEBUG][STORE][MEM  ] prior_word=0x%08h expected_word_after=0x%08h actual_word_after=0x%08h",
                    pending_store_prior_word, pending_store_expected_word, actual_word_after);
                print_word_bytes("[DEBUG][STORE] prior word       ", pending_store_prior_word);
                print_word_bytes("[DEBUG][STORE] expected after   ", pending_store_expected_word);
                print_word_bytes("[DEBUG][STORE] actual after     ", actual_word_after);
                $display("[CHECK][STORE] Stage 4 memory array update (next-cycle commit check): FAIL");
                $display("[DIAGNOSIS] The store request itself already matched the teaching model in cycle=%0d.", pending_store_issue_cycle);
                $display("[DIAGNOSIS] By cycle=%0d, DMEM[%0d] still did not contain the expected post-store word.", cycle_count, pending_store_addr_idx);
                $display("[NOT THIS] This is no longer a byte-mask or store-data-lane bug inside the LSU request path.");
                $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_sram.v posedge write always blocks.");
                $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_top.v mem6 wiring: ADDR/WDATA/WREN into the data SRAM.");
                $display("[EXPECT ] At the committing clock edge, memory should see the same ADDR/WREN/WDATA shown in the request line above.");
                fail_lsu_now("store request was correct, but DMEM did not commit the word by the next clock edge.");
            end else if (trace_all) begin
                $display("[CHECK][STORE] Stage 4 memory array update (next-cycle commit check): PASS");
            end
            pending_store_check_valid = 1'b0;
        end
    end
endtask

task automatic print_cycle_trace;
    begin
        $display("[TRACE] cyc=%0d pc=0x%08h idx=%0d inst=0x%08h %-10s valid=%0b stall=%0b jump=%0b jpc=0x%08h rs1=x%0d:0x%08h rs2=x%0d:0x%08h rd=x%0d wen=%0b wb=0x%08h ex=0x%08h ls=%b(%-10s) dcs=%0b daddr=%0d wren=%b dw=0x%08h dr=0x%08h",
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
            lsctl_name(dut.id_ls_ctl),
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

task automatic check_dmem;
    input integer idx;
    input [31:0] expected;
    input [2047:0] hint;
    begin
        if (dut.mem6.sram[idx] !== expected) begin
            fail_count = fail_count + 1;
            $display("[FAIL] DMEM[%0d] expected=0x%08h got=0x%08h", idx, expected, dut.mem6.sram[idx]);
            $display("[HINT] %0s", hint);
        end else begin
            $display("[PASS] DMEM[%0d] = 0x%08h", idx, expected);
        end
    end
endtask

task automatic final_mem_check;
    begin
        $display("[INFO] final check for rtl/test_mem.hex sb/sw/lb/lw program");

        check_reg(1,  32'h12345678, "x1 is built by LUI+ADDI. Check immediate decode, ALU add, and regfile writeback.");
        check_reg(2,  32'h12345678, "x2 is loaded by LW from DMEM[256]. Check SW/LW path, load stall, and writeback select.");
        check_reg(3,  32'h00000078, "LB offset 0 should return byte 0x78.");
        check_reg(4,  32'h00000056, "LB offset 1 should return byte 0x56.");
        check_reg(5,  32'h00000034, "LB offset 2 should return byte 0x34.");
        check_reg(6,  32'h00000012, "LB offset 3 should return byte 0x12.");
        check_reg(7,  32'hffffff80, "x7 holds the SB source byte -128. Check ADDI immediate sign extension if it is wrong.");
        check_reg(8,  32'hffffff80, "LB after SB at offset 4 should sign-extend 0x80.");
        check_reg(9,  32'h0000007e, "x9 holds the second SB source byte 0x7e.");
        check_reg(10, 32'h7e000080, "LW after two SB writes should preserve byte lanes and read back 0x7e000080.");
        check_reg(11, 32'h0000007e, "LB offset 7 should return byte 0x7e.");
        check_reg(17, 32'h00000400, "x17 is the data base 0x400. If it fails, inspect reset release, first fetch, and regfile writeback.");

        check_dmem(256, 32'h12345678, "SW should write full word 0x12345678 to data base 0x400.");
        check_dmem(257, 32'h7e000080, "Two SB writes should update only byte lanes 0 and 3 and preserve the middle bytes.");
    end
endtask

task automatic final_expanded_check;
    begin
        $display("[INFO] final check for rtl/test_mem.hex expanded rv32i coverage program");

        check_reg(0,  32'h00000000, "x0 must stay zero even after ADDI/ADD/LUI write attempts.");
        check_reg(1,  32'h0000000e, "x1 should reload the BEQ/BNE/BLT/BGE/BLTU/BGEU summary word from DMEM[260].");
        check_reg(2,  32'h0000000e, "x2 should reload the second branch summary word from DMEM[261].");
        check_reg(3,  32'h000000aa, "x3 should reload the jump summary word from DMEM[266].");
        check_reg(4,  32'hffffff80, "x4 should be the sign-extended top byte of DMEM[267].");
        check_reg(5,  32'h80000234, "x5 should reload the saved JALR link word from DMEM[267].");
        check_reg(6,  32'h80000214, "x6 should reload the saved JAL link word from DMEM[268].");
        check_reg(7,  32'h80000234, "x7 should reload the saved JALR link word from DMEM[269].");
        check_reg(8,  32'h12345678, "x8 should hold the first LW result from DMEM[256].");
        check_reg(9,  32'h00000078, "x9 should hold LB offset 0 from 0x12345678.");
        check_reg(10, 32'h00000056, "x10 should hold LB offset 1 from 0x12345678.");
        check_reg(11, 32'h00000034, "x11 should hold LB offset 2 from 0x12345678.");
        check_reg(12, 32'h00000012, "x12 should hold LB offset 3 from 0x12345678.");
        check_reg(13, 32'h21000fff, "x13 should reflect the mixed SB/LW result at DMEM[257].");
        check_reg(14, 32'hffffffff, "x14 should sign-extend byte 0xff from DMEM[257].");
        check_reg(15, 32'h0000000f, "x15 should read back the byte 0x0f written by SB.");
        check_reg(16, 32'h00000000, "x16 should read back the zero byte written by SB.");
        check_reg(17, 32'h00000400, "x17 is the data base 0x400 and should remain unchanged.");
        check_reg(18, 32'h00000021, "x18 should read back the top byte 0x21 from DMEM[257].");
        check_reg(19, 32'h80000000, "x19 should hold the LW result from DMEM[258].");
        check_reg(20, 32'hffffff80, "x20 should sign-extend byte 0x80 from DMEM[258].");
        check_reg(21, 32'h7fffffff, "x21 should hold the LW result from DMEM[259].");
        check_reg(22, 32'h0000007f, "x22 should read back byte 0x7f from DMEM[259].");
        check_reg(23, 32'h0000000e, "x23 should accumulate the BEQ summary value 14.");
        check_reg(24, 32'h0000000e, "x24 should accumulate the BNE summary value 14.");
        check_reg(25, 32'h0000000e, "x25 should accumulate the BLT summary value 14.");
        check_reg(26, 32'h0000000e, "x26 should accumulate the BGE summary value 14.");
        check_reg(27, 32'h0000000e, "x27 should accumulate the BLTU summary value 14.");
        check_reg(28, 32'h0000000e, "x28 should accumulate the BGEU summary value 14.");
        check_reg(29, 32'h80000240, "x29 should hold the last AUIPC base used for JALR.");
        check_reg(30, 32'h000000aa, "x30 should hold the final jump accumulator value 0xaa.");
        check_reg(31, 32'h80000234, "x31 should keep the saved JALR return address.");

        check_dmem(255, 32'h00000000, "DMEM[255] is a guard word before the data region and should remain zero.");
        check_dmem(256, 32'h12345678, "DMEM[256] should hold the first SW pattern.");
        check_dmem(257, 32'h21000fff, "DMEM[257] should reflect four SB updates to one word.");
        check_dmem(258, 32'h80000000, "DMEM[258] should hold the negative word used by SRL/SRA/LB tests.");
        check_dmem(259, 32'h7fffffff, "DMEM[259] should hold the positive boundary word.");
        check_dmem(260, 32'h0000000e, "DMEM[260] should store the BEQ summary.");
        check_dmem(261, 32'h0000000e, "DMEM[261] should store the BNE summary.");
        check_dmem(262, 32'h0000000e, "DMEM[262] should store the BLT summary.");
        check_dmem(263, 32'h0000000e, "DMEM[263] should store the BGE summary.");
        check_dmem(264, 32'h0000000e, "DMEM[264] should store the BLTU summary.");
        check_dmem(265, 32'h0000000e, "DMEM[265] should store the BGEU summary.");
        check_dmem(266, 32'h000000aa, "DMEM[266] should store the final jump accumulator.");
        check_dmem(267, 32'h80000234, "DMEM[267] should store the JALR link value.");
        check_dmem(268, 32'h80000214, "DMEM[268] should store the JAL link value.");
        check_dmem(269, 32'h80000234, "DMEM[269] should store the second JALR link value.");
        check_dmem(270, 32'h00000000, "DMEM[270] is a guard word after the data region and should remain zero.");
    end
endtask

task automatic check_store_semantics;
    integer addr_idx;
    reg [31:0] expected_word;
    reg [31:0] prior_word;
    reg [3:0]  expected_wren;
    reg [31:0] expected_wdata;
    reg [1:0]  byte_off;
    begin
        if (dut.id_ls_ctl == 4'b0001 || dut.id_ls_ctl == 4'b0010 || dut.id_ls_ctl == 4'b0100) begin
            addr_idx = dut.ls_sram_addr;
            byte_off = tb_ex_res[1:0];
            prior_word = shadow_dmem[addr_idx];
            expected_word = prior_word;
            expected_wren = 4'b0000;
            expected_wdata = dut.ls_sram_wdata;

            case (dut.id_ls_ctl)
                4'b0001: begin
                    expected_wren = (4'b0001 << byte_off);
                    expected_wdata = dut.reg_id_rs2_data << (byte_off * 8);
                end
                4'b0010: begin
                    expected_wren = byte_off[0] ? 4'b0000 : (byte_off[1] ? 4'b1100 : 4'b0011);
                    expected_wdata = {2{dut.reg_id_rs2_data[15:0]}};
                end
                4'b0100: begin
                    expected_wren = (byte_off == 2'b00) ? 4'b1111 : 4'b0000;
                    expected_wdata = dut.reg_id_rs2_data;
                end
                default: begin
                    expected_wren = 4'b0000;
                    expected_wdata = dut.ls_sram_wdata;
                end
            endcase

            if (expected_wren[0]) expected_word[7:0]   = expected_wdata[7:0];
            if (expected_wren[1]) expected_word[15:8]  = expected_wdata[15:8];
            if (expected_wren[2]) expected_word[23:16] = expected_wdata[23:16];
            if (expected_wren[3]) expected_word[31:24] = expected_wdata[31:24];

            if (!dut.ls_sram_cs || dut.ls_sram_wren !== expected_wren ||
                ((expected_wren != 4'b0000) && (dut.ls_sram_wdata !== expected_wdata))) begin
                $display("[DEBUG][STORE][MODEL] op=%-10s addr=0x%08h word_addr=%0d byte_off=%0d rs2=0x%08h expected_wren=%b expected_wdata=0x%08h",
                    lsctl_name(dut.id_ls_ctl), tb_ex_res, addr_idx, byte_off, dut.reg_id_rs2_data, expected_wren, expected_wdata);
                $display("[DEBUG][STORE][DUT  ] ls_sram_cs=%0b actual_wren=%b actual_wdata=0x%08h prior_word=0x%08h",
                    dut.ls_sram_cs, dut.ls_sram_wren, dut.ls_sram_wdata, prior_word);
                print_word_bytes("[DEBUG][STORE] prior word       ", prior_word);
                print_word_bytes("[DEBUG][STORE] expected after   ", expected_word);
                $display("[INFO ][STORE] Stage 4 commit is checked on the next cycle, because the SRAM array writes on the clock edge.");

                if (dut.ls_sram_cs) begin
                    $display("[CHECK][STORE] Stage 1 memory request: PASS");
                end else begin
                    $display("[CHECK][STORE] Stage 1 memory request: FAIL");
                    $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_top.v load/store chip-select generation.");
                end

                if (dut.ls_sram_wren === expected_wren) begin
                    $display("[CHECK][STORE] Stage 2 byte mask generation: PASS");
                end else begin
                    $display("[CHECK][STORE] Stage 2 byte mask generation: FAIL");
                    case (dut.id_ls_ctl)
                        4'b0001: $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_lsu.v byte_at_00..byte_at_11 and WREN assignments.");
                        4'b0010: $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_top.v sh_wren generation. SH should use 0011 for offset 0 and 1100 for offset 2.");
                        4'b0100: $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_lsu.v word_at_00 and WREN assignments. SW should normally drive 1111.");
                        default: $display("[LOOK HERE] Store control decode path.");
                    endcase
                end

                if ((expected_wren == 4'b0000) || (dut.ls_sram_wdata === expected_wdata)) begin
                    $display("[CHECK][STORE] Stage 3 write-data lane placement: PASS");
                end else begin
                    $display("[CHECK][STORE] Stage 3 write-data lane placement: FAIL");
                    case (dut.id_ls_ctl)
                        4'b0001: begin
                            $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_lsu.v left_shifter output.");
                            $display("[EXPECT ] SB should place rs2[7:0] into the selected byte lane by shifting left 8*offset bits.");
                        end
                        4'b0010: begin
                            $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_top.v sh_wdata generation.");
                            $display("[EXPECT ] SH should use {2{rs2[15:0]}} so either low or high half can be written.");
                        end
                        4'b0100: begin
                            $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_lsu.v left_shifter output for SW.");
                            $display("[EXPECT ] SW should drive the unmodified 32-bit rs2 value when address offset is 0.");
                        end
                        default: begin
                        end
                    endcase
                end
                fail_lsu_now("store control or store data mismatched the teaching model.");
            end

            shadow_dmem[addr_idx] = expected_word;
            last_store_valid[addr_idx] = 1'b1;
            last_store_cycle[addr_idx] = cycle_count;
            last_store_pc[addr_idx] = tb_if_pc;
            last_store_inst[addr_idx] = dut.if_id_inst;
            last_store_wren[addr_idx] = dut.ls_sram_wren;
            last_store_wdata[addr_idx] = dut.ls_sram_wdata;
            last_store_after[addr_idx] = expected_word;
            pending_store_check_valid = 1'b1;
            pending_store_issue_cycle = cycle_count;
            pending_store_addr_idx = addr_idx;
            pending_store_pc = tb_if_pc;
            pending_store_inst = dut.if_id_inst;
            pending_store_addr = tb_ex_res;
            pending_store_ls_ctl = dut.id_ls_ctl;
            pending_store_byte_off = byte_off;
            pending_store_rs2_data = dut.reg_id_rs2_data;
            pending_store_expected_wren = expected_wren;
            pending_store_expected_wdata = expected_wdata;
            pending_store_prior_word = prior_word;
            pending_store_expected_word = expected_word;
            if (trace_all) begin
                $display("[DEBUG][STORE] addr=0x%08h word_addr=%0d wren=%b prior=0x%08h wdata=0x%08h shadow_after=0x%08h",
                    tb_ex_res, addr_idx, dut.ls_sram_wren, prior_word, dut.ls_sram_wdata, expected_word);
                $display("[DEBUG][STORE] Stage 4 commit will be verified next cycle.");
            end
        end
    end
endtask

task automatic check_load_semantics;
    integer addr_idx;
    reg [31:0] expected_word;
    reg [31:0] expected_load;
    reg [31:0] expected_shift;
    reg [31:0] actual_align;
    reg [31:0] actual_format;
    reg [7:0]  expected_byte;
    reg [15:0] expected_half;
    begin
        if (dut.reg_wen &&
            (dut.id_ls_ctl == 4'b1001 || dut.id_ls_ctl == 4'b1010 || dut.id_ls_ctl == 4'b1011 ||
             dut.id_ls_ctl == 4'b1101 || dut.id_ls_ctl == 4'b1110)) begin
            addr_idx = dut.ls_sram_addr;
            expected_word = shadow_dmem[addr_idx];
            expected_byte = word_byte(expected_word, tb_ex_res[1:0]);
            expected_half = word_half(expected_word, tb_ex_res[1]);
            expected_shift = ref_shift_word(expected_word, tb_ex_res[1:0]);
            actual_align = 32'h00000000;
            actual_format = dut.wb_reg_rd_data;

            case (dut.id_ls_ctl)
                4'b1001: begin
                    expected_load = signext_byte(expected_byte);
                    actual_align = dut.lsu3.shift_rdata;
                    actual_format = dut.lsu_rdata_raw;
                end
                4'b1101: begin
                    expected_load = zeroext_byte(expected_byte);
                    actual_align = {24'b0, dut.ls_load_byte};
                    actual_format = dut.ls_wb_data;
                end
                4'b1010: begin
                    expected_load = signext_half(expected_half);
                    actual_align = {16'b0, dut.ls_load_half};
                    actual_format = dut.ls_wb_data;
                end
                4'b1110: begin
                    expected_load = zeroext_half(expected_half);
                    actual_align = {16'b0, dut.ls_load_half};
                    actual_format = dut.ls_wb_data;
                end
                default: begin
                    expected_load = expected_word;
                    actual_align = dut.lsu3.shift_rdata;
                    actual_format = dut.lsu_rdata_raw;
                end
            endcase

            if (dut.wb_reg_rd_data !== expected_load) begin
                $display("[DEBUG][LOAD] op=%-10s addr=0x%08h word_addr=%0d byte_off=%0d expected_word=0x%08h expected_byte=0x%02h expected_half=0x%04h expected_load=0x%08h actual_wb=0x%08h",
                    lsctl_name(dut.id_ls_ctl), tb_ex_res, addr_idx, tb_ex_res[1:0], expected_word, expected_byte, expected_half, expected_load, dut.wb_reg_rd_data);
                $display("[DEBUG][LOAD][MODEL] expected_shift=0x%08h expected_byte_ext=0x%08h expected_half_ext=0x%08h",
                    expected_shift, signext_byte(expected_byte), signext_half(expected_half));
                $display("[DEBUG][LOAD][DUT  ] rdata_i=0x%08h shift_rdata=0x%08h ls_load_byte=0x%02h ls_load_half=0x%04h format_data=0x%08h wb=0x%08h",
                    dut.ls_sram_rdata, dut.lsu3.shift_rdata, dut.ls_load_byte, dut.ls_load_half, actual_format, dut.wb_reg_rd_data);
                print_word_bytes("[DEBUG][LOAD] shadow word     ", expected_word);
                print_word_bytes("[DEBUG][LOAD] raw memory word ", dut.ls_sram_rdata);

                if (dut.ls_sram_rdata === expected_word) begin
                    $display("[CHECK][LOAD] Stage 1 SRAM read: PASS");
                    $display("[DIAGNOSIS] DMEM[%0d] already contains the expected word, so the store path and SRAM contents for this address look correct.", addr_idx);
                    $display("[NOT STORE] Do not debug the earlier SW/SB/SH for this failure. The first wrong value appears after the memory read.");
                    $display("[DIAGNOSIS] Focus on the load datapath after the memory read: byte/halfword selection, sign extension, zero extension, and WB muxing.");
                end else begin
                    $display("[CHECK][LOAD] Stage 1 SRAM read: FAIL");
                    $display("[DIAGNOSIS] The raw word coming back from DMEM[%0d] is already wrong, so this is not only a load-formatting problem.", addr_idx);
                    $display("[DIAGNOSIS] Check effective address generation first, then inspect the most recent store that should have produced this word.");
                    print_last_store_context(addr_idx);
                    $display("[LOOK HERE] DMEM contents or LSU address path. Inspect SUAT_top address selection and memory timing first.");
                end

                case (dut.id_ls_ctl)
                    4'b1001: begin
                        if (dut.lsu3.shift_rdata === expected_shift) begin
                            $display("[CHECK][LOAD] Stage 2 byte alignment/right shift: PASS");
                        end else begin
                            $display("[CHECK][LOAD] Stage 2 byte alignment/right shift: FAIL");
                            $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_lsu.v right_shifter and addr[1:0].");
                        end

                        if (actual_format === expected_load) begin
                            $display("[CHECK][LOAD] Stage 3 LB sign extension: PASS");
                        end else begin
                            $display("[CHECK][LOAD] Stage 3 LB sign extension: FAIL");
                            if ((actual_format[31:8] === {24{expected_byte[7]}}) &&
                                (actual_format[7:0] == 8'h00) &&
                                (expected_byte != 8'h00)) begin
                                $display("[DIAGNOSIS] High 24 bits are correct sign bits, but the low 8 bits were forced to zero.");
                                $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_lsu.v:25-27");
                                $display("[EXPECT ] LB should use {{24{shift_rdata[7]}}, shift_rdata[7:0]}");
                                $display("[SYMPTOM] Current behavior matches {{24{shift_rdata[7]}}, 8'b0}");
                            end else if (actual_format == zeroext_byte(expected_byte)) begin
                                $display("[DIAGNOSIS] The selected byte is correct, but LB was zero-extended instead of sign-extended.");
                                $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_lsu.v load formatting for LB.");
                            end else begin
                                $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_lsu.v load formatting logic for LB.");
                            end
                        end
                    end
                    4'b1101: begin
                        if (dut.ls_load_byte === expected_byte) begin
                            $display("[CHECK][LOAD] Stage 2 byte selection: PASS");
                        end else begin
                            $display("[CHECK][LOAD] Stage 2 byte selection: FAIL");
                            $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_top.v ls_load_byte mux.");
                        end

                        if (actual_format === expected_load) begin
                            $display("[CHECK][LOAD] Stage 3 LBU zero extension: PASS");
                        end else begin
                            $display("[CHECK][LOAD] Stage 3 LBU zero extension: FAIL");
                            if (actual_format == signext_byte(expected_byte)) begin
                                $display("[DIAGNOSIS] Byte selection is correct, but LBU was sign-extended instead of zero-extended.");
                            end
                            $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_top.v ls_wb_data selection for inst_lbu.");
                            $display("[EXPECT ] LBU should use {24'b0, ls_load_byte}");
                        end
                    end
                    4'b1010: begin
                        if (tb_ex_res[0] !== 1'b0) begin
                            $display("[CHECK][LOAD] Stage 0 halfword alignment: FAIL");
                            $display("[DIAGNOSIS] LH at odd byte offset is misaligned. This simple lab CPU usually expects offset[0] == 0 for halfword access.");
                        end else begin
                            $display("[CHECK][LOAD] Stage 0 halfword alignment: PASS");
                        end

                        if (dut.ls_load_half === expected_half) begin
                            $display("[CHECK][LOAD] Stage 2 halfword selection: PASS");
                        end else begin
                            $display("[CHECK][LOAD] Stage 2 halfword selection: FAIL");
                            $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_top.v ls_load_half mux.");
                        end

                        if (actual_format === expected_load) begin
                            $display("[CHECK][LOAD] Stage 3 LH sign extension: PASS");
                        end else begin
                            $display("[CHECK][LOAD] Stage 3 LH sign extension: FAIL");
                            if (actual_format == zeroext_half(expected_half)) begin
                                $display("[DIAGNOSIS] Halfword selection is correct, but LH was zero-extended instead of sign-extended.");
                            end
                            $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_top.v ls_wb_data selection for inst_lh.");
                            $display("[EXPECT ] LH should use {{16{ls_load_half[15]}}, ls_load_half}");
                        end
                    end
                    4'b1110: begin
                        if (tb_ex_res[0] !== 1'b0) begin
                            $display("[CHECK][LOAD] Stage 0 halfword alignment: FAIL");
                            $display("[DIAGNOSIS] LHU at odd byte offset is misaligned. This simple lab CPU usually expects offset[0] == 0 for halfword access.");
                        end else begin
                            $display("[CHECK][LOAD] Stage 0 halfword alignment: PASS");
                        end

                        if (dut.ls_load_half === expected_half) begin
                            $display("[CHECK][LOAD] Stage 2 halfword selection: PASS");
                        end else begin
                            $display("[CHECK][LOAD] Stage 2 halfword selection: FAIL");
                            $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_top.v ls_load_half mux.");
                        end

                        if (actual_format === expected_load) begin
                            $display("[CHECK][LOAD] Stage 3 LHU zero extension: PASS");
                        end else begin
                            $display("[CHECK][LOAD] Stage 3 LHU zero extension: FAIL");
                            if (actual_format == signext_half(expected_half)) begin
                                $display("[DIAGNOSIS] Halfword selection is correct, but LHU was sign-extended instead of zero-extended.");
                            end
                            $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_top.v ls_wb_data selection for inst_lhu.");
                            $display("[EXPECT ] LHU should use {16'b0, ls_load_half}");
                        end
                    end
                    default: begin
                        if (dut.lsu3.shift_rdata === expected_shift) begin
                            $display("[CHECK][LOAD] Stage 2 word alignment/right shift: PASS");
                        end else begin
                            $display("[CHECK][LOAD] Stage 2 word alignment/right shift: FAIL");
                            $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_lsu.v right_shifter and addr[1:0].");
                        end

                        if (actual_format === expected_load) begin
                            $display("[CHECK][LOAD] Stage 3 LW formatting: PASS");
                        end else begin
                            $display("[CHECK][LOAD] Stage 3 LW formatting: FAIL");
                            $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_lsu.v load formatting logic for LW.");
                        end
                    end
                endcase

                if ((dut.ls_sram_rdata === expected_word) && (dut.id_ls_ctl == 4'b1001 || dut.id_ls_ctl == 4'b1011 ||
                    dut.id_ls_ctl == 4'b1010 || dut.id_ls_ctl == 4'b1101 || dut.id_ls_ctl == 4'b1110)) begin
                    $display("[SUMMARY][LOAD] Effective address and SRAM contents are consistent with the model.");
                    $display("[SUMMARY][LOAD] The first bad transformation happens inside the load datapath, not in the earlier store.");
                end

                if (dut.wb_reg_rd_data === actual_format) begin
                    $display("[CHECK][LOAD] Stage 4 writeback select: PASS");
                end else begin
                    $display("[CHECK][LOAD] Stage 4 writeback select: FAIL");
                    $display("[LOOK HERE] /home/yuweijie/suat-compution_organization/lab4/rtl/SUAT_wbu.v or SUAT_top.v load writeback muxing.");
                end

                fail_lsu_now("load result mismatched the shadow-memory model.");
            end
        end
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

        if (tb_ex_jump && (tb_ex_jump_pc[1:0] !== 2'b00)) begin
            fail_now("jump_pc is not 4-byte aligned. Check EXU branch/jump target add path.");
        end

        if ((imem_loaded_words > 0) && (dut.if_sram_addr >= imem_loaded_words)) begin
            // IFU is prefetching beyond the loaded image. End-of-program handling
            // is done in the main initial block, so skip X checks for this tail cycle.
        end else begin
            if (has_x1(dut.ifu0.inst_valid | dut.ifu0.hold_valid)) begin
                fail_now("IFU valid signal is X/Z. Check IFU reset assignments.");
            end

            if ((dut.ifu0.inst_valid | dut.ifu0.hold_valid) && has_x32(dut.if_id_inst)) begin
                fail_now("instruction is X/Z while IFU says valid. Check test_mem.hex loading, IMEM address, and SRAM read timing.");
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
                fail_now("LSU SRAM address is X/Z during memory access. Check EXU alu_res and LSU address selection.");
            end

            if (dut.ls_sram_wren != 4'b0000) begin
                if ((dut.ls_sram_addr < 16'd32) && !low_dmem_warned) begin
                    warn_now("store is writing low DMEM words. If this is unexpected, check the base register and store immediate.");
                    low_dmem_warned = 1'b1;
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
    end
endtask

task automatic check_step_semantics;
    integer inst_idx;
    integer word_addr;
    integer reg_idx;
    integer prev_step_idx;
    reg [31:0] inst;
    reg [31:0] rs1_val;
    reg [31:0] rs2_val;
    reg [31:0] alu_addr;
    reg [31:0] expected_wb;
    reg [31:0] expected_next_pc;
    reg [31:0] old_word;
    reg [31:0] new_word;
    reg [4:0]  rs1;
    reg [4:0]  rs2;
    reg [4:0]  rd;
    reg [2:0]  funct3;
    reg [6:0]  opcode;
    reg [6:0]  funct7;
    reg        expected_jump;
    reg        expected_wen;
    reg        expected_store;
    reg        step_ok;
    begin
        if (!step_check_enable) begin
        end else if (!(dut.ifu0.inst_valid | dut.ifu0.hold_valid)) begin
        end else begin
            if (tb_if_pc !== model_pc) begin
                if (retired_step_count == 0) begin
                    fail_step_now("PC mismatch before executing the first instruction. Check IFU reset PC.");
                end else begin
                    prev_step_idx = retired_step_count - 1;
                    $display("[FAIL][STEP] pc mismatch before step=%0d. Previous instruction idx=%0d line=%0d expected next_pc=0x%08h got current pc=0x%08h",
                        retired_step_count, prev_step_idx, prev_step_idx + 1, model_pc, tb_if_pc);
                    fail_step_now("architectural PC state does not match the previous instruction's expected next PC.");
                end
            end

            inst_idx = (model_pc - START_PC) >> 2;
            if (inst_idx < 0 || inst_idx >= imem_loaded_words) begin
                fail_step_now("model PC ran outside the loaded IMEM range. Check IFU next-PC sequencing.");
            end

            inst = dut.imem6.sram[inst_idx];
            rs1 = inst[19:15];
            rs2 = inst[24:20];
            rd = inst[11:7];
            funct3 = inst[14:12];
            funct7 = inst[31:25];
            opcode = inst[6:0];
            rs1_val = model_regs[rs1];
            rs2_val = model_regs[rs2];

            expected_wb = 32'h00000000;
            expected_next_pc = model_pc + 32'd4;
            expected_jump = 1'b0;
            expected_wen = 1'b0;
            expected_store = 1'b0;
            old_word = 32'h00000000;
            new_word = 32'h00000000;
            word_addr = 0;
            alu_addr = 32'h00000000;

            // At the start of this cycle, the architectural register state should
            // already reflect all previously retired instructions.
            for (reg_idx = 0; reg_idx < 32; reg_idx = reg_idx + 1) begin
                if (dut.reg5.regs[reg_idx] !== model_regs[reg_idx]) begin
                    if (retired_step_count == 0) begin
                        $display("[FAIL][STEP] reg mismatch before executing the first instruction: x%0d expected=0x%08h got=0x%08h",
                            reg_idx, model_regs[reg_idx], dut.reg5.regs[reg_idx]);
                    end else begin
                        prev_step_idx = retired_step_count - 1;
                        $display("[FAIL][STEP] reg mismatch before step=%0d. Previous instruction idx=%0d line=%0d wrote wrong architectural state: x%0d expected=0x%08h got=0x%08h",
                            retired_step_count, prev_step_idx, prev_step_idx + 1, reg_idx, model_regs[reg_idx], dut.reg5.regs[reg_idx]);
                    end
                    fail_step_now("architectural register state does not match the reference model.");
                end
            end

            case (opcode)
                7'b0110111: begin
                    expected_wen = 1'b1;
                    expected_wb = imm_u32(inst);
                end
                7'b0010111: begin
                    expected_wen = 1'b1;
                    expected_wb = model_pc + imm_u32(inst);
                end
                7'b1101111: begin
                    expected_wen = 1'b1;
                    expected_wb = model_pc + 32'd4;
                    expected_next_pc = model_pc + imm_j32(inst);
                    expected_jump = 1'b1;
                end
                7'b1100111: begin
                    expected_wen = 1'b1;
                    expected_wb = model_pc + 32'd4;
                    expected_next_pc = (rs1_val + imm_i32(inst)) & 32'hffff_fffe;
                    expected_jump = 1'b1;
                end
                7'b1100011: begin
                    if (branch_truth(funct3, rs1_val, rs2_val)) begin
                        expected_next_pc = model_pc + imm_b32(inst);
                        expected_jump = 1'b1;
                    end
                end
                7'b0010011: begin
                    expected_wen = 1'b1;
                    case (funct3)
                        3'b000: expected_wb = rs1_val + imm_i32(inst);
                        3'b010: expected_wb = ($signed(rs1_val) < $signed(imm_i32(inst))) ? 32'd1 : 32'd0;
                        3'b011: expected_wb = ($unsigned(rs1_val) < $unsigned(imm_i32(inst))) ? 32'd1 : 32'd0;
                        3'b100: expected_wb = rs1_val ^ imm_i32(inst);
                        3'b110: expected_wb = rs1_val | imm_i32(inst);
                        3'b111: expected_wb = rs1_val & imm_i32(inst);
                        3'b001: expected_wb = rs1_val << inst[24:20];
                        default: expected_wb = funct7[5] ? sra32(rs1_val, inst[24:20]) : (rs1_val >> inst[24:20]);
                    endcase
                end
                7'b0110011: begin
                    expected_wen = 1'b1;
                    case (funct3)
                        3'b000: expected_wb = funct7[5] ? (rs1_val - rs2_val) : (rs1_val + rs2_val);
                        3'b001: expected_wb = rs1_val << rs2_val[4:0];
                        3'b010: expected_wb = ($signed(rs1_val) < $signed(rs2_val)) ? 32'd1 : 32'd0;
                        3'b011: expected_wb = ($unsigned(rs1_val) < $unsigned(rs2_val)) ? 32'd1 : 32'd0;
                        3'b100: expected_wb = rs1_val ^ rs2_val;
                        3'b101: expected_wb = funct7[5] ? sra32(rs1_val, rs2_val[4:0]) : (rs1_val >> rs2_val[4:0]);
                        3'b110: expected_wb = rs1_val | rs2_val;
                        default: expected_wb = rs1_val & rs2_val;
                    endcase
                end
                7'b0000011: begin
                    expected_wen = 1'b1;
                    alu_addr = rs1_val + imm_i32(inst);
                    word_addr = alu_addr[17:2];
                    old_word = model_dmem[word_addr];
                    case (funct3)
                        3'b000: expected_wb = signext_byte(word_byte(old_word, alu_addr[1:0]));
                        3'b001: expected_wb = signext_half(word_half(old_word, alu_addr[1]));
                        3'b010: expected_wb = old_word;
                        3'b100: expected_wb = zeroext_byte(word_byte(old_word, alu_addr[1:0]));
                        default: expected_wb = zeroext_half(word_half(old_word, alu_addr[1]));
                    endcase
                end
                7'b0100011: begin
                    alu_addr = rs1_val + imm_s32(inst);
                    word_addr = alu_addr[17:2];
                    old_word = model_dmem[word_addr];
                    new_word = old_word;
                    expected_store = 1'b1;
                    case (funct3)
                        3'b000: begin
                            case (alu_addr[1:0])
                                2'b00: new_word[7:0]   = rs2_val[7:0];
                                2'b01: new_word[15:8]  = rs2_val[7:0];
                                2'b10: new_word[23:16] = rs2_val[7:0];
                                default: new_word[31:24] = rs2_val[7:0];
                            endcase
                        end
                        3'b001: begin
                            if (alu_addr[1:0] == 2'b00) begin
                                new_word[15:0] = rs2_val[15:0];
                            end else if (alu_addr[1:0] == 2'b10) begin
                                new_word[31:16] = rs2_val[15:0];
                            end
                        end
                        default: begin
                            if (alu_addr[1:0] == 2'b00) begin
                                new_word = rs2_val;
                            end
                        end
                    endcase
                end
                default: begin
                    fail_step_now("reference model encountered an unsupported instruction. Extend the checker or keep test_mem.hex within the supported subset.");
                end
            endcase

            step_ok = 1'b1;

            if (tb_if_pc !== model_pc) begin
                step_ok = 1'b0;
                $display("[FAIL][STEP] pc mismatch: expected=0x%08h got=0x%08h", model_pc, tb_if_pc);
            end

            if (dut.if_id_inst !== inst) begin
                step_ok = 1'b0;
                $display("[FAIL][STEP] inst mismatch at idx=%0d line=%0d expected=0x%08h got=0x%08h",
                    inst_idx, inst_idx + 1, inst, dut.if_id_inst);
            end

            if (tb_ex_jump !== expected_jump) begin
                step_ok = 1'b0;
                $display("[FAIL][STEP] jump mismatch at idx=%0d line=%0d pc=0x%08h inst=0x%08h %-10s expected=%0b got=%0b",
                    inst_idx, inst_idx + 1, model_pc, inst, inst_name(inst), expected_jump, tb_ex_jump);
            end

            if (expected_jump && (tb_ex_jump_pc !== expected_next_pc)) begin
                step_ok = 1'b0;
                $display("[FAIL][STEP] jump target mismatch at idx=%0d line=%0d pc=0x%08h inst=0x%08h %-10s expected=0x%08h got=0x%08h",
                    inst_idx, inst_idx + 1, model_pc, inst, inst_name(inst), expected_next_pc, tb_ex_jump_pc);
            end

            if (dut.reg_wen !== expected_wen) begin
                step_ok = 1'b0;
                $display("[FAIL][STEP] reg_wen mismatch at idx=%0d line=%0d pc=0x%08h inst=0x%08h %-10s expected=%0b got=%0b",
                    inst_idx, inst_idx + 1, model_pc, inst, inst_name(inst), expected_wen, dut.reg_wen);
            end

            if (expected_wen && (dut.wb_reg_rd_data !== expected_wb)) begin
                step_ok = 1'b0;
                $display("[FAIL][STEP] wb_data mismatch at idx=%0d line=%0d pc=0x%08h inst=0x%08h %-10s expected=0x%08h got=0x%08h",
                    inst_idx, inst_idx + 1, model_pc, inst, inst_name(inst), expected_wb, dut.wb_reg_rd_data);
            end

            if (!step_ok) begin
                fail_step_now("step-by-step checker found the first mismatching instruction.");
            end

            if (expected_wen && (rd != 5'd0)) begin
                model_regs[rd] = expected_wb;
            end
            model_regs[0] = 32'h00000000;
            if (expected_store) begin
                model_dmem[word_addr] = new_word;
            end
            model_pc = expected_next_pc;
            retired_step_count = retired_step_count + 1;
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
    verbose = 1'b0;
    trace_all = 1'b0;
    compact_trace = 1'b0;
    dump_end_trace = 1'b0;
    load_stall_count = 0;
    imem_loaded_words = 0;
    retired_step_count = 0;
    load_store_program = 1'b0;
    expanded_rv32i_program = 1'b0;
    low_dmem_warned = 1'b0;
    saw_terminal_self_loop = 1'b0;
    last_trace_cycle = 0;
    step_check_enable = 1'b1;
    pending_store_check_valid = 1'b0;
    pending_store_issue_cycle = 0;
    pending_store_addr_idx = 0;
    pending_store_pc = 32'h00000000;
    pending_store_inst = 32'h00000013;
    pending_store_addr = 32'h00000000;
    pending_store_ls_ctl = 4'b0000;
    pending_store_byte_off = 2'b00;
    pending_store_rs2_data = 32'h00000000;
    pending_store_expected_wren = 4'b0000;
    pending_store_expected_wdata = 32'h00000000;
    pending_store_prior_word = 32'h00000000;
    pending_store_expected_word = 32'h00000000;

    if ($value$plusargs("cycles=%d", run_cycles)) begin
        $display("[INFO] run_cycles=%0d", run_cycles);
    end
    if ($test$plusargs("quiet")) begin
        verbose = 1'b0;
    end
    if ($test$plusargs("verbose")) begin
        verbose = 1'b1;
    end
    if ($test$plusargs("trace_all")) begin
        trace_all = 1'b1;
        verbose = 1'b1;
    end
    if ($test$plusargs("compact_trace")) begin
        compact_trace = 1'b1;
        verbose = 1'b1;
    end
    if ($test$plusargs("no_step_check")) begin
        step_check_enable = 1'b0;
    end
    if ($test$plusargs("dump_end_trace")) begin
        dump_end_trace = 1'b1;
    end
    if ($test$plusargs("vcd")) begin
        $dumpfile("suat_debug_tb.vcd");
        $dumpvars(0, suat_debug_tb);
    end

    for (i = 0; i < TRACE_DEPTH; i = i + 1) begin
        hist_valid[i] = 1'b0;
    end
    for (i = 0; i < 32; i = i + 1) begin
        model_regs[i] = 32'h00000000;
    end

    #1;
    for (i = 0; i < DMEM_WORDS; i = i + 1) begin
        dut.mem6.sram[i] = 32'h00000000;
        shadow_dmem[i] = 32'h00000000;
        model_dmem[i] = 32'h00000000;
        last_store_valid[i] = 1'b0;
        last_store_cycle[i] = -1;
        last_store_pc[i] = 32'h00000000;
        last_store_inst[i] = 32'h00000013;
        last_store_wren[i] = 4'b0000;
        last_store_wdata[i] = 32'h00000000;
        last_store_after[i] = 32'h00000000;
    end
    model_pc = START_PC;

    begin : detect_imem_words
        reg found_end;
        found_end = 1'b0;
        for (i = 0; i < DMEM_WORDS; i = i + 1) begin
            if (!found_end && has_x32(dut.imem6.sram[i])) begin
                imem_loaded_words = i;
                found_end = 1'b1;
            end
        end
        if (!found_end) begin
            imem_loaded_words = DMEM_WORDS;
        end
    end

    load_store_program =
        (dut.imem6.sram[0] === 32'h40000893) &&
        (dut.imem6.sram[1] === 32'h123450b7) &&
        (dut.imem6.sram[2] === 32'h67808093) &&
        (dut.imem6.sram[3] === 32'h0018a023) &&
        (dut.imem6.sram[10] === 32'h00788223) &&
        (dut.imem6.sram[14] === 32'h0048a503);

    expanded_rv32i_program =
        (imem_loaded_words == 166) &&
        (dut.imem6.sram[0]   === 32'h40000893) &&
        (dut.imem6.sram[3]   === 32'h87654137) &&
        (dut.imem6.sram[67]  === 32'h0018a023) &&
        (dut.imem6.sram[132] === 32'h0080036f) &&
        (dut.imem6.sram[165] === 32'h0000006f);

    $display("[INFO] suat_debug_tb start");
    print_trace_legend();
    $display("[INFO] detected imem_loaded_words=%0d", imem_loaded_words);
    $display("[INFO] IMEM[0..7] = %08h %08h %08h %08h %08h %08h %08h %08h",
        dut.imem6.sram[0], dut.imem6.sram[1], dut.imem6.sram[2], dut.imem6.sram[3],
        dut.imem6.sram[4], dut.imem6.sram[5], dut.imem6.sram[6], dut.imem6.sram[7]);
    $display("[INFO] DMEM[0..7] = %08h %08h %08h %08h %08h %08h %08h %08h",
        dut.mem6.sram[0], dut.mem6.sram[1], dut.mem6.sram[2], dut.mem6.sram[3],
        dut.mem6.sram[4], dut.mem6.sram[5], dut.mem6.sram[6], dut.mem6.sram[7]);

    if (has_x32(dut.imem6.sram[0])) begin
        fail_now("IMEM[0] is X/Z after initialization. Check SUAT_sram $readmemh path and whether test_mem.hex is visible to simulation.");
    end

    if (has_x32(dut.mem6.sram[0])) begin
        fail_now("DMEM[0] is X/Z after initialization. Check SUAT_sram $readmemh path and whether test_mem.hex is visible to simulation.");
    end

    if (load_store_program) begin
        $display("[INFO] recognized default sb/sw/lb/lw debug program. Final scoreboarding is enabled.");
    end else if (expanded_rv32i_program) begin
        $display("[INFO] recognized expanded rv32i coverage program. Final scoreboarding is enabled.");
    end else begin
        $display("[INFO] IMEM does not match a known scored program. Runtime trace will run, final scoreboarding is skipped.");
        step_check_enable = 1'b0;
    end

    if (step_check_enable) begin
        $display("[INFO] step-by-step checker is enabled. Default mode is error-only; use +verbose, +compact_trace, or +trace_all to see traces.");
    end

    repeat (4) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    $display("[INFO] reset released at %0t", $time);

    begin : run_block
        for (i = 0; i < run_cycles; i = i + 1) begin
            @(posedge clk);
            #1;
            if ((imem_loaded_words > 0) &&
                (tb_if_pc == (START_PC + ((imem_loaded_words - 1) << 2))) &&
                (dut.if_id_inst == 32'h0000006f)) begin
                if (saw_terminal_self_loop) begin
                    $display("[INFO] stopping at terminal self-loop at cycle=%0d pc=0x%08h", cycle_count, tb_if_pc);
                    disable run_block;
                end
                saw_terminal_self_loop = 1'b1;
            end else begin
                saw_terminal_self_loop = 1'b0;
            end
            if ((imem_loaded_words > 0) && (dut.if_sram_addr >= imem_loaded_words)) begin
                $display("[INFO] stopping after fetch moved past loaded IMEM at cycle=%0d addr=%0d", cycle_count, dut.if_sram_addr);
                disable run_block;
            end
        end
    end

    if (load_store_program) begin
        final_mem_check();
    end else if (expanded_rv32i_program) begin
        final_expanded_check();
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
        check_pending_store_commit();
        check_store_semantics();
        check_load_semantics();
        check_step_semantics();

        if (verbose) begin
            if (!compact_trace || trace_all) begin
                print_cycle_trace();
                last_trace_cycle = cycle_count;
            end else if (dut.reg_wen ||
                dut.ls_sram_cs ||
                tb_ex_jump ||
                dut.load_stall ||
                cycle_count < 8) begin
                print_skipped_cycles(cycle_count - last_trace_cycle - 1);
                print_cycle_trace();
                last_trace_cycle = cycle_count;
            end
        end
    end
end

endmodule
