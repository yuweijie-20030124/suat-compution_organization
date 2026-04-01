`include "define.v"

module SUAT_wbu(
 	 input     wire        	          wb_ctl
 	,input     wire  [`SUAT_DATA]     exu_res
 	,output    wire  [`SUAT_DATA]     wb_data
  ,output    wire                   wb_wen
);

  assign wb_data = exu_res;
  assign wb_wen  = wb_ctl;

endmodule
