`timescale 1ns/1ps

module suat_debug_tb ();

SUAT_top u_SUAT_top(
	 .clk   (clk)		  
	,.rst   (rst)
);

reg clk, rst;

initial begin
    clk = 1'b0;
    rst = 1'b1;
    #200
    rst = 0;
    #100000;
    $stop;
end

always #5 clk = ~clk;

endmodule
