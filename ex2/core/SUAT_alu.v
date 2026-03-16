module SUAT_alu( 
    input  wire [`SUAT_DATA] src1,
    input  wire [`SUAT_DATA] src2,
    input  wire [9:0]        alu_op,
    output wire [`SUAT_DATA] alu_res
);

    wire [31:0] add_res, and_res, or_res, xor_res;
    wire [31:0] shifter_res, slt_res;
    wire        is_unsigned, lt;

    // TODO
    alu_add     u_add(.a(src1), .b(src2), .is_sub(), .is_unsigned(), .out(add_res), .lt(lt));
    alu_and     u_and(.a(src1), .b(src2), .out(and_res));
    alu_or      u_or (.a(src1), .b(src2), .out(or_res));
    alu_xor     u_xor(.a(src1), .b(src2), .out(xor_res));
    alu_shifter u_shifter(.data(src1), .shamt(src2[4:0]), .op(), .out(shifter_res));
    alu_slt     u_slt(.lt(lt), .out(slt_res));

    assign alu_res = 32'd0; // TODO

endmodule
