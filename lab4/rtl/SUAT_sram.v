module SUAT_sram #(
// --------------------------------------------------------------------------
// Parameters
// --------------------------------------------------------------------------
  parameter AW = 14
 )
 (
  // Inputs
  input  wire           CLK
  ,input  wire [AW-1:0] ADDR
  ,input  wire [31:0]   WDATA
  ,input  wire [3:0]    WREN
  // Outputs
  ,output wire [31:0]   RDATA
  );

// -----------------------------------------------------------------------------
// Constant Declarations
// -----------------------------------------------------------------------------
localparam AWT = ((1<<(AW-0))-1);

  // Memory Array
  reg     [31:0]  sram [AWT:0];
  integer         init_idx;

  // Infer Block RAM - syntax is very specific.
  always@(posedge CLK) begin
    if(WREN[0]) sram[ADDR][ 7: 0] <= WDATA[ 7: 0];
  end
  always@(posedge CLK) begin
    if(WREN[1]) sram[ADDR][15: 8] <= WDATA[15: 8];
  end
  always@(posedge CLK) begin
    if(WREN[2]) sram[ADDR][23:16] <= WDATA[23:16];
  end
  always@(posedge CLK) begin
    if(WREN[3]) sram[ADDR][31:24] <= WDATA[31:24];
  end

  assign RDATA = sram[ADDR];

endmodule
