`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07/26/2026 10:51:56 PM
// Design Name:
// Module Name: uart_rx_TB
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


module uart_rx_TB();

    localparam int CLK_FREQ_HZ = 16_000_000;
    localparam int BAUD_RATE = 1_000_000;
    localparam int DATA_BITS = 8;
    localparam string PARITY_TYPE = "EVEN";
    localparam int STOP_BITS = 1;
    localparam int OVERSAMPLE = 16;
    localparam bit INVERT_LINE = 1'b0;

    localparam real CLK_PERIOD_NS = 1.0e9 / CLK_FREQ_HZ;
    localparam int BIT_CYCLES = CLK_FREQ_HZ / BAUD_RATE;
    localparam real BIT_NS = BIT_CYCLES * CLK_PERIOD_NS;

    logic clk = 0;
    logic reset;
    logic rx_line;
    logic [DATA_BITS-1:0] rx_data;
    logic rx_frame_ready;
    logic rx_parity_err;
    logic rx_frame_err;

    int errors = 0;
    int checks = 0;

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE),
        .DATA_BITS(DATA_BITS),
        .PARITY_TYPE(PARITY_TYPE),
        .STOP_BITS(STOP_BITS),
        .OVERSAMPLE(OVERSAMPLE),
        .INVERT_LINE(INVERT_LINE)
    ) uartReceiver (
        .clk(clk),
        .reset(reset),
        .uart_rx_line(rx_line),
        .uart_rx_data(rx_data),
        .uart_rx_frame_ready(rx_frame_ready),
        .uart_rx_parity_err(rx_parity_err),
        .uart_rx_frame_err(rx_frame_err)
    );

    always #(CLK_PERIOD_NS/2.0) clk = ~clk;

    localparam logic SIG_IDLE = INVERT_LINE ? 1'b0 : 1'b1;

    function automatic logic convert_line(logic logical_bit);
        return INVERT_LINE ? ~logical_bit : logical_bit;
    endfunction

    task automatic send_byte(
        input logic [DATA_BITS-1:0] data,
        input bit bad_parity = 0,
        input bit bad_stop = 0
    );

        logic parity_bit;
        logic calc = ^data;

        rx_line <= convert_line(1'b0); 
        #(BIT_NS);

        for (int i = 0; i < DATA_BITS; i++) begin
            rx_line <= convert_line(data[i]);
            #(BIT_NS);
        end

        if (PARITY_TYPE != "NONE") begin
            parity_bit = (PARITY_TYPE == "EVEN") ? calc : ~calc;
            if (bad_parity) begin
                parity_bit = ~parity_bit;
            end
            rx_line <= convert_line(parity_bit);
            #(BIT_NS);
        end

        for (int s = 0; s < STOP_BITS; s++) begin
            rx_line <= bad_stop ? convert_line(1'b0) : convert_line(1'b1);
            #(BIT_NS);
        end

        rx_line <= SIG_IDLE;
    endtask


    task automatic check_receive(
        input logic [DATA_BITS-1:0] expected_data,
        input bit expect_parity_err,
        input bit expect_frame_err,
        input string tag
    );

        int timeout = 0;
    
        while (!rx_frame_ready) begin
            @(posedge clk);
            timeout++;
            if (timeout > BIT_CYCLES * (DATA_BITS + STOP_BITS + 4)) begin
                $error("[%s] TIMEOUT waiting for rx_frame_ready", tag);
                errors++;
                return;
            end
        end

        checks++;

        if (rx_data !== expected_data) begin
            $error("[%s] rx_data=0x%0h, expected=0x%0h", tag, rx_data, expected_data);
            errors++;
        end
        
        if (rx_parity_err !== expect_parity_err) begin
            $error("[%s] rx_parity_err=%0b, expected=%0b", tag, rx_parity_err, expect_parity_err);
            errors++;
        end
        
        if (rx_frame_err !== expect_frame_err) begin
            $error("[%s] rx_frame_err=%0b, expected=%0b", tag, rx_frame_err, expect_frame_err);
            errors++;
        end
        
        if (rx_parity_err === expect_parity_err && rx_frame_err === expect_frame_err
            && rx_data === expected_data)
            $display("[%s] OK  data=0x%0h  perr=%0b ferr=%0b", tag, rx_data, rx_parity_err, rx_frame_err);

        @(posedge clk);
    endtask

    initial begin

        reset = 1;
        rx_line = SIG_IDLE;
        repeat (5) @(posedge clk);
        reset = 0;
        repeat (5) @(posedge clk);

        fork
            send_byte(8'h55);
            check_receive(8'h55, 0, 0, "0x55"); 
        join
        
        fork 
            send_byte(8'h00);
            check_receive(8'h00, 0, 0, "0x00"); 
        join
        
        fork 
            send_byte(8'hFF); 
            check_receive(8'hFF, 0, 0, "0xFF"); 
        join

        for (int i = 0; i < 20; i++) begin
            automatic logic [7:0] rnd = $urandom_range(0, 255);
            fork
                send_byte(rnd);
                check_receive(rnd, 0, 0, $sformatf("random_%0d", i));
            join
        end

        fork
            send_byte(8'hA5, .bad_parity(1'b1));
            check_receive(8'hA5, 1'b1, 1'b0, "parity_error");
        join

        fork
            send_byte(8'h3C, .bad_stop(1'b1));
            check_receive(8'h3C, 1'b0, 1'b1, "frame_error");
        join

        fork
            begin 
                send_byte(8'h11); 
                send_byte(8'h22); 
            end
            begin
                check_receive(8'h11, 0, 0, "0x11");
                check_receive(8'h22, 0, 0, "0x22");
            end
        join

        repeat (10) @(posedge clk);

        $display("\n**************************************\n");
        $display(" Tests: %0d,  Errors: %0d", checks, errors);
        $display("\n**************************************\n");

        $finish;
    end

    initial begin
        #(BIT_NS * 2000);
        $error("Timeout: Simulation exceeded allowed time.");
        $finish;
    end

endmodule