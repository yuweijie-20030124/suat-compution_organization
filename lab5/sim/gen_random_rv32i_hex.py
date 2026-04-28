#!/usr/bin/env python3
"""Generate safe random RV32I instruction hex for the supported CPU subset.

The generated stream is executable from PC 0x80000000 with 64KB IRAM/DRAM:
- x1 is reserved as 0x80000000 for data accesses and jalr targets.
- loads/stores only use x1 plus a small non-negative offset.
- directed control-flow cases include non +4 jal/jalr/branch targets.
- random control-flow cases still use fall-through targets for long stable runs.
- the last instruction is a local infinite loop using x31 as rd.
"""

from pathlib import Path
import random


SEED = 0x20260421
COUNT = 200
BASE_REG = 1
BASE_ADDR = 0x80000000
IRAM_SIZE = 64 * 1024
DRAM_SIZE = 64 * 1024


def x(n):
    return f"x{n}"


def sext12(n):
    return n & 0xFFF


def enc_r(funct7, rs2, rs1, funct3, rd):
    return (
        ((funct7 & 0x7F) << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | ((rd & 0x1F) << 7)
        | 0x33
    )


def enc_i(imm, rs1, funct3, rd, opcode):
    return (
        ((imm & 0xFFF) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | ((rd & 0x1F) << 7)
        | (opcode & 0x7F)
    )


def enc_s(imm, rs2, rs1, funct3):
    imm &= 0xFFF
    return (
        (((imm >> 5) & 0x7F) << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | ((imm & 0x1F) << 7)
        | 0x23
    )


def enc_b(imm, rs2, rs1, funct3):
    assert imm % 2 == 0
    imm &= 0x1FFF
    return (
        (((imm >> 12) & 0x1) << 31)
        | (((imm >> 5) & 0x3F) << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | (((imm >> 1) & 0xF) << 8)
        | (((imm >> 11) & 0x1) << 7)
        | 0x63
    )


def enc_u(imm20, rd, opcode):
    return ((imm20 & 0xFFFFF) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)


def enc_j(imm, rd):
    assert imm % 2 == 0
    imm &= 0x1FFFFF
    return (
        (((imm >> 20) & 0x1) << 31)
        | (((imm >> 1) & 0x3FF) << 21)
        | (((imm >> 11) & 0x1) << 20)
        | (((imm >> 12) & 0xFF) << 12)
        | ((rd & 0x1F) << 7)
        | 0x6F
    )


R_OPS = {
    "add": (0x00, 0x0),
    "sub": (0x20, 0x0),
    "sll": (0x00, 0x1),
    "slt": (0x00, 0x2),
    "sltu": (0x00, 0x3),
    "xor": (0x00, 0x4),
    "srl": (0x00, 0x5),
    "sra": (0x20, 0x5),
    "or": (0x00, 0x6),
    "and": (0x00, 0x7),
}

I_OPS = {
    "addi": 0x0,
    "slti": 0x2,
    "sltiu": 0x3,
    "xori": 0x4,
    "ori": 0x6,
    "andi": 0x7,
}

SHIFT_I_OPS = {
    "slli": (0x00, 0x1),
    "srli": (0x00, 0x5),
    "srai": (0x20, 0x5),
}

LOAD_OPS = {
    "lb": 0x0,
    "lw": 0x2,
}

STORE_OPS = {
    "sb": 0x0,
    "sw": 0x2,
}

BRANCH_OPS = {
    "beq": 0x0,
    "bne": 0x1,
    "blt": 0x4,
    "bge": 0x5,
    "bltu": 0x6,
    "bgeu": 0x7,
}

SUPPORTED = [
    "lui",
    "auipc",
    "jal",
    "jalr",
    "sb",
    "sw",
    "lb",
    "lw",
    "beq",
    "bne",
    "blt",
    "bge",
    "bltu",
    "bgeu",
    "add",
    "sub",
    "sll",
    "slt",
    "sltu",
    "xor",
    "srl",
    "sra",
    "or",
    "and",
    "addi",
    "slti",
    "sltiu",
    "xori",
    "ori",
    "andi",
    "slli",
    "srli",
    "srai",
]


def case_addi(rd, rs1, imm):
    return enc_i(imm, rs1, I_OPS["addi"], rd, 0x13), f"addi {x(rd)},{x(rs1)},{imm}"


def case_lb(rd, offset, rs1=BASE_REG):
    return enc_i(offset, rs1, LOAD_OPS["lb"], rd, 0x03), f"lb {x(rd)},{offset}({x(rs1)})"


def case_lw(rd, offset, rs1=BASE_REG):
    return enc_i(offset, rs1, LOAD_OPS["lw"], rd, 0x03), f"lw {x(rd)},{offset}({x(rs1)})"


def case_sb(rs2, offset, rs1=BASE_REG):
    return enc_s(offset, rs2, rs1, STORE_OPS["sb"]), f"sb {x(rs2)},{offset}({x(rs1)})"


def case_beq(rs1, rs2, imm):
    return enc_b(imm, rs2, rs1, BRANCH_OPS["beq"]), f"beq {x(rs1)},{x(rs2)},{imm}"


def case_blt(rs1, rs2, imm):
    return enc_b(imm, rs2, rs1, BRANCH_OPS["blt"]), f"blt {x(rs1)},{x(rs2)},{imm}"


def case_jal(rd, imm):
    return enc_j(imm, rd), f"jal {x(rd)},{imm}"


def case_jalr_abs(rd, target_idx, rs1=BASE_REG):
    imm = target_idx * 4
    if imm >= 2048:
        raise ValueError(f"jalr target index too large for imm12: {target_idx}")
    return enc_i(imm, rs1, 0x0, rd, 0x67), f"jalr {x(rd)},{imm}({x(rs1)})"


def directed_data_cases():
    """Cases that random generation is unlikely to hit with useful data values."""
    cases = [
        # lb must return a non-zero positive byte.
        case_addi(5, 0, 127),
        case_sb(5, 0),
        case_lb(6, 0),
        # lb must sign-extend 0x80 from byte lane 1 to 0xffffff80.
        case_addi(5, 0, -128),
        case_sb(5, 1),
        case_lb(7, 1),
        # lb must sign-extend 0xff from byte lane 2 to 0xffffffff.
        case_addi(5, 0, -1),
        case_sb(5, 2),
        case_lb(8, 2),
        # lb must read byte lane 3 without being confused by the other lanes.
        case_addi(5, 0, 1),
        case_sb(5, 3),
        case_lb(9, 3),
        # The four byte stores above should form one little-endian word.
        case_lw(10, 0),
    ]
    return cases


def directed_control_flow_cases(start_idx):
    """Non +4 control-flow cases to ensure jump/branch paths are exercised."""
    cases = [
        # Taken forward branch with non +4 offset.
        case_addi(2, 0, 1),
        case_addi(3, 0, 1),
        case_beq(2, 3, 12),
        case_addi(15, 0, 0x15),
        case_addi(15, 0, 0x1F),
        case_addi(16, 0, 0x16),
        # Backward branch: taken once, then falls through.
        case_addi(18, 0, 2),
        case_addi(19, 0, 0),
        case_addi(19, 19, 1),
        case_blt(19, 18, -4),
        # Taken jal with non +4 offset.
        case_jal(8, 8),
        case_addi(12, 0, 0x55),
        case_addi(13, 0, 0x66),
    ]

    # Taken jalr with non +4 offset. Target is computed in absolute index space.
    jalr_idx = start_idx + len(cases)
    jalr_target_idx = jalr_idx + 3
    cases.append(case_jalr_abs(10, jalr_target_idx))
    cases.append(case_addi(14, 0, 0x14))
    cases.append(case_addi(14, 0, 0x24))
    cases.append(case_addi(20, 0, 0x20))
    return cases


def rand_reg(rng):
    return rng.randrange(32)


def rand_rd(rng):
    # Mostly write real registers, but keep occasional x0 cases.
    # x1 is reserved as BASE_ADDR for memory and jalr safety.
    if rng.randrange(8) == 0:
        return 0
    return rng.choice([reg for reg in range(2, 32)])


def rand_simm12(rng):
    return rng.randrange(-2048, 2048)


def rand_data_byte_offset(rng):
    return rng.randrange(0, 1024)


def rand_data_word_offset(rng):
    return rng.randrange(0, 1024 // 4) * 4


def make_case(op, rng, pc_offset):
    rd = rand_rd(rng)
    rs1 = rand_reg(rng)
    rs2 = rand_reg(rng)

    if op in R_OPS:
        funct7, funct3 = R_OPS[op]
        word = enc_r(funct7, rs2, rs1, funct3, rd)
        asm = f"{op} {x(rd)},{x(rs1)},{x(rs2)}"
    elif op in I_OPS:
        imm = rand_simm12(rng)
        word = enc_i(imm, rs1, I_OPS[op], rd, 0x13)
        asm = f"{op} {x(rd)},{x(rs1)},{imm}"
    elif op in SHIFT_I_OPS:
        funct7, funct3 = SHIFT_I_OPS[op]
        shamt = rng.randrange(32)
        word = enc_i((funct7 << 5) | shamt, rs1, funct3, rd, 0x13)
        asm = f"{op} {x(rd)},{x(rs1)},{shamt}"
    elif op in LOAD_OPS:
        rs1 = BASE_REG
        imm = rand_data_word_offset(rng) if op == "lw" else rand_data_byte_offset(rng)
        word = enc_i(imm, rs1, LOAD_OPS[op], rd, 0x03)
        asm = f"{op} {x(rd)},{imm}({x(rs1)})"
    elif op in STORE_OPS:
        rs1 = BASE_REG
        rs2 = rng.choice([0] + list(range(2, 32)))
        imm = rand_data_word_offset(rng) if op == "sw" else rand_data_byte_offset(rng)
        word = enc_s(imm, rs2, rs1, STORE_OPS[op])
        asm = f"{op} {x(rs2)},{imm}({x(rs1)})"
    elif op in BRANCH_OPS:
        imm = 4
        word = enc_b(imm, rs2, rs1, BRANCH_OPS[op])
        asm = f"{op} {x(rs1)},{x(rs2)},{imm}"
    elif op == "lui":
        imm20 = rng.randrange(0x100000)
        word = enc_u(imm20, rd, 0x37)
        asm = f"lui {x(rd)},0x{imm20:x}"
    elif op == "auipc":
        imm20 = rng.randrange(0x100000)
        word = enc_u(imm20, rd, 0x17)
        asm = f"auipc {x(rd)},0x{imm20:x}"
    elif op == "jal":
        imm = 4
        word = enc_j(imm, rd)
        asm = f"jal {x(rd)},{imm}"
    elif op == "jalr":
        rs1 = BASE_REG
        imm = pc_offset + 4
        word = enc_i(imm, rs1, 0x0, rd, 0x67)
        asm = f"jalr {x(rd)},{imm}({x(rs1)})"
    else:
        raise ValueError(op)

    return word & 0xFFFFFFFF, asm


def verify_cases(cases):
    pc = BASE_ADDR
    for idx, (word, asm) in enumerate(cases):
        op = asm.split()[0]
        pc_offset = pc - BASE_ADDR
        if not (0 <= pc_offset < IRAM_SIZE):
            raise ValueError(f"PC out of IRAM at idx {idx}: 0x{pc:08x}")

        if op in BRANCH_OPS or op == "jal":
            imm = int(asm.rsplit(",", 1)[1], 0)
            target = pc + imm
            if not (BASE_ADDR <= target < BASE_ADDR + IRAM_SIZE):
                raise ValueError(f"{op} target out of IRAM at idx {idx}: 0x{target:08x}")
        elif op == "jalr":
            imm = int(asm.split(",", 1)[1].split("(", 1)[0], 0)
            target = (BASE_ADDR + imm) & ~1
            if not (BASE_ADDR <= target < BASE_ADDR + IRAM_SIZE):
                raise ValueError(f"jalr target out of IRAM at idx {idx}: 0x{target:08x}")
        elif op in LOAD_OPS or op in STORE_OPS:
            if op in LOAD_OPS:
                off_part = asm.split(",", 1)[1]
            else:
                off_part = asm.split(",", 1)[1]
            imm = int(off_part.split("(", 1)[0], 0)
            addr = BASE_ADDR + imm
            width = 4 if op in ("lw", "sw") else 1
            if not (BASE_ADDR <= addr <= BASE_ADDR + DRAM_SIZE - width):
                raise ValueError(f"{op} address out of DRAM at idx {idx}: 0x{addr:08x}")
            if op in ("lw", "sw") and imm % 4 != 0:
                raise ValueError(f"{op} unaligned at idx {idx}: offset {imm}")

        pc += 4


def main():
    rng = random.Random(SEED)
    directed_data = directed_data_cases()
    directed_ctrl = directed_control_flow_cases(start_idx=1 + len(directed_data))
    directed = directed_data + directed_ctrl
    body_count = COUNT - 2 - len(directed)
    if body_count < 0:
        raise ValueError(f"COUNT={COUNT} is too small for directed cases")
    ops = SUPPORTED * (body_count // len(SUPPORTED))
    while len(ops) < body_count:
        ops.append(rng.choice(SUPPORTED))
    rng.shuffle(ops)

    cases = [(enc_u(BASE_ADDR >> 12, BASE_REG, 0x37), f"lui x{BASE_REG},0x{BASE_ADDR >> 12:x}")]
    cases.extend(directed)
    for op in ops[:body_count]:
        cases.append(make_case(op, rng, pc_offset=len(cases) * 4))
    cases.append((enc_j(0, 31), "jal x31,0"))
    verify_cases(cases)

    out_dir = Path(__file__).resolve().parent
    hex_path = out_dir / "random_rv32i_200.hex"
    ann_path = out_dir / "random_rv32i_200_annotated.txt"

    hex_path.write_text("".join(f"{word:08x}\n" for word, _ in cases), encoding="ascii")

    lines = [
        f"# seed=0x{SEED:x}, count={COUNT}, base=0x{BASE_ADDR:08x}, iram={IRAM_SIZE}, dram={DRAM_SIZE}",
        "# safe constraints: x1 is reserved as 0x80000000; load/store offsets stay inside 64KB DRAM",
        "# directed cases cover lb sign-extension/lanes and non +4 branch/jal/jalr targets",
        "# control-flow targets stay inside 64KB IRAM; final instruction is jal x31,0",
        "# idx  pc          hex       asm",
    ]
    for idx, (word, asm) in enumerate(cases):
        pc = BASE_ADDR + idx * 4
        note = ""
        if idx == len(cases) - 1 and asm == "jal x31,0":
            note = f"  # target=0x{pc:08x}, self-loop"
        lines.append(f"{idx:03d}  0x{pc:08x}  {word:08x}  {asm}{note}")
    ann_path.write_text("\n".join(lines) + "\n", encoding="ascii")

    print(hex_path)
    print(ann_path)


if __name__ == "__main__":
    main()
