`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/13/2026 12:15:11 AM
// Design Name: 
// Module Name: servo_pulse_generator_TB
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


module servo_pulse_generator_TB();
 
    localparam int CLK_FREQ_HZ = 1_000_000;
    localparam int PWM_PERIOD_MS = 20;
    localparam int PWM_SAFE_US = 1500;
    localparam int PERIOD_TICKS = (CLK_FREQ_HZ / 1000) * PWM_PERIOD_MS;
    localparam int CLK_PERIOD_NS = 1_000_000_000 / CLK_FREQ_HZ;
 
    logic clk;
    logic reset;
    logic [10:0] pwm_us;
    logic servo_pwm_out;
 
    int test_count;
    int error_count;
 
    servo_pulse_generator #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .PWM_PERIOD_MS(PWM_PERIOD_MS),
        .PWM_SAFE_US(PWM_SAFE_US)
    ) uutServoPulseGenerator (
        .clk(clk),
        .reset(reset),
        .pwm_us(pwm_us),
        .servo_pwm_out(servo_pwm_out)
    );
 
    always begin
        clk = 1'b0;
        #(CLK_PERIOD_NS/2);
        clk = 1'b1;
        #(CLK_PERIOD_NS/2);
    end


    task automatic measure_pulse_width_us(output int width_us);
        int count;
        begin
            @(posedge servo_pwm_out);
            count = 0;
            while (servo_pwm_out == 1'b1) begin
                @(posedge clk);
                count++;
            end
            width_us = count;
        end
    endtask

    task automatic measure_period_ticks(output int period_ticks_out);
        int count;
        begin
            @(posedge servo_pwm_out);
            count = 0;
            while (servo_pwm_out == 1'b1) begin
                @(posedge clk);
                count++;
            end
            while (servo_pwm_out == 1'b0) begin
                @(posedge clk);
                count++;
            end
            period_ticks_out = count;
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
 
        reset = 1'b1;
        pwm_us = 11'd0;
        repeat (5) @(posedge clk);
        reset = 1'b0;
 
        pwm_us = 11'd1200;
 
        begin
            int width_us;
            measure_pulse_width_us(width_us);
            check_equal("pulse width right after reset (safe default)", width_us, PWM_SAFE_US, 1);
        end
 
        begin
            int period_ticks_out;
            measure_period_ticks(period_ticks_out);
            check_equal("PWM period (clock ticks)", period_ticks_out, PERIOD_TICKS, 1);
        end
 
        pwm_us = 11'd1000;
        repeat (2 * PERIOD_TICKS + 10) @(posedge clk);
        begin
            int width_us;
            measure_pulse_width_us(width_us);
            check_equal("pulse width (1000us)", width_us, 1000, 1);
        end
 
        pwm_us = 11'd2000;
        repeat (2 * PERIOD_TICKS + 10) @(posedge clk);
        begin
            int width_us;
            measure_pulse_width_us(width_us);
            check_equal("pulse width (2000us)", width_us, 2000, 1);
        end
 
        pwm_us = 11'd1500;
        repeat (2 * PERIOD_TICKS + 10) @(posedge clk);
        begin
            int width_us;
            measure_pulse_width_us(width_us);
            check_equal("pulse width (1500us)", width_us, 1500, 1);
        end
 
        pwm_us = 11'd0;
        repeat (2 * PERIOD_TICKS + 10) @(posedge clk);
        begin
            int idle_cycles;
            int high_seen;
            idle_cycles = 0;
            high_seen = 0;
            while (idle_cycles < PERIOD_TICKS) begin
                @(posedge clk);
                if (servo_pwm_out == 1'b1) begin
                    high_seen = 1;
                end
                idle_cycles++;
            end
            test_count++;
            if (high_seen == 1) begin
                error_count++;
                $display("[ERROR]: pulse width (0us raw, passthrough) - expected no pulse, but signal went high");
            end
        end
 
        pwm_us = 11'd1000;
        repeat (2 * PERIOD_TICKS + 10) @(posedge clk);
 
        @(posedge servo_pwm_out);
        begin
            int count;
            count = 0;
            while (servo_pwm_out == 1'b1) begin
                @(posedge clk);
                count++;
                if (count == 1) begin
                    pwm_us = 11'd1200;
                end
            end
            check_equal("pulse width unaffected mid-period", count, 1000, 1);
        end
 
        begin
            int width_us;
            measure_pulse_width_us(width_us);
            check_equal("pulse width after next latch (1200us)", width_us, 1200, 1);
        end
 
        $display("==========================================");
        $display("TEST MARKS: %0d/%0d passed", test_count - error_count, test_count);
        $display("==========================================");
 
        $finish;
    end
 
endmodule
