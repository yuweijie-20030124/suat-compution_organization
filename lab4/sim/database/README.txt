lab4 ai.hex difftest database
source_program=../rtl/ai.hex
image_words=171
trace_steps=42
halt_pc=0x800000a4
observable_pc=debug_pc after each retired instruction
files:
  ai_difftest_retired_pc.hex  retired PC of each executed instruction
  ai_difftest_pc.hex          expected debug_pc after each step
  ai_difftest_regs.hex        expected x31..x0 packed state after each step
  ai_difftest_lsu.hex         expected {addr,data,wren} after each step
  ai_difftest_trace.txt       human-readable per-step trace
note:
  if ai.hex changes, regenerate this database before running difftest
