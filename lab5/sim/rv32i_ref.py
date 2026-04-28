#!/usr/bin/env python3
"""RV32I subset reference model and difftest database generator.

Supported instructions match the current RTL subset:
lui, auipc, jal, jalr, sb, sw, lb, lw, all six branches,
add/sub/sll/slt/sltu/xor/srl/sra/or/and,
addi/slti/sltiu/xori/ori/andi/slli/srli/srai.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path


DEFAULT_BASE = 0x80000000
DEFAULT_IRAM_SIZE = 64 * 1024
DEFAULT_DRAM_SIZE = 64 * 1024


def u32(value: int) -> int:
    return value & 0xFFFFFFFF


def sign_extend(value: int, bits: int) -> int:
    sign = 1 << (bits - 1)
    value &= (1 << bits) - 1
    return (value ^ sign) - sign


def s32(value: int) -> int:
    return sign_extend(value, 32)


def reg_name(reg: int) -> str:
    return f"x{reg}"


def read_hex_program(path: Path) -> list[int]:
    words: list[int] = []
    for lineno, raw in enumerate(path.read_text(encoding="ascii").splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if line.startswith("0x"):
            line = line[2:]
        if len(line) > 8:
            raise ValueError(f"{path}:{lineno}: instruction is wider than 32 bits: {raw!r}")
        words.append(int(line, 16) & 0xFFFFFFFF)
    return words


def imm_i(inst: int) -> int:
    return sign_extend(inst >> 20, 12)


def imm_s(inst: int) -> int:
    value = ((inst >> 25) << 5) | ((inst >> 7) & 0x1F)
    return sign_extend(value, 12)


def imm_b(inst: int) -> int:
    value = (
        (((inst >> 31) & 0x1) << 12)
        | (((inst >> 7) & 0x1) << 11)
        | (((inst >> 25) & 0x3F) << 5)
        | (((inst >> 8) & 0xF) << 1)
    )
    return sign_extend(value, 13)


def imm_u(inst: int) -> int:
    return inst & 0xFFFFF000


def imm_j(inst: int) -> int:
    value = (
        (((inst >> 31) & 0x1) << 20)
        | (((inst >> 12) & 0xFF) << 12)
        | (((inst >> 20) & 0x1) << 11)
        | (((inst >> 21) & 0x3FF) << 1)
    )
    return sign_extend(value, 21)


@dataclass(frozen=True)
class DecodedInst:
    name: str
    asm: str
    rd: int = 0
    rs1: int = 0
    rs2: int = 0
    imm: int = 0
    width: int = 0


@dataclass(frozen=True)
class LsuInfo:
    addr: int = 0
    data: int = 0
    wen: int = 0
    ren: int = 0
    width: int = 0

    @property
    def addr16(self) -> int:
        return self.addr & 0xFFFF


@dataclass(frozen=True)
class StepInfo:
    step: int
    retired_pc: int
    next_pc: int
    inst: int
    decoded: DecodedInst
    lsu: LsuInfo
    regs: tuple[int, ...]


def decode(inst: int) -> DecodedInst:
    opcode = inst & 0x7F
    rd = (inst >> 7) & 0x1F
    funct3 = (inst >> 12) & 0x7
    rs1 = (inst >> 15) & 0x1F
    rs2 = (inst >> 20) & 0x1F
    funct7 = (inst >> 25) & 0x7F

    if opcode == 0x37:
        imm = imm_u(inst)
        return DecodedInst("lui", f"lui {reg_name(rd)},0x{imm >> 12:x}", rd=rd, imm=imm)

    if opcode == 0x17:
        imm = imm_u(inst)
        return DecodedInst("auipc", f"auipc {reg_name(rd)},0x{imm >> 12:x}", rd=rd, imm=imm)

    if opcode == 0x6F:
        imm = imm_j(inst)
        return DecodedInst("jal", f"jal {reg_name(rd)},{imm}", rd=rd, imm=imm)

    if opcode == 0x67 and funct3 == 0x0:
        imm = imm_i(inst)
        return DecodedInst(
            "jalr",
            f"jalr {reg_name(rd)},{imm}({reg_name(rs1)})",
            rd=rd,
            rs1=rs1,
            imm=imm,
        )

    if opcode == 0x63:
        names = {
            0x0: "beq",
            0x1: "bne",
            0x4: "blt",
            0x5: "bge",
            0x6: "bltu",
            0x7: "bgeu",
        }
        if funct3 in names:
            name = names[funct3]
            imm = imm_b(inst)
            return DecodedInst(
                name,
                f"{name} {reg_name(rs1)},{reg_name(rs2)},{imm}",
                rs1=rs1,
                rs2=rs2,
                imm=imm,
            )

    if opcode == 0x03:
        names = {0x0: ("lb", 1), 0x2: ("lw", 4)}
        if funct3 in names:
            name, width = names[funct3]
            imm = imm_i(inst)
            return DecodedInst(
                name,
                f"{name} {reg_name(rd)},{imm}({reg_name(rs1)})",
                rd=rd,
                rs1=rs1,
                imm=imm,
                width=width,
            )

    if opcode == 0x23:
        names = {0x0: ("sb", 1), 0x2: ("sw", 4)}
        if funct3 in names:
            name, width = names[funct3]
            imm = imm_s(inst)
            return DecodedInst(
                name,
                f"{name} {reg_name(rs2)},{imm}({reg_name(rs1)})",
                rs1=rs1,
                rs2=rs2,
                imm=imm,
                width=width,
            )

    if opcode == 0x13:
        imm = imm_i(inst)
        names = {
            0x0: "addi",
            0x2: "slti",
            0x3: "sltiu",
            0x4: "xori",
            0x6: "ori",
            0x7: "andi",
        }
        if funct3 in names:
            name = names[funct3]
            return DecodedInst(
                name,
                f"{name} {reg_name(rd)},{reg_name(rs1)},{imm}",
                rd=rd,
                rs1=rs1,
                imm=imm,
            )
        shamt = (inst >> 20) & 0x1F
        if funct3 == 0x1 and funct7 == 0x00:
            return DecodedInst(
                "slli",
                f"slli {reg_name(rd)},{reg_name(rs1)},{shamt}",
                rd=rd,
                rs1=rs1,
                imm=shamt,
            )
        if funct3 == 0x5 and funct7 == 0x00:
            return DecodedInst(
                "srli",
                f"srli {reg_name(rd)},{reg_name(rs1)},{shamt}",
                rd=rd,
                rs1=rs1,
                imm=shamt,
            )
        if funct3 == 0x5 and funct7 == 0x20:
            return DecodedInst(
                "srai",
                f"srai {reg_name(rd)},{reg_name(rs1)},{shamt}",
                rd=rd,
                rs1=rs1,
                imm=shamt,
            )

    if opcode == 0x33:
        names = {
            (0x00, 0x0): "add",
            (0x20, 0x0): "sub",
            (0x00, 0x1): "sll",
            (0x00, 0x2): "slt",
            (0x00, 0x3): "sltu",
            (0x00, 0x4): "xor",
            (0x00, 0x5): "srl",
            (0x20, 0x5): "sra",
            (0x00, 0x6): "or",
            (0x00, 0x7): "and",
        }
        key = (funct7, funct3)
        if key in names:
            name = names[key]
            return DecodedInst(
                name,
                f"{name} {reg_name(rd)},{reg_name(rs1)},{reg_name(rs2)}",
                rd=rd,
                rs1=rs1,
                rs2=rs2,
            )

    raise ValueError(f"unsupported instruction 0x{inst:08x}")


class Rv32Ref:
    def __init__(
        self,
        program: list[int],
        base: int = DEFAULT_BASE,
        iram_size: int = DEFAULT_IRAM_SIZE,
        dram_size: int = DEFAULT_DRAM_SIZE,
    ) -> None:
        self.program = program
        self.base = base
        self.iram_size = iram_size
        self.dram_size = dram_size
        self.pc = base
        self.regs = [0] * 32
        self.dram = bytearray(dram_size)

        if len(program) * 4 > iram_size:
            raise ValueError(
                f"program uses {len(program) * 4} bytes, larger than IRAM {iram_size} bytes"
            )

    def fetch(self) -> int:
        if self.pc % 4 != 0:
            raise ValueError(f"unaligned PC 0x{self.pc:08x}")
        if not (self.base <= self.pc < self.base + self.iram_size):
            raise ValueError(f"PC out of IRAM range: 0x{self.pc:08x}")
        index = (self.pc - self.base) // 4
        if index < 0 or index >= len(self.program):
            raise ValueError(f"PC has no loaded instruction: 0x{self.pc:08x}")
        return self.program[index]

    def check_dram(self, addr: int, width: int) -> int:
        offset = addr - self.base
        if offset < 0 or offset + width > self.dram_size:
            raise ValueError(
                f"DRAM access out of range: addr=0x{addr:08x} width={width}"
            )
        return offset

    def read_u8(self, addr: int) -> int:
        return self.dram[self.check_dram(addr, 1)]

    def read_u32(self, addr: int) -> int:
        if addr & 0x3:
            raise ValueError(f"unaligned lw address: 0x{addr:08x}")
        off = self.check_dram(addr, 4)
        return (
            self.dram[off]
            | (self.dram[off + 1] << 8)
            | (self.dram[off + 2] << 16)
            | (self.dram[off + 3] << 24)
        )

    def write_u8(self, addr: int, value: int) -> None:
        self.dram[self.check_dram(addr, 1)] = value & 0xFF

    def write_u32(self, addr: int, value: int) -> None:
        if addr & 0x3:
            raise ValueError(f"unaligned sw address: 0x{addr:08x}")
        off = self.check_dram(addr, 4)
        value = u32(value)
        self.dram[off] = value & 0xFF
        self.dram[off + 1] = (value >> 8) & 0xFF
        self.dram[off + 2] = (value >> 16) & 0xFF
        self.dram[off + 3] = (value >> 24) & 0xFF

    def set_reg(self, reg: int, value: int) -> None:
        if reg != 0:
            self.regs[reg] = u32(value)
        self.regs[0] = 0

    def step(self, step_no: int) -> StepInfo:
        pc = self.pc
        inst = self.fetch()
        decoded = decode(inst)
        next_pc = u32(pc + 4)
        lsu = LsuInfo()

        rs1v = self.regs[decoded.rs1]
        rs2v = self.regs[decoded.rs2]
        name = decoded.name

        if name == "lui":
            self.set_reg(decoded.rd, decoded.imm)
        elif name == "auipc":
            self.set_reg(decoded.rd, pc + decoded.imm)
        elif name == "jal":
            self.set_reg(decoded.rd, pc + 4)
            next_pc = u32(pc + decoded.imm)
        elif name == "jalr":
            self.set_reg(decoded.rd, pc + 4)
            next_pc = u32((rs1v + decoded.imm) & ~1)
        elif name == "beq":
            if rs1v == rs2v:
                next_pc = u32(pc + decoded.imm)
        elif name == "bne":
            if rs1v != rs2v:
                next_pc = u32(pc + decoded.imm)
        elif name == "blt":
            if s32(rs1v) < s32(rs2v):
                next_pc = u32(pc + decoded.imm)
        elif name == "bge":
            if s32(rs1v) >= s32(rs2v):
                next_pc = u32(pc + decoded.imm)
        elif name == "bltu":
            if rs1v < rs2v:
                next_pc = u32(pc + decoded.imm)
        elif name == "bgeu":
            if rs1v >= rs2v:
                next_pc = u32(pc + decoded.imm)
        elif name == "lb":
            addr = u32(rs1v + decoded.imm)
            value = u32(sign_extend(self.read_u8(addr), 8))
            self.set_reg(decoded.rd, value)
            lsu = LsuInfo(addr=addr, data=value, wen=0, ren=1, width=1)
        elif name == "lw":
            addr = u32(rs1v + decoded.imm)
            value = self.read_u32(addr)
            self.set_reg(decoded.rd, value)
            lsu = LsuInfo(addr=addr, data=value, wen=0, ren=1, width=4)
        elif name == "sb":
            addr = u32(rs1v + decoded.imm)
            lane = addr & 0x3
            self.write_u8(addr, rs2v)
            bus_data = (rs2v & 0xFF) << (8 * lane)
            lsu = LsuInfo(addr=addr, data=bus_data, wen=1 << lane, ren=0, width=1)
        elif name == "sw":
            addr = u32(rs1v + decoded.imm)
            self.write_u32(addr, rs2v)
            lsu = LsuInfo(addr=addr, data=rs2v, wen=0xF, ren=0, width=4)
        elif name == "add":
            self.set_reg(decoded.rd, rs1v + rs2v)
        elif name == "sub":
            self.set_reg(decoded.rd, rs1v - rs2v)
        elif name == "sll":
            self.set_reg(decoded.rd, rs1v << (rs2v & 0x1F))
        elif name == "slt":
            self.set_reg(decoded.rd, 1 if s32(rs1v) < s32(rs2v) else 0)
        elif name == "sltu":
            self.set_reg(decoded.rd, 1 if rs1v < rs2v else 0)
        elif name == "xor":
            self.set_reg(decoded.rd, rs1v ^ rs2v)
        elif name == "srl":
            self.set_reg(decoded.rd, rs1v >> (rs2v & 0x1F))
        elif name == "sra":
            self.set_reg(decoded.rd, s32(rs1v) >> (rs2v & 0x1F))
        elif name == "or":
            self.set_reg(decoded.rd, rs1v | rs2v)
        elif name == "and":
            self.set_reg(decoded.rd, rs1v & rs2v)
        elif name == "addi":
            self.set_reg(decoded.rd, rs1v + decoded.imm)
        elif name == "slti":
            self.set_reg(decoded.rd, 1 if s32(rs1v) < decoded.imm else 0)
        elif name == "sltiu":
            self.set_reg(decoded.rd, 1 if rs1v < u32(decoded.imm) else 0)
        elif name == "xori":
            self.set_reg(decoded.rd, rs1v ^ u32(decoded.imm))
        elif name == "ori":
            self.set_reg(decoded.rd, rs1v | u32(decoded.imm))
        elif name == "andi":
            self.set_reg(decoded.rd, rs1v & u32(decoded.imm))
        elif name == "slli":
            self.set_reg(decoded.rd, rs1v << decoded.imm)
        elif name == "srli":
            self.set_reg(decoded.rd, rs1v >> decoded.imm)
        elif name == "srai":
            self.set_reg(decoded.rd, s32(rs1v) >> decoded.imm)
        else:
            raise ValueError(f"execution not implemented for {name}")

        self.regs[0] = 0
        self.pc = next_pc

        return StepInfo(
            step=step_no,
            retired_pc=pc,
            next_pc=next_pc,
            inst=inst,
            decoded=decoded,
            lsu=lsu,
            regs=tuple(self.regs),
        )


def regs_trace_line(regs: tuple[int, ...]) -> str:
    return " ".join(f"x{i:02d}=0x{regs[i]:08x}" for i in range(32))


def regs_hex_line(regs: tuple[int, ...]) -> str:
    # Existing lab database packs registers as x31..x0.
    return "".join(f"{regs[i]:08x}" for i in range(31, -1, -1))


def run_model(
    hex_path: Path,
    out_dir: Path,
    base: int,
    iram_size: int,
    dram_size: int,
    max_steps: int | None,
) -> list[StepInfo]:
    program = read_hex_program(hex_path)
    steps = len(program) if max_steps is None else max_steps
    cpu = Rv32Ref(program=program, base=base, iram_size=iram_size, dram_size=dram_size)

    trace: list[StepInfo] = []
    for step_no in range(1, steps + 1):
        trace.append(cpu.step(step_no))

    out_dir.mkdir(parents=True, exist_ok=True)
    write_database(trace, out_dir)
    return trace


def write_database(trace: list[StepInfo], out_dir: Path) -> None:
    trace_lines: list[str] = []
    for item in trace:
        lsu = item.lsu
        trace_lines.append(
            " ".join(
                [
                    f"step={item.step:04d}",
                    f"retired_pc=0x{item.retired_pc:08x}",
                    f"debug_pc=0x{item.next_pc:08x}",
                    f"inst=0x{item.inst:08x}",
                    f"asm=\"{item.decoded.asm}\"",
                    f"lsu_addr=0x{lsu.addr:08x}",
                    f"lsu_addr16=0x{lsu.addr16:04x}",
                    f"lsu_data=0x{lsu.data:08x}",
                    f"lsu_wen=0x{lsu.wen:x}",
                    f"lsu_ren=0x{lsu.ren:x}",
                    f"lsu_width={lsu.width}",
                ]
            )
        )
        trace_lines.append(regs_trace_line(item.regs))

    files = {
        "difftest_trace.txt": "\n".join(trace_lines) + "\n",
        "difftest_retired_pc.hex": "".join(f"{item.retired_pc:08x}\n" for item in trace),
        "difftest_pc.hex": "".join(f"{item.next_pc:08x}\n" for item in trace),
        "difftest_inst.hex": "".join(f"{item.inst:08x}\n" for item in trace),
        "difftest_disasm.txt": "".join(
            f"{item.step:04d} 0x{item.retired_pc:08x} 0x{item.inst:08x} {item.decoded.asm}\n"
            for item in trace
        ),
        "difftest_regs.hex": "".join(f"{regs_hex_line(item.regs)}\n" for item in trace),
        # Format: addr16[15:0] + data[31:0] + wen[3:0] + ren[0].
        "difftest_lsu.hex": "".join(
            f"{item.lsu.addr16:04x}{item.lsu.data:08x}{item.lsu.wen:x}{item.lsu.ren:x}\n"
            for item in trace
        ),
    }

    for name, content in files.items():
        (out_dir / name).write_text(content, encoding="ascii")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parents[1]
    parser.add_argument(
        "--hex",
        type=Path,
        default=root / "sim" / "random_rv32i_200.hex",
        help="input instruction hex file, one 32-bit word per line",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=root / "sim" / "database",
        help="output database directory",
    )
    parser.add_argument("--base", type=lambda s: int(s, 0), default=DEFAULT_BASE)
    parser.add_argument("--iram-size", type=lambda s: int(s, 0), default=DEFAULT_IRAM_SIZE)
    parser.add_argument("--dram-size", type=lambda s: int(s, 0), default=DEFAULT_DRAM_SIZE)
    parser.add_argument(
        "--max-steps",
        type=int,
        default=None,
        help="number of retired instructions to simulate; default is instruction count",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    trace = run_model(
        hex_path=args.hex,
        out_dir=args.out_dir,
        base=args.base,
        iram_size=args.iram_size,
        dram_size=args.dram_size,
        max_steps=args.max_steps,
    )
    print(f"wrote {len(trace)} steps to {args.out_dir}")


if __name__ == "__main__":
    main()
