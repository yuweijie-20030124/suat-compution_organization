module SUAT_sram_dual(
  // Inputs
  input  wire          CLK,
  input  wire [15:0]   I_ADDR,
  input  wire          I_CS,
  input  wire [15:0]   D_ADDR,
  input  wire [31:0]   D_WDATA,
  input  wire [3:0]    D_WREN,
  input  wire          D_CS,

  // Outputs
  output wire [31:0]   I_RDATA,
  output wire [31:0]   D_RDATA
  );

// -----------------------------------------------------------------------------
// Constant Declarations
// -----------------------------------------------------------------------------

  // Memory Array
  reg     [31:0]  BRAM [0:65535];

  integer i;
  integer mem_file;
  reg     mem_loaded;

    initial begin
      mem_loaded = 1'b0;

      for (i = 0; i < 65536; i = i + 1) begin
        BRAM[i] = 32'b0;
      end

      mem_file = $fopen("rtl/test_mem.hex", "r");
      if (mem_file != 0) begin
        $fclose(mem_file);
        $readmemh("rtl/test_mem.hex", BRAM);
        mem_loaded = 1'b1;
        $display("[INFO] SUAT_sram_dual loaded rtl/test_mem.hex");
      end

      if (!mem_loaded) begin
        mem_file = $fopen("../rtl/test_mem.hex", "r");
        if (mem_file != 0) begin
          $fclose(mem_file);
          $readmemh("../rtl/test_mem.hex", BRAM);
          mem_loaded = 1'b1;
          $display("[INFO] SUAT_sram_dual loaded ../rtl/test_mem.hex");
        end
      end

      if (!mem_loaded) begin
        mem_file = $fopen("../../../../../rtl/test_mem.hex", "r");
        if (mem_file != 0) begin
          $fclose(mem_file);
          $readmemh("../../../../../rtl/test_mem.hex", BRAM);
          mem_loaded = 1'b1;
          $display("[INFO] SUAT_sram_dual loaded ../../../../../rtl/test_mem.hex");
        end
      end

      if (!mem_loaded) begin
        mem_file = $fopen("/home/yuweijie/suat-compution_organization/lab4/rtl/test_mem.hex", "r");
        if (mem_file != 0) begin
          $fclose(mem_file);
          $readmemh("/home/yuweijie/suat-compution_organization/lab4/rtl/test_mem.hex", BRAM);
          mem_loaded = 1'b1;
          $display("[INFO] SUAT_sram_dual loaded /home/yuweijie/suat-compution_organization/lab4/rtl/test_mem.hex");
        end
      end

      if (!mem_loaded) begin
        $display("[ERROR] SUAT_sram_dual cannot open test_mem.hex");
        $finish;
      end
    end

  // Internal signals
  reg     [15:0]    i_addr_q1;
  reg     [15:0]    d_addr_q1;
  wire    [3:0]     d_write_enable;
  reg               i_cs_q1;
  reg               d_cs_q1;
  wire    [31:0]    i_read_data;
  wire    [31:0]    d_read_data;

  assign d_write_enable[3:0] = D_WREN[3:0] & {4{D_CS}};

  always @ (posedge CLK)
    begin
    i_cs_q1   <= I_CS;
    d_cs_q1   <= D_CS;
    i_addr_q1 <= I_ADDR;
    d_addr_q1 <= D_ADDR;
    end

  // Infer Block RAM - syntax is very specific.
  always@(posedge CLK) begin
    if(d_write_enable[0]) BRAM[D_ADDR][7:0] <= D_WDATA[7:0];
  end
  always@(posedge CLK) begin
    if(d_write_enable[1]) BRAM[D_ADDR][15:8] <= D_WDATA[15:8];
  end
  always@(posedge CLK) begin
    if(d_write_enable[2]) BRAM[D_ADDR][23:16] <= D_WDATA[23:16];
  end
  always@(posedge CLK) begin
    if(d_write_enable[3]) BRAM[D_ADDR][31:24] <= D_WDATA[31:24];
  end

  assign i_read_data  = BRAM[i_addr_q1];
  assign d_read_data  = BRAM[d_addr_q1];

  assign I_RDATA      = (i_cs_q1) ? i_read_data : {32{1'b0}};
  assign D_RDATA      = (d_cs_q1) ? d_read_data : {32{1'b0}};

endmodule
