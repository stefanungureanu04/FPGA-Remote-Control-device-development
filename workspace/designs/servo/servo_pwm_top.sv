`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/13/2026 02:52:34 AM
// Design Name: 
// Module Name: servo_pwm_top
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


module servo_pwm_top #(
    parameter int NUM_SERVOS = 8,
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int PWM_PERIOD_MS = 20,
    parameter logic [4*NUM_SERVOS-1:0] SERVO_CHANNEL_MAP = {4'd7, 4'd6, 4'd5, 4'd4, 4'd3, 4'd2, 4'd1, 4'd0},
    parameter logic [11*NUM_SERVOS-1:0] SERVO_SAFE_US_MAP = {NUM_SERVOS{11'd1500}},
    parameter int FAILSAFE_TIMEOUT_MS = 200,
    parameter int FAILSAFE_RECOVERY_FRAMES = 3,
    parameter bit RESET_ACTIVE_LOW = 1'b1
)(
    input logic clk,
    input logic reset,
 
    input logic sbus_rx_line,
 
    output logic [NUM_SERVOS-1:0] servo_pwm_out,
    output logic failsafe_active
);
 
    logic reset_active_high;
 
    assign reset_active_high = RESET_ACTIVE_LOW ? ~reset : reset;
 
    logic [7:0] uart_rx_data;
    logic uart_rx_frame_ready;
    logic uart_rx_parity_err;
    logic uart_rx_frame_err;
 
    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(100_000),
        .DATA_BITS(8),
        .PARITY_TYPE("EVEN"),
        .STOP_BITS(2),
        .OVERSAMPLE(16),
        .INVERT_LINE(1'b1)
    ) uartRx (
        .clk(clk),
        .reset(reset_active_high),
        .uart_rx_line(sbus_rx_line),
        .uart_rx_data(uart_rx_data),
        .uart_rx_frame_ready(uart_rx_frame_ready),
        .uart_rx_parity_err(uart_rx_parity_err),
        .uart_rx_frame_err(uart_rx_frame_err)
    );
 
    logic [175:0] pwm_us_all;
    logic sbus_digital_ch17;
    logic sbus_digital_ch18;
 
    sbus_rx_chain #(
        .NUM_CHANNELS(16),
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .FAILSAFE_TIMEOUT_MS(FAILSAFE_TIMEOUT_MS),
        .FAILSAFE_RECOVERY_FRAMES(FAILSAFE_RECOVERY_FRAMES)
    ) sbusRxChain (
        .clk(clk),
        .reset(reset_active_high),
        .uart_rx_data(uart_rx_data),
        .uart_rx_frame_ready(uart_rx_frame_ready),
        .uart_rx_parity_err(uart_rx_parity_err),
        .uart_rx_frame_err(uart_rx_frame_err),
        .pwm_us_channels(pwm_us_all),
        .failsafe_active(failsafe_active),
        .sbus_digital_ch17(sbus_digital_ch17),
        .sbus_digital_ch18(sbus_digital_ch18)
    );
 
    genvar i;
    generate
        for (i = 0; i < NUM_SERVOS; i++) begin : gen_servo
 
            servo_pulse_generator #(
                .CLK_FREQ_HZ(CLK_FREQ_HZ),
                .PWM_PERIOD_MS(PWM_PERIOD_MS),
                .PWM_SAFE_US(SERVO_SAFE_US_MAP[i*11 +: 11])
            ) servoPulseGenerator (
                .clk(clk),
                .reset(reset_active_high),
                .pwm_us(pwm_us_all[SERVO_CHANNEL_MAP[i*4 +: 4]*11 +: 11]),
                .servo_pwm_out(servo_pwm_out[i])
            );
 
        end
    endgenerate
 
endmodule
