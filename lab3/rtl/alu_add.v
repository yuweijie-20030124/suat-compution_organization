module alu_add(
    input  wire [31:0] a,      // 输入a
    input  wire [31:0] b,      // 输入b
    input  wire        is_sub, // 是否做减法
    input  wire        is_unsigned, // 是否为无符号数
    output wire [31:0] out,    // 输出结果
    output wire        lt      // less than
);

// Please complete the code
    wire [31:0] complement;
    assign complement = is_sub ? ~b : b;
    
    wire cin;
    assign cin = is_sub ? 1'b1 : 1'b0;
    
    wire cout;
    assign {cout, out} = a + complement + cin;
    
    wire overflow;
    assign overflow = (a[31] == complement[31]) && (out[31] != a[31]);
    
    assign lt = is_unsigned ? 
                ~cout :                          
                (is_sub ? (overflow ^ out[31]) : 
                         (a[31] != b[31] ? a[31] : out[31])); 

endmodule