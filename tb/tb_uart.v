// -----------------------------------------------------------------------------
// tb_uart.v : self-checking loopback testbench for the UART core.
//   Wires uart_tx.tx -> uart_rx.rx and verifies every transmitted byte is
//   received intact. Uses a small CLKS_PER_BIT so simulation is quick.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module tb_uart;
    // 1 MHz "clock", 115200-ish baud -> CLKS_PER_BIT = 8 (small = fast sim).
    localparam integer CLK_FREQ  = 1_000_000;
    localparam integer BAUD_RATE = 125_000;   // 1e6/125e3 = 8 clks/bit

    reg        clk = 1'b0;
    reg        rst_n = 1'b0;
    reg        tx_start = 1'b0;
    reg  [7:0] tx_data = 8'd0;
    wire       serial;         // the shared TX->RX line
    wire       tx_busy;
    wire [7:0] rx_data;
    wire       rx_valid;

    always #500 clk = ~clk;    // 1 MHz -> 1000 ns period

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_tx (
        .clk(clk), .rst_n(rst_n),
        .tx_start(tx_start), .tx_data(tx_data),
        .tx(serial), .tx_busy(tx_busy)
    );

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_rx (
        .clk(clk), .rst_n(rst_n),
        .rx(serial),
        .rx_data(rx_data), .rx_valid(rx_valid)
    );

    integer errors = 0;
    integer i;
    reg [7:0] test_vectors [0:4];

    // Send one byte and wait for it to come back, then check it.
    task send_and_check(input [7:0] b);
        begin
            @(posedge clk);
            tx_data  <= b;
            tx_start <= 1'b1;
            @(posedge clk);
            tx_start <= 1'b0;
            // wait for receiver to strobe a byte
            wait (rx_valid == 1'b1);
            @(posedge clk);
            if (rx_data === b)
                $display("  PASS  sent=0x%02x recv=0x%02x", b, rx_data);
            else begin
                $display("  FAIL  sent=0x%02x recv=0x%02x", b, rx_data);
                errors = errors + 1;
            end
            // let the line settle back to idle before the next frame
            wait (tx_busy == 1'b0);
            repeat (4) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("uart.vcd");
        $dumpvars(0, tb_uart);

        test_vectors[0] = 8'h55;  // 0101_0101
        test_vectors[1] = 8'hAA;  // 1010_1010
        test_vectors[2] = 8'h00;
        test_vectors[3] = 8'hFF;
        test_vectors[4] = 8'h3C;

        // reset
        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("UART loopback test:");
        for (i = 0; i < 5; i = i + 1)
            send_and_check(test_vectors[i]);

        if (errors == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: %0d FAILURE(S)", errors);
        $finish;
    end

    // safety timeout
    initial begin
        #5_000_000;
        $display("RESULT: TIMEOUT");
        $finish;
    end
endmodule

`default_nettype wire
