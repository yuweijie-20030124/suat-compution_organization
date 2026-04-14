`include "define.v"

module SUAT_wbu(
 	 input     wire  [2:0]      	  wb_ctl
 	,input     wire  [`SUAT_DATA]     exu_res
 	,input     wire  [`SUAT_DATA]     lsu_res
 	,output    wire  [`SUAT_DATA]     wb_data
  	,output    wire                   wb_wen
);

  assign wb_data = {32{wb_ctl[1]}} & exu_res | {32{wb_ctl[2]}} & lsu_res;
  assign wb_wen  = wb_ctl[0];

endmodule
