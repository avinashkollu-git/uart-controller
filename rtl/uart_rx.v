// -----------------------------------------------------------------------------
// uart_rx.v : UART receiver (8N1)
//   Samples the incoming line at the middle of each bit period.
//   Double-flops the async rx input to guard against metastability.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module uart_rx #(
    parameter integer CLK_FREQ  = 50_000_000,
    parameter integer BAUD_RATE = 115_200
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,          // serial input line
    output reg  [7:0] rx_data,     // received byte (valid when rx_valid pulses)
    output reg        rx_valid     // one-clk pulse when a byte is ready
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam [2:0] IDLE  = 3'd0,
                     START = 3'd1,
                     DATA  = 3'd2,
                     STOP  = 3'd3,
                     DONE  = 3'd4;

    reg [2:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shifter;

    // Two-stage synchronizer for the asynchronous rx line (CDC hygiene).
    reg rx_sync_0, rx_sync_1;
    always @(posedge clk) begin
        if (!rst_n) begin
            rx_sync_0 <= 1'b1;
            rx_sync_1 <= 1'b1;
        end else begin
            rx_sync_0 <= rx;
            rx_sync_1 <= rx_sync_0;
        end
    end
    wire rx_in = rx_sync_1;

    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= IDLE;
            clk_cnt  <= 16'd0;
            bit_idx  <= 3'd0;
            shifter  <= 8'd0;
            rx_data  <= 8'd0;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0;   // default: deassert unless DONE
            case (state)
                IDLE: begin
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (rx_in == 1'b0)   // falling edge => start bit
                        state <= START;
                end

                // Wait to the middle of the start bit and re-check it is still low.
                START: begin
                    if (clk_cnt == (CLKS_PER_BIT / 2) - 1) begin
                        if (rx_in == 1'b0) begin
                            clk_cnt <= 16'd0;
                            state   <= DATA;
                        end else begin
                            state <= IDLE;   // false start (glitch)
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                // Sample each data bit at its centre (a full period apart).
                DATA: begin
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt          <= 16'd0;
                        shifter[bit_idx] <= rx_in;   // LSB first
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 3'd1;
                        end else begin
                            bit_idx <= 3'd0;
                            state   <= STOP;
                        end
                    end
                end

                STOP: begin
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        state   <= DONE;
                    end
                end

                DONE: begin
                    rx_data  <= shifter;
                    rx_valid <= 1'b1;    // one-clk strobe
                    state    <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
