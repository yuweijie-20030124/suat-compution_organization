`include "define.v"

module SUAT_wbu(
 	 input     wire  [2:0]      	  wbu_op
 	,input     wire  [`SUAT_DATA]     exu_res
 	,input     wire  [`SUAT_DATA]     mem_res
 	,output    wire  [`SUAT_DATA]     wb_data
  	,output    wire                   wb_wen
);

  assign wb_data = {32{wbu_op[1]}} & exu_res | {32{wbu_op[2]}} & mem_res;
  assign wb_wen  = wbu_op[0];

endmodule
