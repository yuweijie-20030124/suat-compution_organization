module SUAT_imem #(
// --------------------------------------------------------------------------
// Parameters
// --------------------------------------------------------------------------
  parameter AW = 14
 )
 (
  // Inputs
   input  wire          CLK
  ,input  wire [AW-1:0] ADDR1
  ,input  wire          RDEN1
  ,input  wire [AW-1:0] ADDR2
  ,input  wire [3:0]    WREN2
  ,input  wire [31:0]   WDATA2
  ,input  wire          RDEN2
  // Outputs
  ,output wire [31:0]   RDATA1
  ,output wire [31:0]   RDATA2
  );

// -----------------------------------------------------------------------------
// Constant Declarations
// -----------------------------------------------------------------------------
localparam AWT = ((1<<(AW-0))-1);

  // Memory Array
  reg     [31:0]  sram [AWT:0];

  initial begin
    $readmemh("C:/Users/HXC/Desktop/lab7/yonex.hex", sram);
  end

  // Infer Block RAM - syntax is very specific.
  always@(posedge CLK) begin
    if(WREN2[0]) sram[ADDR2][ 7:0] <= WDATA2[ 7:0];
  end
  always@(posedge CLK) begin
    if(WREN2[1]) sram[ADDR2][15:8] <= WDATA2[15:8];
  end
  always@(posedge CLK) begin
    if(WREN2[2]) sram[ADDR2][23:16] <= WDATA2[23:16];
  end
  always@(posedge CLK) begin
    if(WREN2[3]) sram[ADDR2][31:24] <= WDATA2[31:24];
  end

  assign RDATA1 = RDEN1 ? sram[ADDR1] : 32'b0;
  assign RDATA2 = RDEN2 ? sram[ADDR2] : 32'b0;

endmodule
