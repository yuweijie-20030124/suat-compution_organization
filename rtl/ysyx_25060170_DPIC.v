//专门为了拓展出这么个DPI-C文件 让整个core可综合，避免后续要一直屏蔽掉DPI-C功能 太麻烦了
 `include "define.v"

 module ysyx_25060170_DPIC(
	/* verilator lint_off UNUSEDSIGNAL */
	input  wire	clk,
	input  wire rst,
	/* verilator lint_on UNUSEDSIGNAL */
 	input  wire	[`ysyx_25060170_INST]	pc_i,
	output reg	[`ysyx_25060170_PC]		inst_o,
	//for ftrace
	input wire 	[`ysyx_25060170_REGADDR] rd_addr,
	input wire 	[`ysyx_25060170_IMM]	imm,
	//for difftest
	input  wire	[`ysyx_25060170_REG]	regs0 ,
	input  wire	[`ysyx_25060170_REG]	regs1 ,
	input  wire	[`ysyx_25060170_REG]	regs2 ,
	input  wire	[`ysyx_25060170_REG]	regs3 ,
	input  wire	[`ysyx_25060170_REG]	regs4 ,
	input  wire	[`ysyx_25060170_REG]	regs5 ,
	input  wire	[`ysyx_25060170_REG]	regs6 ,
	input  wire	[`ysyx_25060170_REG]	regs7 ,
	input  wire	[`ysyx_25060170_REG]	regs8 ,
	input  wire	[`ysyx_25060170_REG]	regs9 ,
	input  wire	[`ysyx_25060170_REG]	regs10,
	input  wire	[`ysyx_25060170_REG]	regs11,
	input  wire	[`ysyx_25060170_REG]	regs12,
	input  wire	[`ysyx_25060170_REG]	regs13,
	input  wire	[`ysyx_25060170_REG]	regs14,
	input  wire	[`ysyx_25060170_REG]	regs15,
	input  wire	[`ysyx_25060170_REG]	regs16,
	input  wire	[`ysyx_25060170_REG]	regs17,
	input  wire	[`ysyx_25060170_REG]	regs18,
	input  wire	[`ysyx_25060170_REG]	regs19,
	input  wire	[`ysyx_25060170_REG]	regs20,
	input  wire	[`ysyx_25060170_REG]	regs21,
	input  wire	[`ysyx_25060170_REG]	regs22,
	input  wire	[`ysyx_25060170_REG]	regs23,
	input  wire	[`ysyx_25060170_REG]	regs24,
	input  wire	[`ysyx_25060170_REG]	regs25,
	input  wire	[`ysyx_25060170_REG]	regs26,
	input  wire	[`ysyx_25060170_REG]	regs27,
	input  wire	[`ysyx_25060170_REG]	regs28,
	input  wire	[`ysyx_25060170_REG]	regs29,
	input  wire	[`ysyx_25060170_REG]	regs30,
	input  wire	[`ysyx_25060170_REG]	regs31,
	input  wire	[`ysyx_25060170_REG] 	mstatus,
	input  wire	[`ysyx_25060170_REG] 	mtvec,
	input  wire	[`ysyx_25060170_REG] 	mepc,
	input  wire	[`ysyx_25060170_REG] 	mcause,

	//for magic number
	input  wire                           magic_flag
);

 //--------------------DPI-C----------------------//

import "DPI-C" function void pc_inst_end(input int thepc_data, input int the_inst);

import "DPI-C" function void pmem_read(input int raddr, output int rdata, input byte rlen);

import "DPI-C" function void set_npc_exit(int pc, int halt_ret);

import "DPI-C" function void magic_instruction();

import "DPI-C" function void difftest_dut_csr(
	input int csr_mstatus,
	input int csr_mtvec,
	input int csr_mepc,
	input int csr_mcause
);

import "DPI-C" function void difftest_dut_regs(
 	input int regs0  ,
 	input int regs1  ,
 	input int regs2  ,
 	input int regs3  ,
 	input int regs4  ,
 	input int regs5  ,
 	input int regs6  ,
 	input int regs7  ,
 	input int regs8  ,
 	input int regs9  ,
 	input int regs10 ,
 	input int regs11 ,
 	input int regs12 ,
 	input int regs13 ,
 	input int regs14 ,
 	input int regs15 ,
 	input int regs16 ,
 	input int regs17 ,
 	input int regs18 ,
 	input int regs19 ,
 	input int regs20 ,
 	input int regs21 ,
 	input int regs22 ,
 	input int regs23 ,
 	input int regs24 ,
 	input int regs25 ,
 	input int regs26 ,
 	input int regs27 ,
    input int regs28 ,
 	input int regs29 ,
 	input int regs30 ,
 	input int regs31 
 );


/***********************************use dpic*************************************/

reg [7:0] rlen = 8'd4;
always @(*) begin
    pmem_read(pc_i,inst_o,rlen);
    pc_inst_end(pc_i, inst_o);
end

//  always @(posedge clk) begin
//    if(rst ==`ysyx_25060170_RSTABLE) begin
//      pc_inst_end(`ysyx_25060170_STARTPC, inst_o);
// 	$strobe("rst dpic pc_i = 0x%08x",pc_i);
// 		 pmem_read(pc_i,inst_o,rlen);
//   	$strobe("rst dpic inst_o = 0x%08x",inst_o);
//    end
//    else begin
// 	 pmem_read(pc_i,inst_o,rlen);
//      pc_inst_end(pc_i, inst_o);
// 	// $display("else pc_i = 0x%08x",pc_i);
//   	// $display("else inst_o = 0x%08x",inst_o);
//    end
//  end

