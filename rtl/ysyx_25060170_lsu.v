`include "define.v"

module ysyx_25060170_lsu(
    input wire rst,//
    input wire clk,//
    input wire [`ysyx_25060170_DATA] alu_res,//
    input wire [`ysyx_25060170_DATA] store_data,//
    input wire [3:0] ls_ctl,//
    output wire [`ysyx_25060170_DATA] ls_data_o
);

wire [`ysyx_25060170_DATAADDR] raddr;
wire [`ysyx_25060170_DATAADDR] waddr;

/* verilator lint_off UNUSEDSIGNAL */
reg [7:0] rlen = 8'd4;  // 32-bit: maximum 4 bytes
reg [7:0] wlen;
/* verilator lint_on UNUSEDSIGNAL */

reg [`ysyx_25060170_DATA] data_i;
reg [`ysyx_25060170_DATA] data_o;
wire re;
wire we;
reg [`ysyx_25060170_DATA] load_data;

assign re = (rst == `ysyx_25060170_RSTABLE | ls_ctl == 4'b0000) ? 1'b0 : ls_ctl[3];
assign we = (rst == `ysyx_25060170_RSTABLE | ls_ctl == 4'b0000) ? 1'b0 : ~ls_ctl[3];
assign waddr = (rst == `ysyx_25060170_RSTABLE) ? `ysyx_25060170_ZERO32 : alu_res[31:0];
assign raddr = (rst == `ysyx_25060170_RSTABLE) ? `ysyx_25060170_ZERO32 : alu_res[31:0];

//--------------------------load-----------------------------------------------------------------//
wire [1:0] byte_sel = alu_res[1:0];  // 32-bit: 2 bits for byte selection
wire [1:0] half_sel = alu_res[1:0];  // 32-bit: 2 bits for halfword selection
// word selection not needed for 32-bit as it's always aligned to 4 bytes

reg [7:0] data_byte = data_i[7:0];
reg [15:0] data_half = data_i[15:0];
wire [31:0] data_word = data_i;  // 32-bit word

// always @(*) begin
//     if (rst == `ysyx_25060170_RSTABLE) begin
//         data_byte = 8'b00000000;
//     end else begin
//         case (byte_sel)
//             2'b00: data_byte = data_i[7:0];
//             2'b01: data_byte = data_i[15:8];
//             2'b10: data_byte = data_i[23:16];
//             2'b11: data_byte = data_i[31:24];
//         endcase
//     end
// end

// always @(*) begin
//     if (rst == `ysyx_25060170_RSTABLE) begin
//         data_half = 16'h0;
//     end else begin
//         case (half_sel)
//             2'b00: data_half = data_i[15:0];
//             2'b10: data_half = data_i[31:16];  // Halfword must be aligned to 2 bytes
//             default: data_half = 16'h0;
//         endcase
//     end
// end

always @(*) begin
    if (rst == `ysyx_25060170_RSTABLE) begin
        load_data = `ysyx_25060170_ZERO32;
    end 
    else if (ls_ctl[3] == 1'b1) begin
        case (ls_ctl[2:0])
            3'b001: load_data = {{24{data_byte[7]}}, data_byte};    // LB: sign-extended byte
            3'b010: load_data = {{16{data_half[15]}}, data_half};   // LH: sign-extended halfword
            3'b011: load_data = data_word;                          // LW: word
            3'b101: load_data = {24'b0, data_byte};                 // LBU: zero-extended byte
            3'b110: load_data = {16'b0, data_half};                 // LHU: zero-extended halfword
            default: load_data = `ysyx_25060170_ZERO32;
        endcase
    end else begin
        load_data = `ysyx_25060170_ZERO32;
    end
end

//--------------------------store--------------------------------------------------------------------//
reg [3:0] sb_mask;  // 32-bit: 4 bytes
reg [3:0] sh_mask;  // 32-bit: 2 halfwords
reg [3:0] sw_mask;  // 32-bit: 1 word

always @(*) begin
    if (rst == `ysyx_25060170_RSTABLE) begin
        sb_mask = 4'd0;
    end else begin
        case (byte_sel)
            2'b00: sb_mask = 4'b0001;
            2'b01: sb_mask = 4'b0010;
            2'b10: sb_mask = 4'b0100;
            2'b11: sb_mask = 4'b1000;
        endcase
    end
end

always @(*) begin
    if (rst == `ysyx_25060170_RSTABLE) begin
        sh_mask = 4'd0;
    end else begin
        case (half_sel)
            2'b00: sh_mask = 4'b0011;  // Store halfword at bytes 0-1
            2'b10: sh_mask = 4'b1100;  // Store halfword at bytes 2-3
            default: sh_mask = 4'd0;
        endcase
    end
end

always @(*) begin
    if (rst == `ysyx_25060170_RSTABLE) begin
        sw_mask = 4'b1111;  // Store word always uses all 4 bytes
    end else begin
        sw_mask = 4'b1111;  // Word must be aligned to 4 bytes
    end
end

always @(*) begin
    if (rst == `ysyx_25060170_RSTABLE) begin
        data_o = `ysyx_25060170_ZERO32;
        wlen = 8'd0;
    end else begin
        case (ls_ctl)
            4'b0001: begin  // SB
                data_o = {4{store_data[7:0]}};  // Replicate byte to all positions
                wlen = {{4{1'b0}}, sb_mask}; 
            end
            4'b0010: begin  // SH
                data_o = {2{store_data[15:0]}};  // Replicate halfword to both positions
                wlen = {{4{1'b0}}, sh_mask}; 
            end
            4'b0100: begin  // SW
                data_o = store_data;
                wlen = {{4{1'b0}}, sw_mask};
            end
            default: begin
                data_o = `ysyx_25060170_ZERO32;
                wlen = 8'd0;
            end
        endcase
    end
end

//--------------------------dpi-c--------------------------------------------------------------------//
import "DPI-C" function void pmem_read(input int raddr, output int rdata, input byte rlen);
import "DPI-C" function void pmem_write(input int waddr, input int wdata, input byte wlen);

always @(negedge clk) begin
    if (re) begin
        pmem_read(raddr, data_i, rlen);
    end
    if (we) begin
        pmem_write(waddr, data_o, wlen);
    end
end

//------------------------output----------------------------------------------------------------------//
assign ls_data_o = re ? load_data : `ysyx_25060170_ZERO32;

// Remove unused wire for 32-bit
// wire _unused_ok = &{alu_res[2:0]};

endmodule
