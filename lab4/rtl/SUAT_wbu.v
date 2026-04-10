`include "define.v"

module SUAT_wbu(
 	 input     wire        	          wb_ctl
 	,input     wire  [`SUAT_DATA]     exu_res
 	,input     wire  [`SUAT_DATA]     lsu_res
 	,input     wire  [3:0]            ls_ctl
 	,output    wire  [`SUAT_DATA]     wb_data
  ,output    wire                   wb_wen
);

  assign wb_data = ls_ctl[3] ? lsu_res : exu_res;
  assign wb_wen  = wb_ctl;

endmodule
