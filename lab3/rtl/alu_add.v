module alu_add(
    input  wire [31:0] a,      // 输入a
    input  wire [31:0] b,      // 输入b
    input  wire        is_sub, // 是否做减法
    input  wire        is_unsigned, // 是否为无符号数
    output wire [31:0] out,    // 输出结果
    output wire        lt,     // less than
    output wire        equ,    // equal
    output wire        ne,     // not equal
    output wire        ge      // greater or equal
);

    // Please complete the code
    wire    [31:0]  complement;
    wire cout;
    assign complement = b ^ {32{is_sub}};
    assign {cout, out} = a + complement + is_sub;

    wire msb_xor;
    assign msb_xor = a[31] ^ b[31];     // 对 a 和 b 的最高位进行异或
    assign lt = ~(msb_xor | cout) | (msb_xor & (is_unsigned ^ cout));

    // TODO

endmodule
