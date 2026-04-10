`include "define.v"

module SUAT_exu( 
     input  wire [`SUAT_DATA]   data1
    ,input  wire [`SUAT_DATA]   data2
    ,input  wire [`SUAT_DATA]   data3
    ,input  wire [`SUAT_DATA]   data4
    ,input  wire [17:0]          exu_op
    ,output wire                exu_jump
    ,output wire [`SUAT_PC]     exu_jump_pc
    ,output wire [`SUAT_DATA]   exu_res
);

wire [31:0] alu_res;
wire [3:0]  cmp_res;

SUAT_alu u_SUAT_alu(
     .op1       (data1)
    ,.op2       (data2)
    ,.alu_op    (exu_op[9:0])
    ,.alu_res   (alu_res)
    ,.cmp_res   (cmp_res)
);

wire branch_taken;
assign branch_taken = |(cmp_res & exu_op[15:12]);

assign exu_jump     = exu_op[10] | (exu_op[11] & branch_taken);
assign exu_jump_pc  = data3 + data4;
assign exu_res      = alu_res;
    
endmodule