/********************************difftest****************************************/
 always@(*)begin
	// pmem_read(pc_i,inst_o,rlen);
 	difftest_dut_regs(
 		regs0  ,
 		regs1  ,
 		regs2  ,
 		regs3  ,
 		regs4  ,
 		regs5  ,
 		regs6  ,
 		regs7  ,
 		regs8  ,
 		regs9  ,
 		regs10,
 		regs11,
 		regs12,
 		regs13,
 		regs14,
 		regs15,
 		regs16,
 		regs17,
 		regs18,
 		regs19,
 		regs20,
 		regs21,
 		regs22,
 		regs23,
 		regs24,
 		regs25,
 		regs26,
 		regs27,
 		regs28,
 		regs29,
 		regs30,
 		regs31
 	);
 end

always@(*) begin
   difftest_dut_csr(
   	mstatus,
   	mtvec,
   	mepc,
   	mcause
   );
end



/********************************FTRACE****************************************/

wire jal;
wire jalr;

assign jal  	= inst_o[6:0]  == 7'b1101111 ? 1 : 0;
assign jalr 	= inst_o[6:0]  == 7'b1100111 ? 1 : 0;

export "DPI-C" task IDU_SEND_CALL_FLAG;

task IDU_SEND_CALL_FLAG(
    output int call_flag,
    output int pc,
    output int dnpc
);

    call_flag = ((rd_addr == 1 && jal == 1 | jalr == 1 ) || (rd_addr == 0 && imm == 0 && jalr == 1)) ? 1 : 0;
    // $display("rd_addr = 0x%08x", rd_addr);
    // $display("jump_en = %d", jump_en);
    // $display("jalr = %d", PCx1);
    // $display("jal = %d", jal);
    // $display("imm = 0x%08x", imm);
    // $display("PCx1 = %d", PCx1);
    dnpc =  pc_i + imm;

endtask

export "DPI-C" task IDU_SEND_RET_FLAG;

task IDU_SEND_RET_FLAG(
    output int ret_flag,
    output int pc
);

    ret_flag = inst_o == 32'h00008067 ? 1 : 0;
    //pc  = pc_i;
    pc = jalr ? {pc_i[31:1],1'b0} : pc_i ;

endtask

// reg [999:0] count;
// reg [999:0] countcount;
// always @(posedge clk) begin
//         if (rst == `ysyx_25060170_RSTABLE) begin
//             count <= 1000'd0;
// 			countcount <= 1000'd0;
//         end else begin
//             count <= count + 1;
//             if (count == 100000) begin
//                 count <= 0;
// 				countcount <= countcount + 1;
//                 $display("output 10000 inst");
// 				$display("has gone %d times",countcount);
//             end
//         end
//     end
/***********************************ebreak*************************************/


always@(*) begin
	  	// $display("pc_i = 0x%08x",pc_i);
  		// $display("inst_o = 0x%08x",inst_o);
	if(inst_o == `EBREAK_TRAP)begin
  		set_npc_exit(pc_i,0);
  	end
	else if(magic_flag) begin
		magic_instruction();
  		//set_npc_exit(pc_i,1);

  	end
  end
 endmodule
