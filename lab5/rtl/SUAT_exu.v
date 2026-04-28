`include "define.v"

module SUAT_exu( 
     input  wire [`SUAT_DATA]   data1
    ,input  wire [`SUAT_DATA]   data2
    ,input  wire [`SUAT_DATA]   data3
    ,input  wire [`SUAT_DATA]   data4
    ,input  wire [17:0]         exu_op
    ,output wire                exu_jump
    ,output wire [`SUAT_PC]     exu_jump_pc
    ,output wire [`SUAT_DATA]   exu_addr
    ,output wire [`SUAT_DATA]   exu_data
);

// ALU
wire [`SUAT_DATA] alu_res;
wire [3:0] cmp_res;

SUAT_alu u_SUAT_alu( 
     .op1           (data1)
    ,.op2           (data2)
    ,.alu_op        (exu_op[9:0])
    ,.alu_res       (alu_res)
    ,.cmp_res       (cmp_res)
);

// branch
wire branch = |(cmp_res & exu_op[16:13]);
assign exu_jump = branch | exu_op[17];

// Address Adder
wire [`SUAT_DATA] addr_res;
assign addr_res = data3 + data4;

assign exu_addr = addr_res;
assign exu_data = alu_res & {32{exu_op[10]}} | addr_res & {32{exu_op[11]}};
assign exu_jump_pc = addr_res & {32{exu_op[12]}};
    
endmodule
