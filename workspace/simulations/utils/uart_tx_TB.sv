`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07/26/2026 10:51:43 PM
// Design Name:
// Module Name: uart_tx_TB
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module uart_tx_TB();

    localparam int CLK_FREQ_HZ = 16_000_000;
    localparam int BAUD_RATE = 1_000_000;
    localparam int DATA_BITS = 8;
    localparam string PARITY_TYPE = "EVEN";
    localparam int STOP_BITS = 1;
    localparam bit INVERT_LINE = 1'b0;

    localparam real CLK_PERIOD_NS = 1.0e9 / CLK_FREQ_HZ;
    localparam int BIT_CYCLES = CLK_FREQ_HZ / BAUD_RATE;
    localparam real BIT_NS = BIT_CYCLES * CLK_PERIOD_NS;

    logic clk = 0;
    logic reset;
    logic [DATA_BITS-1:0] tx_data;
    logic tx_start;
    logic tx_line;
    logic tx_busy;

    int errors = 0;
    int checks = 0;

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE),
        .DATA_BITS(DATA_BITS),
        .PARITY_TYPE(PARITY_TYPE),
        .STOP_BITS(STOP_BITS),
        .INVERT_LINE(INVERT_LINE)
    ) uartTransmitter (
        .clk(clk),
        .reset(reset),
        .uart_tx_data(tx_data),
        .uart_tx_start(tx_start),
        .uart_tx_line(tx_line),
        .uart_tx_busy(tx_busy)
    );

    always #(CLK_PERIOD_NS/2.0) clk = ~clk;

    function automatic logic convert_line(logic logical_bit);
        return INVERT_LINE ? ~logical_bit : logical_bit;
    endfunction

    task automatic start_tx(
        input logic [DATA_BITS-1:0] data
    );
        @(posedge clk);
        while (tx_busy) @(posedge clk);
        tx_data <= data;
        tx_start <= 1'b1;
        @(posedge clk);
        tx_start <= 1'b0;
    endtask
    
    task automatic capture_and_check(
        input logic [DATA_BITS-1:0] expected_data,
        input string tag
    );
        logic [DATA_BITS-1:0] rx_shift;
        logic parity_bit_sampled;
        logic parity_calc;
        logic expected_parity;
        int timeout = 0;

        while (tx_line !== convert_line(1'b0)) begin
            @(posedge clk);
            timeout++;
            if (timeout > BIT_CYCLES * 5) begin
                $error("[%s] TIMEOUT waiting for start bit", tag);
                errors++;
                return;
            end
        end

        checks++;

        if (tx_busy !== 1'b1) begin
            $error("[%s] tx_busy not active at frame start", tag);
            errors++;
        end

        #(BIT_NS/2.0);
        if (tx_line !== convert_line(1'b0)) begin
            $error("[%s] Starting bit not valid at sampling", tag);
            errors++;
        end

        parity_calc = 1'b0;
        for (int i = 0; i < DATA_BITS; i++) begin
            #(BIT_NS);
            rx_shift[i] = (tx_line === convert_line(1'b1));
            parity_calc = parity_calc ^ rx_shift[i];
        end

        if (PARITY_TYPE != "NONE") begin
            #(BIT_NS);
            parity_bit_sampled = (tx_line === convert_line(1'b1));
            expected_parity = (PARITY_TYPE == "EVEN") ? parity_calc : ~parity_calc;
            if (parity_bit_sampled !== expected_parity) begin
                $error("[%s] Parity bit error: received=%0b, expected=%0b", tag, parity_bit_sampled, expected_parity);
                errors++;
            end
        end

        for (int s = 0; s < STOP_BITS; s++) begin
            #(BIT_NS);
            if (tx_line !== convert_line(1'b1)) begin
                $error("[%s] Stop bit %0d error", tag, s);
                errors++;
            end
        end

        if (rx_shift !== expected_data) begin
            $error("[%s] Byte send=0x%0h, byte expected=0x%0h", tag, rx_shift, expected_data);
            errors++;
        end 
        else begin
            $display("[%s] OK  byte=0x%0h", tag, rx_shift);
        end

        #(BIT_NS/2.0);
        if (tx_busy !== 1'b0) begin
            $error("[%s] tx_busy still active after last stop bit", tag);
            errors++;
        end
    endtask

    initial begin

        reset = 1;
        tx_start = 1'b0;
        tx_data = '0;
        repeat (5) @(posedge clk);
        reset = 0;
        repeat (5) @(posedge clk);

        if (tx_line !== convert_line(1'b1)) begin
            $error("Line not in idle");
            errors++;
        end

        fork 
            start_tx(8'h55); 
            capture_and_check(8'h55, "0x55"); 
        join
        
        fork 
            start_tx(8'h00); 
            capture_and_check(8'h00, "0x00");
        join
        
        fork 
            start_tx(8'hFF); 
            capture_and_check(8'hFF, "0xFF");
        join

        for (int i = 0; i < 20; i++) begin
            automatic logic [7:0] rnd = $urandom_range(0, 255);
            fork
                start_tx(rnd);
                capture_and_check(rnd, $sformatf("random_%0d", i));
            join
        end

        repeat (10) @(posedge clk);

        $display("\n**************************************\n");
        $display(" Tests: %0d,  Errors: %0d", checks, errors);
        $display("\n**************************************\n");

        $finish;
    end

    initial begin
        #(BIT_NS * 3000);
        $error("Timeout: Simulation exceeded allowed time.");
        $finish;
    end

endmodule
