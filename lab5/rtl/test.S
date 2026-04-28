// ==========================================
// Block 1: 寄存器初始化与 U-Type / I-Type ALU 测试
// ==========================================
lui x1, 0x80008         // 设置数据基址: x1 = 0x80008000
auipc x2, 8192          // 测试 U-type: x2 = PC + (8192 << 12)
addi x3, x0, 15         // 初始化 x3 = 15
addi x4, x1, -20        // I-type 加法带负数立即数
add x5, x3, x4          // R-type 加法
sub x6, x5, x3          // R-type 减法
sll x7, x6, x3          // R-type 逻辑左移 (位移量由 x3 的低 5 位决定)
slt x8, x7, x5          // R-type 有符号比较
sltu x9, x8, x6         // R-type 无符号比较
xor x10, x9, x7         // R-type 异或
srl x11, x10, x3        // R-type 逻辑右移
sra x12, x11, x3        // R-type 算术右移
or x13, x12, x4         // R-type 或运算
and x14, x13, x5        // R-type 与运算
slti x15, x14, 100      // I-type 有符号比较立即数
sltiu x16, x15, 200     // I-type 无符号比较立即数
xori x17, x16, 50       // I-type 异或立即数
ori x18, x17, 25        // I-type 或立即数
andi x19, x18, 12       // I-type 与立即数
slli x20, x19, 4        // I-type 逻辑左移立即数

// ==========================================
// Block 2: 访存指令 (Memory Load/Store) 与移位测试
// 注意：实际仿真时，请确保 x1 指向有效的 RAM 地址空间
// ==========================================
srli x21, x20, 2        // I-type 逻辑右移立即数
srai x22, x21, 1        // I-type 算术右移立即数
sw x22, 0(x1)           // S-type 存字 (Store Word)
sb x21, 4(x1)           // S-type 存字节 (Store Byte)
lw x23, 0(x1)           // I-type 取字 (Load Word)
lb x24, 4(x1)           // I-type 取字节 (Load Byte)
add x25, x23, x24       // 访存后的数据依赖测试 (Load-Use)
sub x26, x25, x22       
and x27, x26, x25
or x28, x27, x24
xor x29, x28, x23
sll x30, x29, x4
srl x31, x30, x5
sra x1, x31, x6         // 覆盖目标寄存器 x1，测试重写逻辑
slt x2, x1, x30
sltu x3, x2, x29
addi x4, x3, 1023       // 测试立即数边界值
slti x5, x4, -512       // 测试负立即数比较
xori x6, x5, -1         // 使用 -1 (全 1) 测试位翻转
ori x7, x6, 255         

// ==========================================
// Block 3: 分支与跳转指令 (Control Flow)
// ==========================================
beq x7, x6, 8           // B-type 相等跳转 (跳过下一条指令)
add x8, x7, x6          // 如果跳转生效，此指令不应提交
bne x8, x7, 12          // B-type 不等跳转
sub x9, x8, x5          
blt x9, x4, -8          // B-type 有符号小于跳转 (向后跳转测试)
sll x10, x9, x3
bge x10, x9, 16         // B-type 有符号大于等于跳转
srl x11, x10, x2
bltu x11, x10, -12      // B-type 无符号小于跳转
sra x12, x11, x1
bgeu x12, x11, 8        // B-type 无符号大于等于跳转
jal x13, 20             // J-type 无条件跳转，保存返回地址到 x13
add x14, x13, x12       
jalr x15, x14, 0        // I-type 寄存器跳转，基于 x14 进行跳转
sub x16, x15, x14
lui x17, 1048575        // 测试 U-type 最大立即数 (0xFFFFF)
auipc x18, 524288       
addi x19, x17, 2047     // 测试 I-type 正最大立即数
addi x20, x18, -2048    // 测试 I-type 负最大立即数
add x21, x19, x20

// ==========================================
// Block 4: 混合算术与逻辑运算压力测试
// ==========================================
sub x22, x21, x19
sll x23, x22, x18
slt x24, x23, x17
sltu x25, x24, x16
xor x26, x25, x15
srl x27, x26, x14
sra x28, x27, x13
or x29, x28, x12
and x30, x29, x11
slti x31, x30, 42
sltiu x1, x31, 84
xori x2, x1, 126
ori x3, x2, 168
andi x4, x3, 210
slli x5, x4, 15
srli x6, x5, 10
srai x7, x6, 5
lui x20, 0x80008       // 设置数据基址 x20 = 0x80008000
addi x20, x20, 8        // x20 = 0x80008008
sw x7, 0(x20)           // S-type 存字 (Store Word)
sb x6, 4(x20)           // S-type 存字节 (Store Byte)
lw x8, 0(x20)           // I-type 取字 (Load Word)

// ==========================================
// Block 5: 访存后紧接控制流
// ==========================================
lb x9, 4(x20)
add x10, x8, x9
sub x11, x10, x8
and x12, x11, x10
or x13, x12, x9
xor x14, x13, x8
sll x15, x14, x7
srl x16, x15, x6
sra x17, x16, x5
slt x18, x17, x15
sltu x19, x18, x14
beq x19, x18, 24
addi x20, x19, 111
bne x20, x19, -16       // 紧凑型向后分支
xori x21, x20, 222
blt x21, x20, 12
ori x22, x21, 333
bge x22, x21, -20
andi x23, x22, 444
bltu x23, x22, 16

// ==========================================
// Block 6: 连续跳转与流水线冲刷 (Pipeline Flush) 测试
// ==========================================
slli x24, x23, 3
bgeu x24, x23, -24
jal x25, -32            // 向后的大跨度 JAL
jalr x26, x25, 16       // 基于刚写入的 x25 立即执行 JALR
lui x27, 65536
auipc x28, 131072
addi x29, x27, 500
addi x30, x28, -500
add x31, x29, x30
sub x1, x31, x29
sll x2, x1, x30
slt x3, x2, x31
sltu x4, x3, x1
xor x5, x4, x2
srl x6, x5, x3
sra x7, x6, x4
or x8, x7, x5
and x9, x8, x6
slti x10, x9, 999
sltiu x11, x10, 1999

// ==========================================
// Block 7: 后续指令与零号寄存器 (x0) 鲁棒性
// ==========================================
xori x12, x11, -100
ori x13, x12, 200
andi x14, x13, 300
slli x15, x14, 8
srli x16, x15, 4
srai x17, x16, 2
lui x27, 0x80008       // 设置数据基址 x27 = 0x80008000
addi x27, x27, 16       // x27 = 0x80008010
sw x17, 0(x27)          // S-type 存字
sb x16, 4(x27)          // S-type 存字节
lw x18, 0(x27)          // I-type 取字
lb x19, 4(x27)          // I-type 取字节
add x20, x18, x19
sub x21, x20, x18
and x22, x21, x20
or x23, x22, x19
xor x24, x23, x18
sll x25, x24, x17
srl x26, x25, x16
sra x27, x26, x15
slt x28, x27, x25
sltu x29, x28, x24

// ==========================================
// Block 8: 结尾与无限循环 (Halt模拟)
// ==========================================
beq x29, x28, 32
addi x30, x29, 77
bne x30, x29, -28
xori x31, x30, 88
blt x31, x30, 20
ori x1, x31, 99
bge x1, x31, -12
andi x2, x1, 11
bltu x2, x1, 8
end:
j end               // 模拟处理器的停机 (Halt)，原位无限循环

