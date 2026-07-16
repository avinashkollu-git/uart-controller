// -----------------------------------------------------------------------------
// uart_tx.v : UART transmitter
//   8 data bits, 1 start bit, 1 stop bit, no parity (8N1).
//   Baud rate = CLK_FREQ / BAUD_RATE clocks per bit.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module uart_tx #(
    parameter integer CLK_FREQ  = 50_000_000,  // system clock in Hz
    parameter integer BAUD_RATE = 115_200
) (
    input  wire       clk,
    input  wire       rst_n,       // active-low synchronous reset
    input  wire       tx_start,    // pulse high for one clk to load tx_data
    input  wire [7:0] tx_data,     // byte to transmit
    output reg        tx,          // serial output line (idles high)
    output reg        tx_busy      // high while a frame is in flight
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // FSM states
    localparam [2:0] IDLE  = 3'd0,
                     START = 3'd1,
                     DATA  = 3'd2,
                     STOP  = 3'd3,
                     DONE  = 3'd4;

    reg [2:0]  state;
    reg [15:0] clk_cnt;    // counts clocks within one bit period
    reg [2:0]  bit_idx;    // which data bit (0..7)
    reg [7:0]  shifter;    // holds the byte being shifted out

    always @(posedge clk) begin
        if (!rst_n) begin
            state   <= IDLE;
            tx      <= 1'b1;
            tx_busy <= 1'b0;
            clk_cnt <= 16'd0;
            bit_idx <= 3'd0;
            shifter <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    tx      <= 1'b1;   // line idles high
                    tx_busy <= 1'b0;
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        shifter <= tx_data;
                        tx_busy <= 1'b1;
                        state   <= START;
                    end
                end

                START: begin
                    tx <= 1'b0;        // start bit
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        state   <= DATA;
                    end
                end

                DATA: begin
                    tx <= shifter[bit_idx];   // LSB first
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 3'd1;
                        end else begin
                            bit_idx <= 3'd0;
                            state   <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx <= 1'b1;        // stop bit
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        state   <= DONE;
                    end
                end

                DONE: begin
                    tx_busy <= 1'b0;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
