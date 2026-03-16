module SUAT_wbu(
 	
 	 input	  wire             	   rst  
 	,input     wire  [1:0]     	   wb_ctl    
 	,input     wire  [`SUAT_DATA]    exu_res      
 	,output    reg   [`SUAT_DATA]    wb_data   
 	
);

always @(*) begin
    if(rst == `SUAT_RSTABLE) begin
       wb_data=`SUAT_ZERO32;
    end
    else begin
      case(wb_ctl)
        2'b10 : 	   begin wb_data = exu_res       ; end
        default : 	begin wb_data = `SUAT_ZERO32  ; end
      endcase
    end
end

endmodule
