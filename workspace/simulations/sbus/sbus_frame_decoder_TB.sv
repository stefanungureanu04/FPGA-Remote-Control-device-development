`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/28/2026 05:16:17 PM
// Design Name: 
// Module Name: sbus_frame_decoder_TB
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


module sbus_frame_decoder_TB();
 
    localparam int SBUS_START_BYTE = 8'h0F;
    localparam int SBUS_END_BYTE = 8'h00;
 
    logic clk;
    logic reset;
    logic [7:0] uart_rx_data;
    logic uart_rx_frame_ready;
    logic uart_rx_parity_err;
    logic uart_rx_frame_err;
 
    logic [175:0] sbus_channels;
    logic sbus_digital_ch17;
    logic sbus_digital_ch18;
    logic sbus_frame_lost;
    logic sbus_failsafe;
    logic sbus_frame_valid;
    logic sbus_frame_error;
 
    int error_count;
    int test_count;
 
    sbus_frame_decoder uut (
        .clk(clk),
        .reset(reset),
        .uart_rx_data(uart_rx_data),
        .uart_rx_frame_ready(uart_rx_frame_ready),
        .uart_rx_parity_err(uart_rx_parity_err),
        .uart_rx_frame_err(uart_rx_frame_err),
        .sbus_channels(sbus_channels),
        .sbus_digital_ch17(sbus_digital_ch17),
        .sbus_digital_ch18(sbus_digital_ch18),
        .sbus_frame_lost(sbus_frame_lost),
        .sbus_failsafe(sbus_failsafe),
        .sbus_frame_valid(sbus_frame_valid),
        .sbus_frame_error(sbus_frame_error)
    );
 
    always #5 clk = ~clk;
 
    task automatic send_byte(input logic [7:0] data, input logic frame_err = 1'b0, input logic parity_err = 1'b0);
        @(negedge clk);
        uart_rx_data = data;
        uart_rx_frame_ready = 1'b1;
        uart_rx_frame_err = frame_err;
        uart_rx_parity_err = parity_err;
        @(negedge clk);
        uart_rx_frame_ready = 1'b0;
        uart_rx_frame_err = 1'b0;
        uart_rx_parity_err = 1'b0;
    endtask
 
    function automatic logic [175:0] make_channels(input int start_val, input int step);
        logic [175:0] result;
        result = '0;
        for (int i = 0; i < 16; i++) begin
            result[i*11 +: 11] = 11'(start_val + step * i);
        end
        return result;
    endfunction

    task automatic send_frame(input logic [175:0] ch_bits, input logic [7:0] flags, input int corrupt_byte = -1);
        send_byte(SBUS_START_BYTE[7:0], (corrupt_byte == 0));
        for (int i = 0; i < 22; i++) begin
            send_byte(ch_bits[i*8 +: 8], (corrupt_byte == i + 1));
        end
        send_byte(flags, (corrupt_byte == 23));
        send_byte(SBUS_END_BYTE[7:0], (corrupt_byte == 24));
    endtask

    task automatic check_channels(input logic [175:0] ch_bits, input string label);
        for (int i = 0; i < 16; i++) begin
            logic [10:0] expected;
            logic [10:0] actual;
            expected = ch_bits[i*11 +: 11];
            actual = sbus_channels[i*11 +: 11];
            test_count++;
            if (actual !== expected) begin
                error_count++;
                $display("[ERROR] %s: channel %0d expected=%0d actual=%0d", label, i, expected, actual);
            end
        end
    endtask
 
    task automatic check_flags(input logic exp_ch17, input logic exp_ch18, input logic exp_lost, input logic exp_failsafe, input string label);
        test_count++;
        if (sbus_digital_ch17 !== exp_ch17 || sbus_digital_ch18 !== exp_ch18 || sbus_frame_lost !== exp_lost || sbus_failsafe !== exp_failsafe) begin
            error_count++;
            $display("[ERROR] %s: flags expected(ch17=%0b ch18=%0b lost=%0b fs=%0b) actual(ch17=%0b ch18=%0b lost=%0b fs=%0b)",
                label, exp_ch17, exp_ch18, exp_lost, exp_failsafe, sbus_digital_ch17, sbus_digital_ch18, sbus_frame_lost, sbus_failsafe);
        end
    endtask
 
    task automatic check_valid_pulse(input logic expected, input string label);
        test_count++;
        if (sbus_frame_valid !== expected) begin
            error_count++;
            $display("[ERROR] %s: sbus_frame_valid expected=%0b actual=%0b", label, expected, sbus_frame_valid);
        end
    endtask
 
    task automatic check_error_pulse(input logic expected, input string label);
        test_count++;
        if (sbus_frame_error !== expected) begin
            error_count++;
            $display("[ERROR] %s: sbus_frame_error expected=%0b actual=%0b", label, expected, sbus_frame_error);
        end
    endtask
 
    task automatic send_byte_check_error(input logic [7:0] data, input logic frame_err, input logic parity_err, input logic expected_err, input string label);
        @(negedge clk);
        uart_rx_data = data;
        uart_rx_frame_ready = 1'b1;
        uart_rx_frame_err = frame_err;
        uart_rx_parity_err = parity_err;
        @(negedge clk);
        test_count++;
        if (sbus_frame_error !== expected_err) begin
            error_count++;
            $display("[ERROR] %s: sbus_frame_error expected=%0b actual=%0b", label, expected_err, sbus_frame_error);
        end
        uart_rx_frame_ready = 1'b0;
        uart_rx_frame_err = 1'b0;
        uart_rx_parity_err = 1'b0;
    endtask
 
    initial begin
 
        clk = 1'b0;
        reset = 1'b1;
        uart_rx_data = '0;
        uart_rx_frame_ready = 1'b0;
        uart_rx_parity_err = 1'b0;
        uart_rx_frame_err = 1'b0;
        error_count = 0;
        test_count = 0;
 
        repeat (3) @(negedge clk);
        reset = 1'b0;
        repeat (2) @(negedge clk);
 
        begin
            logic [175:0] ch_bits;
            ch_bits = make_channels(37, 100);
            send_frame(ch_bits, 8'h00);
            check_valid_pulse(1'b1, "test1 valid_pulse");
            check_channels(ch_bits, "test1 distinct values");
            check_flags(1'b0, 1'b0, 1'b0, 1'b0, "test1 flags zero");
        end
 
        begin
            logic [175:0] ch_bits;
            ch_bits = make_channels(2047, 0);
            send_frame(ch_bits, 8'h00);
            check_valid_pulse(1'b1, "test2 valid_pulse");
            check_channels(ch_bits, "test2 maximum");
        end
 
        begin
            logic [175:0] ch_bits;
            ch_bits = make_channels(0, 0);
            send_frame(ch_bits, 8'b0000_1001);
            check_valid_pulse(1'b1, "test3 valid_pulse");
            check_channels(ch_bits, "test3 zero");
            check_flags(1'b1, 1'b0, 1'b0, 1'b1, "test3 flags ch17+failsafe");
        end
 
        begin
            logic [175:0] ch_bits;
            ch_bits = make_channels(0, 1);
            send_frame(ch_bits, 8'b0000_0110);
            check_valid_pulse(1'b1, "test4 valid_pulse");
            check_flags(1'b0, 1'b1, 1'b1, 1'b0, "test4 flags ch18+lost");
        end
 
        begin
            logic [175:0] ch_bits;
            ch_bits = make_channels(200, 1);
            send_byte(8'hAA);
            send_byte(8'h55);
            send_byte(8'hFF);
            check_valid_pulse(1'b0, "test5 no premature pulse");
            send_frame(ch_bits, 8'h00);
            check_valid_pulse(1'b1, "test5 valid after spurious bytes");
            check_channels(ch_bits, "test5 resync on start");
        end
 
        begin
            logic [175:0] ch_bits;
            ch_bits = make_channels(300, 1);
            send_byte(SBUS_START_BYTE[7:0]);
            for (int i = 0; i < 9; i++) send_byte(ch_bits[i*8 +: 8]);
            send_byte_check_error(ch_bits[9*8 +: 8], 1'b1, 1'b0, 1'b1, "test6 frame_error on injected frame_err");
            for (int i = 10; i < 22; i++) send_byte(ch_bits[i*8 +: 8]);
            send_byte(8'h00);
            send_byte(SBUS_END_BYTE[7:0]);
            check_valid_pulse(1'b0, "test6 no valid on corrupted frame");
        end
 
        begin
            logic [175:0] ch_bits;
            ch_bits = make_channels(400, 3);
            send_frame(ch_bits, 8'h00);
            check_valid_pulse(1'b1, "test7 valid after resync");
            check_channels(ch_bits, "test7 values after resync");
        end
 
        begin
            logic [175:0] ch_bits;
            ch_bits = make_channels(505, 1);
            send_byte(SBUS_START_BYTE[7:0]);
            for (int i = 0; i < 22; i++) send_byte(ch_bits[i*8 +: 8]);
            send_byte_check_error(8'h00, 1'b0, 1'b1, 1'b1, "test8 frame_error on injected parity_err");
            send_byte(SBUS_END_BYTE[7:0]);
            check_valid_pulse(1'b0, "test8 no valid on parity_err");
        end
 
        begin
            logic [175:0] ch_bits;
            ch_bits = make_channels(600, 1);
            send_byte(SBUS_START_BYTE[7:0]);
            for (int i = 0; i < 22; i++) send_byte(ch_bits[i*8 +: 8]);
            send_byte(8'h00);
            send_byte(8'hFF);
            check_valid_pulse(1'b0, "test9 no valid on wrong end_byte");
            check_error_pulse(1'b1, "test9 frame_error on wrong end_byte");
        end
 
        begin
            logic [175:0] ch_bits_a;
            logic [175:0] ch_bits_b;
            ch_bits_a = make_channels(700, 1);
            ch_bits_b = make_channels(50, 2);
            send_frame(ch_bits_a, 8'h00);
            check_valid_pulse(1'b1, "test10 first frame valid");
            check_channels(ch_bits_a, "test10 first frame values");
            send_frame(ch_bits_b, 8'h00);
            check_valid_pulse(1'b1, "test10 second frame valid");
            check_channels(ch_bits_b, "test10 second frame values");
        end
 
        repeat (3) @(negedge clk);
 
        $display("==========================================");
        $display("TEST MARKS: %0d/%0d passed", test_count - error_count, test_count);
        $display("==========================================");
 
        $finish;
    end
 
endmodule