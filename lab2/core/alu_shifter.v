module alu_shifter (
    input   wire    [31:0]  data,
    input   wire    [4:0]   shamt,
    input   wire    [1:0]   op,
    output  wire    [31:0]  out
);

/*
    00 逻辑左移 logical left
    01 逻辑右移 logical right
    11 算术右移 arithmetical right
*/

wire signal;
assign signal = op[1] ? data[31] : 1'b0;

genvar i;

wire [31:0] l1;
generate
    for (i = 0; i < 32; i = i + 1) begin:inst_l1
        if (i == 0)
            assign l1[i] = shamt[0] ? signal : data[i];
        else
            assign l1[i] = shamt[0] ? data[i-1] : data[i];
    end
endgenerate

wire [31:0] l2;
generate
    for (i = 0; i < 32; i = i + 1) begin:inst_l2
        if (i < 2)
            assign l2[i] = shamt[1] ? signal : l1[i];
        else
            assign l2[i] = shamt[1] ? l1[i-2] : l1[i];
    end
endgenerate

wire [31:0] l4;
generate
    for (i = 0; i < 32; i = i + 1) begin:inst_l4
        if (i < 4)
            assign l4[i] = shamt[2] ? signal : l2[i];
        else
            assign l4[i] = shamt[2] ? l2[i-4] : l2[i];
    end
endgenerate

wire [31:0] l8;
generate
    for (i = 0; i < 32; i = i + 1) begin:inst_l8
        if (i < 8)
            assign l8[i] = shamt[3] ? signal : l4[i];
        else
            assign l8[i] = shamt[3] ? l4[i-8] : l4[i];
    end
endgenerate

wire [31:0] l16;
generate
    for (i = 0; i < 32; i = i + 1) begin:inst_l16
        if (i < 16)
            assign l16[i] = shamt[4] ? signal : l8[i];
        else
            assign l16[i] = shamt[4] ? l8[i-16] : l8[i];
    end
endgenerate

wire [31:0] r1;
generate
    for (i = 0; i < 32; i = i + 1) begin:inst_r1
        if (i < 31)
            assign r1[i] = shamt[0] ? data[i+1] : data[i];
        else
            assign r1[i] = shamt[0] ? signal : data[i];
    end
endgenerate

wire [31:0] r2;
generate
    for (i = 0; i < 32; i = i + 1) begin:inst_r2
        if (i < 30)
            assign r2[i] = shamt[1] ? r1[i+2] : r1[i];
        else
            assign r2[i] = shamt[1] ? signal : r1[i];
    end
endgenerate

wire [31:0] r4;
generate
    for (i = 0; i < 32; i = i + 1) begin:inst_r4
        if (i < 28)
            assign r4[i] = shamt[2] ? r2[i+4] : r2[i];
        else
            assign r4[i] = shamt[2] ? signal : r2[i];
    end
endgenerate

wire [31:0] r8;
generate
    for (i = 0; i < 32; i = i + 1) begin:inst_r8
        if (i < 24)
            assign r8[i] = shamt[3] ? r4[i+8] : r4[i];
        else
            assign r8[i] = shamt[3] ? signal : r4[i];
    end
endgenerate

wire [31:0] r16;
generate
    for (i = 0; i < 32; i = i + 1) begin:inst_r16
        if (i < 16)
            assign r16[i] = shamt[4] ? r8[i+16] : r8[i];
        else
            assign r16[i] = shamt[4] ? signal : r8[i];
    end
endgenerate

assign out = op[0] ? r16 : l16;

endmodule
