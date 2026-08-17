`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/14/2026 04:49:51 AM
// Design Name: 
// Module Name: servo_tty_monitor_TB
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


module servo_tty_monitor_TB();
 
    localparam int NUM_SERVOS = 8;

    localparam int CLK_FREQ_HZ = 8_000_000;
    localparam int PWM_PERIOD_MS = 5;
    localparam int SBUS_BAUD_RATE = 100_000;
    localparam int FAILSAFE_TIMEOUT_MS = 5;
    localparam int FAILSAFE_RECOVERY_FRAMES = 2;
    localparam int PERIOD_TICKS = (CLK_FREQ_HZ / 1000) * PWM_PERIOD_MS;
    localparam int TICKS_PER_US = CLK_FREQ_HZ / 1_000_000;
    localparam int CLK_PERIOD_NS = 1_000_000_000 / CLK_FREQ_HZ;
    localparam int SBUS_BIT_PERIOD_NS = 1_000_000_000 / SBUS_BAUD_RATE;
    localparam int TIMEOUT_TICKS = (CLK_FREQ_HZ / 1000) * FAILSAFE_TIMEOUT_MS;
 
    logic clk;
    logic reset;
    logic sbus_rx_line;
    logic [NUM_SERVOS-1:0] servo_pwm_out;
    logic failsafe_active;
    logic pc_tx_line;
 
    int test_count;
    int error_count;
 
    int servo_width_us [0:NUM_SERVOS-1];
 
    servo_tty_monitor #(
        .NUM_SERVOS(NUM_SERVOS),
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .PWM_PERIOD_MS(PWM_PERIOD_MS),
        .FAILSAFE_TIMEOUT_MS(FAILSAFE_TIMEOUT_MS),
        .FAILSAFE_RECOVERY_FRAMES(FAILSAFE_RECOVERY_FRAMES)
    ) uutServoTtyMonitor (
        .clk(clk),
        .reset(reset),
        .sbus_rx_line(sbus_rx_line),
        .servo_pwm_out(servo_pwm_out),
        .failsafe_active(failsafe_active),
        .pc_tx_line(pc_tx_line)
    );
 
    always begin
        clk = 1'b0;
        #(CLK_PERIOD_NS/2);
        clk = 1'b1;
        #(CLK_PERIOD_NS/2);
    end
 
    genvar gi;
    generate
        for (gi = 0; gi < NUM_SERVOS; gi++) begin : gen_servo_watch
            initial begin
                int cnt;
                forever begin
                    @(posedge servo_pwm_out[gi]);
                    cnt = 0;
                    while (servo_pwm_out[gi] == 1'b1) begin
                        @(posedge clk);
                        cnt++;
                    end
                    servo_width_us[gi] = cnt / TICKS_PER_US;
                end
            end
        end
    endgenerate
 

    task automatic send_uart_byte(input logic [7:0] data);
        logic parity_bit;
        int i;
        begin
            parity_bit = ^data;
 
            sbus_rx_line = 1'b1;
            #(SBUS_BIT_PERIOD_NS);
 
            for (i = 0; i < 8; i++) begin
                sbus_rx_line = ~data[i];
                #(SBUS_BIT_PERIOD_NS);
            end
 
            sbus_rx_line = ~parity_bit;
            #(SBUS_BIT_PERIOD_NS);
 
            sbus_rx_line = 1'b0;
            #(SBUS_BIT_PERIOD_NS);
            sbus_rx_line = 1'b0;
            #(SBUS_BIT_PERIOD_NS);
        end
    endtask
 
    task automatic send_sbus_frame_flags(input logic [175:0] channels_packed, input logic [7:0] flags_byte);
        logic [7:0] payload_buff [0:21];
        int k;
        begin
            for (k = 0; k < 22; k++) begin
                payload_buff[k] = channels_packed[k*8 +: 8];
            end
 
            send_uart_byte(8'h0F);
            for (k = 0; k < 22; k++) begin
                send_uart_byte(payload_buff[k]);
            end
            send_uart_byte(flags_byte);
            send_uart_byte(8'h00);
        end
    endtask
 
    task automatic send_sbus_frame(input logic [175:0] channels_packed);
        begin
            send_sbus_frame_flags(channels_packed, 8'h00);
        end
    endtask
 
    task automatic send_corrupted_sbus_frame(input logic [175:0] channels_packed);
        logic [7:0] payload_buff [0:21];
        int k;
        begin
            for (k = 0; k < 22; k++) begin
                payload_buff[k] = channels_packed[k*8 +: 8];
            end
 
            send_uart_byte(8'h0F);
            for (k = 0; k < 22; k++) begin
                send_uart_byte(payload_buff[k]);
            end
            send_uart_byte(8'h00);
            send_uart_byte(8'hFF);
        end
    endtask
 
    function automatic int expected_us(input int raw);
        int us;
        begin
            us = (raw * 5) / 8 + 880;
            if (us > 2000) us = 2000;
            if (us < 1000) us = 1000;
            expected_us = us;
        end
    endfunction
 
    task automatic check_true(input string label, input bit condition);
        begin
            test_count++;
            if (!condition) begin
                error_count++;
                $display("[ERROR]: %s", label);
            end
        end
    endtask
 
    task automatic check_equal(input string label, input int actual, input int expected, input int tolerance);
        begin
            test_count++;
            if ((actual > expected + tolerance) || (actual < expected - tolerance)) begin
                error_count++;
                $display("[ERROR]: %s - expected %0d, got %0d", label, expected, actual);
            end
        end
    endtask
 
    initial begin
 
        test_count = 0;
        error_count = 0;
 
        reset = 1'b0;
        sbus_rx_line = 1'b0;
        repeat (10) @(posedge clk);
 
        check_true("servo_pwm_out is all-zero during reset", (servo_pwm_out === '0));
 
        reset = 1'b1;
        repeat (5) @(posedge clk);

        check_true("servo_pwm_out has no X/Z bits shortly after reset release", !$isunknown(servo_pwm_out));
        check_true("failsafe_active is defined and 0 with no SBUS frame received", (failsafe_active === 1'b0));
        check_true("pc_tx_line has no X/Z bits shortly after reset release", !$isunknown(pc_tx_line));

        begin
            logic [175:0] channels_packed;
            int raw_values [0:15];
            int c;
 
            raw_values[0] = 200;
            raw_values[1] = 992;
            raw_values[2] = 1800;
            raw_values[3] = 500;
            raw_values[4] = 1500;
            raw_values[5] = 300;
            raw_values[6] = 1700;
            raw_values[7] = 1100;
            for (c = 8; c < 16; c++) begin
                raw_values[c] = 992;
            end
 
            channels_packed = '0;
            for (c = 0; c < 16; c++) begin
                channels_packed[c*11 +: 11] = raw_values[c][10:0];
            end
 
            send_sbus_frame(channels_packed);
 
            repeat (2 * PERIOD_TICKS + 10) @(posedge clk);
 
            check_equal("servo 0 pulse width (raw 200)", servo_width_us[0], expected_us(200), 2);
            check_equal("servo 1 pulse width (raw 992, center)", servo_width_us[1], expected_us(992), 2);
            check_equal("servo 2 pulse width (raw 1800, saturates)", servo_width_us[2], expected_us(1800), 2);
            check_equal("servo 3 pulse width (raw 500)", servo_width_us[3], expected_us(500), 2);
            check_equal("servo 4 pulse width (raw 1500)", servo_width_us[4], expected_us(1500), 2);
            check_equal("servo 5 pulse width (raw 300)", servo_width_us[5], expected_us(300), 2);
            check_equal("servo 6 pulse width (raw 1700)", servo_width_us[6], expected_us(1700), 2);
            check_equal("servo 7 pulse width (raw 1100)", servo_width_us[7], expected_us(1100), 2);
 
            repeat (TIMEOUT_TICKS + 20) @(posedge clk);
            check_true("failsafe_active becomes 1 after losing the link past FAILSAFE_TIMEOUT_MS", (failsafe_active === 1'b1));
 
            begin
                logic [175:0] corrupted_packed;
                int cc;
 
                corrupted_packed = '0;
                for (cc = 0; cc < 16; cc++) begin
                    corrupted_packed[cc*11 +: 11] = 11'd992;
                end
 
                send_corrupted_sbus_frame(corrupted_packed);
                repeat (2 * PERIOD_TICKS + 10) @(posedge clk);
 
                check_equal("servo 0 pulse width unchanged after corrupted frame", servo_width_us[0], expected_us(200), 2);
                check_equal("servo 1 pulse width unchanged after corrupted frame", servo_width_us[1], expected_us(992), 2);
                check_equal("servo 2 pulse width unchanged after corrupted frame", servo_width_us[2], expected_us(1800), 2);
                check_equal("servo 3 pulse width unchanged after corrupted frame", servo_width_us[3], expected_us(500), 2);
                check_equal("servo 4 pulse width unchanged after corrupted frame", servo_width_us[4], expected_us(1500), 2);
                check_equal("servo 5 pulse width unchanged after corrupted frame", servo_width_us[5], expected_us(300), 2);
                check_equal("servo 6 pulse width unchanged after corrupted frame", servo_width_us[6], expected_us(1700), 2);
                check_equal("servo 7 pulse width unchanged after corrupted frame", servo_width_us[7], expected_us(1100), 2);
            end

            begin
                int r;
 
                check_true("failsafe_active still 1 just before recovery frames", (failsafe_active === 1'b1));
 
                for (r = 0; r < FAILSAFE_RECOVERY_FRAMES; r++) begin
                    send_sbus_frame(channels_packed);
                end
                repeat (20) @(posedge clk);
 
                check_true("failsafe_active returns to 0 after FAILSAFE_RECOVERY_FRAMES valid frames", (failsafe_active === 1'b0));
            end
 
            begin
                logic [175:0] flagged_packed;
                int fc;
 
                flagged_packed = '0;
                for (fc = 0; fc < 16; fc++) begin
                    flagged_packed[fc*11 +: 11] = 11'd992;
                end
 
                send_sbus_frame_flags(flagged_packed, 8'h08);
                repeat (20) @(posedge clk);
 
                check_true("failsafe_active becomes 1 immediately on a sbus_failsafe-flagged frame", (failsafe_active === 1'b1));
            end
 
            begin
                send_sbus_frame(channels_packed);
                repeat (20) @(posedge clk);
 
                check_true("failsafe_active clears again after a single normal frame (no hysteresis on the flag path)", (failsafe_active === 1'b0));
            end
        end
 
        $display("==========================================");
        $display("TEST MARKS: %0d/%0d passed", test_count - error_count, test_count);
        $display("==========================================");
 
        $finish;
    end
 
endmodule
