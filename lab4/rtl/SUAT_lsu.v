`include "define.v"

module SUAT_lsu(
     input   wire    [31:0]  addr
    ,input   wire    [31:0]  wdata_i
    ,input   wire    [31:0]  rdata_i
    ,input   wire    [3:0]   lsu_op
    ,output  wire    [3:0]   WREN
    ,output  wire    [31:0]  wdata_o
    ,output  wire    [31:0]  rdata_o
);

wire inst_lb, inst_lw, inst_sb, inst_sw;
assign {inst_lb, inst_lw, inst_sb, inst_sw} = lsu_op;

//--------------------------------------------load-----------------------------------------------//

wire [31:0] shift_rdata;
right_shifter u_right_shifter(
    .data       (rdata_i),
    .shamt      (addr[1:0]),
    .out        (shift_rdata)
);

assign rdata_o = {32{inst_lw}} & rdata_i | 
    {32{inst_lb}} & {{24{shift_rdata[7]}},shift_rdata[7:0]};

//-------------------------------------------store---------------------------------------------------//

wire byte_at_00 = inst_sb & (~addr[1]) & (~addr[0]);
wire byte_at_01 = inst_sb & (~addr[1]) &   addr[0];
wire byte_at_10 = inst_sb &   addr[1]  & (~addr[0]);
wire byte_at_11 = inst_sb &   addr[1]  &   addr[0];
wire word_at_00 = inst_sw & (~addr[1]) & (~addr[0]);    

assign WREN[0] = word_at_00 | byte_at_00;
assign WREN[1] = word_at_00 | byte_at_01;
assign WREN[2] = word_at_00 | byte_at_10;
assign WREN[3] = word_at_00 | byte_at_11;

left_shifter u_left_shifter(
    .data       (wdata_i),
    .shamt      (addr[1:0]),
    .out        (wdata_o)
);

endmodule

/* verilator lint_off DECLFILENAME */
module left_shifter (
    input   wire    [31:0]  data,
    input   wire    [1:0]   shamt,
    output  wire    [31:0]  out
);

genvar i;

wire [31:0] l8;
generate
    for (i = 0; i < 32; i = i + 1) begin:inst_l8
        if (i < 8)
            assign l8[i] = shamt[0] ? 1'b0 : data[i];
        else
            assign l8[i] = shamt[0] ? data[i-8] : data[i];
    end
endgenerate

wire [31:0] l16;
generate
    for (i = 0; i < 32; i = i + 1) begin:inst_l16
        if (i < 16)
            assign l16[i] = shamt[1] ? 1'b0 : l8[i];
        else
            assign l16[i] = shamt[1] ? l8[i-16] : l8[i];
    end
endgenerate

assign out = l16;

endmodule

module right_shifter (
    input   wire    [31:0]  data,
    input   wire    [1:0]   shamt,
    output  wire    [31:0]  out
);

genvar i;

wire [31:0] r8;
generate
    for (i = 0; i < 32; i = i + 1) begin:inst_r8
        if (i < 24)
            assign r8[i] = shamt[0] ? data[i+8] : data[i];
        else
            assign r8[i] = shamt[0] ? 1'b0 : data[i];
    end
endgenerate

wire [31:0] r16;
generate
    for (i = 0; i < 32; i = i + 1) begin:inst_r16
        if (i < 16)
            assign r16[i] = shamt[1] ? r8[i+16] : r8[i];
        else
            assign r16[i] = shamt[1] ? 1'b0 : r8[i];
    end
endgenerate

assign out = r16;
/* verilator lint_on  DECLFILENAME */
endmodule

