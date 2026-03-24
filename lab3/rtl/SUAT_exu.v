`include "define.v"

module SUAT_exu( 
     input  wire [`SUAT_DATA]   op1
    ,input  wire [`SUAT_DATA]   op2
    ,input  wire [`SUAT_DATA]   op3       //pc_i
    ,input  wire [9:0]          alu_op
    ,output wire                exu_jump
    ,output wire [`SUAT_PC]     exu_jump_pc
    ,output wire [`SUAT_DATA]   exu_res
);

//lihua alu
wire [`SUAT_DATA] alu_res;
SUAT_alu u_SUAT_alu(
     .op1           (op1)
    ,.op2           (op2)
    ,.alu_op        (alu_op[9:0])
    ,.alu_res       (alu_res)
);



//select exu output 
// assign exu_res = 


endmodule
