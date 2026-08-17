`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/29/2026 08:09:13 PM
// Design Name: 
// Module Name: sbus_rx_chain_TB
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


module sbus_rx_chain_TB();
 
    localparam int CLK_FREQ_HZ = 100_000;
    localparam int FAILSAFE_TIMEOUT_MS = 1;
    localparam int FAILSAFE_TIMEOUT_TICKS = (CLK_FREQ_HZ / 1000) * FAILSAFE_TIMEOUT_MS;
    localparam int FAILSAFE_RECOVERY_FRAMES = 3;
 
    localparam logic [7:0] SBUS_START_BYTE = 8'h0F;
    localparam logic [7:0] SBUS_END_BYTE = 8'h00;
 
    logic clk;
    logic reset;
    logic [7:0] uart_rx_data;
    logic uart_rx_frame_ready;
    logic uart_rx_parity_err;
    logic uart_rx_frame_err;
    logic [16*11-1:0] pwm_us_channels;
    logic failsafe_active;
    logic sbus_digital_ch17;
    logic sbus_digital_ch18;
 
    int error_count;
    int test_count;
 
    sbus_rx_chain #(
        .NUM_CHANNELS(16),
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .FAILSAFE_TIMEOUT_MS(FAILSAFE_TIMEOUT_MS),
        .FAILSAFE_RECOVERY_FRAMES(FAILSAFE_RECOVERY_FRAMES)
    ) uut (
        .clk(clk),
        .reset(reset),
        .uart_rx_data(uart_rx_data),
        .uart_rx_frame_ready(uart_rx_frame_ready),
        .uart_rx_parity_err(uart_rx_parity_err),
        .uart_rx_frame_err(uart_rx_frame_err),
        .pwm_us_channels(pwm_us_channels),
        .failsafe_active(failsafe_active),
        .sbus_digital_ch17(sbus_digital_ch17),
        .sbus_digital_ch18(sbus_digital_ch18)
    );
 
    localparam int TRUNC_NUM_CHANNELS = 5;
    logic [TRUNC_NUM_CHANNELS*11-1:0] pwm_us_channels_trunc;
    logic failsafe_active_trunc;
 
    sbus_rx_chain #(
        .NUM_CHANNELS(TRUNC_NUM_CHANNELS),
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .FAILSAFE_TIMEOUT_MS(FAILSAFE_TIMEOUT_MS),
        .FAILSAFE_RECOVERY_FRAMES(FAILSAFE_RECOVERY_FRAMES)
    ) uutTrunc (
        .clk(clk),
        .reset(reset),
        .uart_rx_data(uart_rx_data),
        .uart_rx_frame_ready(uart_rx_frame_ready),
        .uart_rx_parity_err(uart_rx_parity_err),
        .uart_rx_frame_err(uart_rx_frame_err),
        .pwm_us_channels(pwm_us_channels_trunc),
        .failsafe_active(failsafe_active_trunc),
        .sbus_digital_ch17(),
        .sbus_digital_ch18()
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
 
    task automatic send_frame(input logic [175:0] ch_bits, input logic [7:0] flags);
        send_byte(SBUS_START_BYTE);
        for (int i = 0; i < 22; i++) send_byte(ch_bits[i*8 +: 8]);
        send_byte(flags);
        send_byte(SBUS_END_BYTE);
        @(negedge clk);
    endtask
 
    function automatic logic [10:0] expected_pwm(input logic [10:0] raw);
        logic [13:0] m5;
        logic [11:0] ext;
        m5 = raw * 5;
        ext = (m5 >> 3) + 12'd880;
        if (ext > 12'd2000) return 11'd2000;
        else if (ext < 12'd1000) return 11'd1000;
        else return ext[10:0];
    endfunction
 
    task automatic check_pwm_channels(input logic [175:0] ch_bits, input string label);
        for (int i = 0; i < 16; i++) begin
            logic [10:0] expected;
            logic [10:0] actual;
            expected = expected_pwm(ch_bits[i*11 +: 11]);
            actual = pwm_us_channels[i*11 +: 11];
            test_count++;
            if (actual !== expected) begin
                error_count++;
                $display("[ERROR] %s: channel %0d expected=%0d actual=%0d", label, i, expected, actual);
            end
        end
    endtask
 
    task automatic check_pwm_channels_trunc(input logic [175:0] ch_bits, input string label);
        for (int i = 0; i < TRUNC_NUM_CHANNELS; i++) begin
            logic [10:0] expected;
            logic [10:0] actual;
            expected = expected_pwm(ch_bits[i*11 +: 11]);
            actual = pwm_us_channels_trunc[i*11 +: 11];
            test_count++;
            if (actual !== expected) begin
                error_count++;
                $display("[ERROR] %s: truncated channel %0d expected=%0d actual=%0d", label, i, expected, actual);
            end
        end
    endtask
 
    task automatic check_digital_channels(input logic expected_ch17, input logic expected_ch18, input string label);
        test_count++;
        if (sbus_digital_ch17 !== expected_ch17) begin
            error_count++;
            $display("[ERROR] %s: sbus_digital_ch17 expected=%0b actual=%0b", label, expected_ch17, sbus_digital_ch17);
        end
        test_count++;
        if (sbus_digital_ch18 !== expected_ch18) begin
            error_count++;
            $display("[ERROR] %s: sbus_digital_ch18 expected=%0b actual=%0b", label, expected_ch18, sbus_digital_ch18);
        end
    endtask
 
    task automatic check_failsafe(input logic expected, input string label);
        test_count++;
        if (failsafe_active !== expected) begin
            error_count++;
            $display("[ERROR] %s: failsafe_active expected=%0b actual=%0b", label, expected, failsafe_active);
        end
    endtask
 
    task automatic do_reset();
        reset = 1'b1;
        repeat (2) @(negedge clk);
        reset = 1'b0;
        repeat (2) @(negedge clk);
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
            check_pwm_channels(ch_bits, "PWM conversion through the full chain");
            check_failsafe(1'b0, "no failsafe after the first real frame");
        end
 
        begin
            logic [175:0] ch_bits_digital;
            ch_bits_digital = make_channels(500, 10);
 
            send_frame(ch_bits_digital, 8'b0000_0000);
            check_digital_channels(1'b0, 1'b0, "ch17=0 ch18=0");
 
            send_frame(ch_bits_digital, 8'b0000_0001);
            check_digital_channels(1'b1, 1'b0, "ch17=1 ch18=0");
 
            send_frame(ch_bits_digital, 8'b0000_0010);
            check_digital_channels(1'b0, 1'b1, "ch17=0 ch18=1");
 
            send_frame(ch_bits_digital, 8'b0000_0011);
            check_digital_channels(1'b1, 1'b1, "ch17=1 ch18=1");
        end
 
        begin
            logic [175:0] ch_bits;
            ch_bits = make_channels(200, 37);
            send_frame(ch_bits, 8'h00);
            check_pwm_channels(ch_bits, "full uut, unaffected by the truncated instance");
            check_pwm_channels_trunc(ch_bits, "uutTrunc, first 5 channels");
        end
 
        begin
            logic [16*11-1:0] pwm_held;
            pwm_held = pwm_us_channels;
            send_byte(8'hAA);
            send_byte(8'h55);
            send_byte(8'hFF);
            @(negedge clk);
            test_count++;
            if (pwm_us_channels !== pwm_held) begin
                error_count++;
                $display("[ERROR]: pwm_us_channels changed on spurious bytes (no valid frame), expected unchanged");
            end
        end
 
        do_reset();
 
        begin
            logic [175:0] ch_bits_fs;
            ch_bits_fs = make_channels(992, 0);
 
            send_frame(ch_bits_fs, 8'h00);
            check_failsafe(1'b0, "no failsafe after a clean real frame");
 
            repeat (FAILSAFE_TIMEOUT_TICKS + 10) @(negedge clk);
            check_failsafe(1'b1, "failsafe active after missing frames (sbus_frame_valid path)");
 
            send_frame(ch_bits_fs, 8'h00);
            send_frame(ch_bits_fs, 8'h00);
            send_frame(ch_bits_fs, 8'h00);
            check_failsafe(1'b0, "recovered after 3 consecutive frames");
 
            send_frame(ch_bits_fs, 8'b0000_1000);
            check_failsafe(1'b1, "failsafe active on the sbus_failsafe protocol flag (sbus_failsafe path)");
            send_frame(ch_bits_fs, 8'h00);
            check_failsafe(1'b0, "failsafe cleared after clean flags");
 
            send_frame(ch_bits_fs, 8'b0000_0100);
            check_failsafe(1'b1, "failsafe active on the sbus_frame_lost protocol flag (sbus_frame_lost path)");
            send_frame(ch_bits_fs, 8'h00);
            check_failsafe(1'b0, "failsafe cleared after clean flags");
        end
 
        do_reset();
 
        begin
            logic [175:0] ch_bits_gate;
            ch_bits_gate = make_channels(992, 0);
 
            for (int i = 0; i < 3; i++) begin
                send_frame(ch_bits_gate, 8'b0000_1000);
                check_failsafe(1'b0, $sformatf("iteration %0d, failsafe-flagged frame before real link", i));
            end
 
            repeat (FAILSAFE_TIMEOUT_TICKS * 3) @(negedge clk);
            check_failsafe(1'b0, "missing frames before real link, still no trigger");
 
            send_frame(ch_bits_gate, 8'h00);
            check_failsafe(1'b0, "first real frame, gate opens with no false trigger");
        end
 
        begin
            logic [175:0] ch_bits_f;
            ch_bits_f = make_channels(500, 5);
            send_frame(ch_bits_f, 8'h00);
        end
 
        reset = 1'b1;
        repeat (2) @(negedge clk);
        begin
            logic [16*11-1:0] expected_reset;
            expected_reset = '0;
            for (int i = 0; i < 16; i++) begin
                expected_reset[i*11 +: 11] = expected_pwm(11'd0); 
            end
            test_count++;
            if (pwm_us_channels !== expected_reset) begin
                error_count++;
                $display("[ERROR] F1: pwm_us_channels expected=%0h (1000us/channel, raw=0 saturated) after reset, actual=%0h", expected_reset, pwm_us_channels);
            end
        end
        check_failsafe(1'b0, "F1 failsafe_active cleared by reset");
        reset = 1'b0;
        repeat (2) @(negedge clk);
 
        repeat (3) @(negedge clk);
 
        $display("==========================================");
        $display("TEST MARKS: %0d/%0d passed", test_count - error_count, test_count);
        $display("==========================================");
 
        $finish;
    end
 
endmodule