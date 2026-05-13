module mux(
     addr_i
    ,wren_i
    ,rden_i
    ,imem2c_data_i
    ,dmem2c_data_i
    ,uart2c_data_i
    ,c2dmem_wren_o
    ,c2uart_wren_o
    ,c2imem_rden_o
    ,c2dmem_rden_o
    ,c2uart_rden_o
    ,rdata
);

/*
    * UART: 0x1000_0000 ~ 0x1000_0FFF
    * INST SRAM: 0x8000_0000 ~ 0x8000_FFFF
    * DATA SRAM: 0x8001_0000 ~ 0x8001_FFFF
*/

input [15:0] addr_i;
input [3:0]  wren_i;
input        rden_i;
input [31:0] imem2c_data_i;
input [31:0] dmem2c_data_i;
input [31:0] uart2c_data_i;

output wire [3:0]  c2dmem_wren_o;
output wire [3:0]  c2uart_wren_o;
output wire        c2imem_rden_o;
output wire        c2dmem_rden_o;
output wire        c2uart_rden_o;
output wire [31:0] rdata;

// TODO

endmodule
