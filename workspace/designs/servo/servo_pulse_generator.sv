`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/13/2026 12:14:41 AM
// Design Name: 
// Module Name: servo_pulse_generator
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


module servo_pulse_generator #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int PWM_PERIOD_MS = 20,
    parameter int PWM_SAFE_US = 1500
)(
    input logic clk,
    input logic reset,
    input logic [10:0] pwm_us,

    output logic servo_pwm_out
);

    localparam int TICKS_PER_US = CLK_FREQ_HZ / 1_000_000;
    localparam int PERIOD_TICKS = (CLK_FREQ_HZ / 1000) * PWM_PERIOD_MS;
    localparam int PERIOD_CNT_WIDTH = $clog2(PERIOD_TICKS);
    localparam int PULSE_TICKS_WIDTH = $clog2(2000 * TICKS_PER_US + 1);

    logic [PERIOD_CNT_WIDTH-1:0] period_cnt;
    logic period_wrap;

    always_ff @(posedge clk) begin
        if (reset) begin
            period_cnt <= '0;
        end
        else if (period_cnt == PERIOD_TICKS - 1) begin
            period_cnt <= '0;
        end
        else begin
            period_cnt <= period_cnt + 1'b1;
        end
    end
 
    assign period_wrap = (period_cnt == PERIOD_TICKS - 1);
 
    logic [10:0] pwm_us_held;
    logic [PULSE_TICKS_WIDTH-1:0] pulse_ticks;
 
    always_ff @(posedge clk) begin
        if (reset) begin
            pwm_us_held <= PWM_SAFE_US[10:0];
        end
        else if (period_wrap) begin
            pwm_us_held <= pwm_us;
        end
    end
 
    assign pulse_ticks = pwm_us_held * TICKS_PER_US;
 
    always_ff @(posedge clk) begin
        if (reset) begin
            servo_pwm_out <= 1'b0;
        end
        else begin
            servo_pwm_out <= (period_cnt < pulse_ticks);
        end
    end
 
endmodule
