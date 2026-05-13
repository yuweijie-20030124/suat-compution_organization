module uart (
   input  wire          CLK
  ,input  wire          RST
  ,input  wire [15:0]   ADDR
  ,input  wire [31:0]   WDATA
  ,input  wire [3:0]    WREN
  ,input  wire          RDEN
  ,output wire [31:0]   RDATA
  ,input  wire          rx_pad
  ,output wire          tx_pad
);

parameter CNT_MAX = 50000000 / 115200;

reg [7:0] tx_data;
reg [7:0] rx_data;

reg [7:0] rx_cnt;
reg [0:0] rx_inv_cnt;
reg [3:0] rx_bit_cnt;

parameter IDLE = 4'b0001, START = 4'b0010, DATA = 4'b0100, STOP = 4'b1000;
reg [3:0] rx_state;
reg [7:0] rx_buffer;
reg       receive;

reg [3:0] tx_state;
reg [7:0] tx_buffer;
reg       transmit;

reg [8:0] tx_cnt;
reg [3:0] tx_bit_cnt;

wire rx = rx_pad;
reg  tx;
assign tx_pad = tx;

wire write_tx_data = (WREN == 4'b0001 && ADDR == 16'h0000);
wire read_tx_data = (RDEN == 1'b1 && ADDR == 16'h0000);
wire read_rx_data = (RDEN == 1'b1 && ADDR == 16'h0004);

always @(posedge CLK) begin
    if (RST) begin
        tx_data <= 0;
    end else if (write_tx_data) begin
        tx_data <= WDATA[7:0];
    end else if (transmit) begin
        tx_data <= 0;
    end
end

always @(posedge CLK) begin
    if (RST) begin
        rx_data <= 0;
    end else if (receive) begin
        rx_data <= rx_buffer;
    end else if (read_rx_data) begin
        rx_data <= 0;
    end
end

always @(posedge CLK) begin
    if (RST) begin
        tx_state <= IDLE;
        transmit <= 0;
        tx_cnt <= 0;
        tx_bit_cnt <= 0;
        tx <= 1;
    end else begin
        case (tx_state)
            // TODO
        endcase
    end
end

always @(posedge CLK) begin
    if (RST) begin
        rx_state <= IDLE;
        rx_cnt <= 0;
        rx_inv_cnt <= 0;
        rx_bit_cnt <= 0;
        receive <= 0;
    end else begin
        case (rx_state)
            IDLE: begin
                if (rx == 0) begin
                    rx_state <= START;
                end
            end
            START: begin
                if (rx_cnt == CNT_MAX / 2 - 1) begin
                    if (rx_inv_cnt == 1) begin
                        rx_state <= DATA;
                    end
                    rx_cnt <= 0;
                    rx_inv_cnt <= rx_inv_cnt + 1;
                end
                else begin
                    rx_cnt <= rx_cnt + 1;
                end
            end
            DATA: begin
                if (rx_cnt == CNT_MAX / 2 - 1) begin
                    if (rx_inv_cnt == 1) begin
                        if (rx_bit_cnt == 7) begin
                            rx_bit_cnt <= 0;
                            rx_state <= STOP;
                        end
                        else begin
                            rx_bit_cnt <= rx_bit_cnt + 1;
                        end
                    end
                    else if (rx_inv_cnt == 0) begin
                        rx_buffer <= {rx, rx_buffer[7:1]}; // Shift in the received bit
                    end
                    rx_cnt <= 0;
                    rx_inv_cnt <= rx_inv_cnt + 1;
                end else begin
                    rx_cnt <= rx_cnt + 1;
                end
            end
            STOP: begin
                receive <= 0;
                if (rx_cnt == CNT_MAX / 2 - 1) begin
                    if (rx_inv_cnt == 1) begin
                        rx_state <= IDLE;
                    end
                    else if (rx_inv_cnt == 0) begin
                        if (rx == 1) begin
                            receive <= 1;
                        end
                    end
                    rx_cnt <= 0;
                    rx_inv_cnt <= rx_inv_cnt + 1;
                end else begin
                    rx_cnt <= rx_cnt + 1;
                end
            end
            default : rx_state <= IDLE;
        endcase
    end
end

assign RDATA = {24'd0, ({8{read_rx_data}} & rx_data) | ({8{read_tx_data}} & tx_data)};

endmodule
