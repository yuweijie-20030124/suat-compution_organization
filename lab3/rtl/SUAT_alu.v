`include "define.v"

module SUAT_alu( 
     input  wire [`SUAT_DATA] op1
    ,input  wire [`SUAT_DATA] op2
    ,input  wire [9:0]        alu_op
    ,output wire [`SUAT_DATA] alu_res
    ,output wire [3:0]        cmp_res
);

// Please complete the code
    
    // shangcidedaima
    wire [`SUAT_DATA] adder_alu_res ;
    wire              is_lt         ;
    wire              is_equ;
    wire              is_ge;
    alu_add u_alu_add(
         .a                 (op1            )//<<i<<
        ,.b                 (op2            )//<<i<<
        ,.is_sub            (alu_op[5]      )//<<i<<
        ,.is_unsigned       (alu_op[4]      )//<<i<<
        ,.out               (adder_alu_res  )//>>o>>
        ,.lt                (is_lt          )//>>o>>
        ,.equ               (is_equ         )//>>o>>
        ,.ne                (is_ne          )//>>o>>
        ,.ge                (is_ge          )//>>o>>
    );

    wire [`SUAT_DATA] and_alu_res   ;
    alu_and u_alu_and(
         .a                 (op1            )//<<i<<
        ,.b                 (op2            )//<<i<<
        ,.out               (and_alu_res    )//>>o>>
    );  

    wire [`SUAT_DATA] or_alu_res   ;
    alu_or u_alu_or(
         .a                 (op1            )//<<i<<
        ,.b                 (op2            )//<<i<<
        ,.out               (or_alu_res     )//>>o>>
    );    

    wire [`SUAT_DATA] shifter_alu_res   ;
    alu_shifter u_alu_shifter(
         .data              (op1            )//<<i<<
        ,.shamt             (op2[4:0]       )//<<i<<
        ,.op                (alu_op[1:0]    )//<<i<<
        ,.out               (shifter_alu_res)//>>o>>
    );

    wire [`SUAT_DATA] slt_alu_res   ;
    alu_slt u_alu_slt(
         .lt                 (is_lt          )//<<i<<
        ,.out                (slt_alu_res    )//>>o>>
    );

    wire [`SUAT_DATA] xor_alu_res   ;
    alu_xor u_alu_xor(
         .a                 (op1             )//<<i<<
        ,.b                 (op2             )//<<i<<
        ,.out               (xor_alu_res      )//>>o>>
    );


    //choose which alu_res
    assign alu_res = {32{alu_op[2]}} & shifter_alu_res  |
                     {32{alu_op[3]}} & adder_alu_res    |
                     {32{alu_op[6]}} & and_alu_res      |
                     {32{alu_op[7]}} & or_alu_res       |
                     {32{alu_op[8]}} & xor_alu_res      |
                     {32{alu_op[9]}} & slt_alu_res      ;


    // TODO cmp_res

endmodule
