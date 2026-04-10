`include "define.v"

module SUAT_lsu(
    input wire rst,
    input wire [`SUAT_DATA] alu_res,
    input wire [`SUAT_DATA] store_data,
    input wire [3:0] ls_ctl,
    input wire [`SUAT_DATA] bram_rdata,
    output wire [15:0] bram_addr,
    output wire [`SUAT_DATA] bram_wdata,
    output wire [3:0] bram_wren,
    output wire bram_cs,
    output wire [`SUAT_DATA] ls_data_o
);

wire load_en;
wire store_en;
reg [`SUAT_DATA] load_data;
reg [`SUAT_DATA] store_wdata;
reg [3:0] store_mask;
reg [7:0] load_byte;
reg [15:0] load_half;

assign load_en  = (rst != `SUAT_RSTABLE) && (ls_ctl != 4'b0000) &&  ls_ctl[3];
assign store_en = (rst != `SUAT_RSTABLE) && (ls_ctl != 4'b0000) && ~ls_ctl[3];

assign bram_addr  = alu_res[17:2];
assign bram_wdata = store_wdata;
assign bram_wren  = store_en ? store_mask : 4'b0000;
assign bram_cs    = load_en | store_en;

//--------------------------load-----------------------------------------------------------------//
wire [1:0] byte_sel = alu_res[1:0];  

always @(*) begin
    case (byte_sel)
        2'b00: load_byte = bram_rdata[7:0];
        2'b01: load_byte = bram_rdata[15:8];
        2'b10: load_byte = bram_rdata[23:16];
        default: load_byte = bram_rdata[31:24];
    endcase
end

always @(*) begin
    case (byte_sel)
        2'b00: load_half = bram_rdata[15:0];
        2'b10: load_half = bram_rdata[31:16];
        default: load_half = 16'b0;
    endcase
end

always @(*) begin
    if (rst == `SUAT_RSTABLE) begin
        load_data = `SUAT_ZERO32;
    end 
    else if (ls_ctl[3] == 1'b1) begin
        case (ls_ctl[2:0])
            3'b001: load_data = {{24{load_byte[7]}}, load_byte};  
            3'b010: load_data = {{16{load_half[15]}}, load_half}; 
            3'b011: load_data = bram_rdata;                        
            3'b101: load_data = {24'b0, load_byte};               
            3'b110: load_data = {16'b0, load_half};               
            default: load_data = `SUAT_ZERO32;
        endcase
    end else begin
        load_data = `SUAT_ZERO32;
    end
end

//--------------------------store--------------------------------------------------------------------//
always @(*) begin
    if (rst == `SUAT_RSTABLE) begin
        store_wdata = `SUAT_ZERO32;
        store_mask = 4'b0000;
    end else begin
        case (ls_ctl)
            4'b0001: begin  // SB
                store_wdata = {4{store_data[7:0]}};  
                store_mask = 4'b0001 << byte_sel; 
            end
            4'b0010: begin  // SH
                store_wdata = {2{store_data[15:0]}};  
                store_mask = byte_sel[0] ? 4'b0000 : (byte_sel[1] ? 4'b1100 : 4'b0011); 
            end
            4'b0100: begin  // SW
                store_wdata = store_data;
                store_mask = 4'b1111;
            end
            default: begin
                store_wdata = `SUAT_ZERO32;
                store_mask = 4'b0000;
            end
        endcase
    end
end

assign ls_data_o = load_en ? load_data : `SUAT_ZERO32;


endmodule
