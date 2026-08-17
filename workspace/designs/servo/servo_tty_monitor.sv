`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/14/2026 04:49:33 AM
// Design Name: 
// Module Name: servo_tty_monitor
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


module servo_tty_monitor #(
    parameter int NUM_SERVOS = 8,
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int PWM_PERIOD_MS = 20,
    parameter logic [4*NUM_SERVOS-1:0] SERVO_CHANNEL_MAP = {4'd7, 4'd6, 4'd5, 4'd4, 4'd3, 4'd2, 4'd1, 4'd0},
    parameter logic [11*NUM_SERVOS-1:0] SERVO_SAFE_US_MAP = {NUM_SERVOS{11'd1500}},
    parameter int FAILSAFE_TIMEOUT_MS = 200,
    parameter int FAILSAFE_RECOVERY_FRAMES = 3,
    parameter int PC_BAUD_RATE = 115_200,
    parameter int UPDATE_INTERVAL_MS = 100,
    parameter bit RESET_ACTIVE_LOW = 1'b1
)(
    input logic clk,
    input logic reset,
 
    input logic sbus_rx_line,
 
    output logic [NUM_SERVOS-1:0] servo_pwm_out,
    output logic failsafe_active,
    output logic pc_tx_line
);

    servo_pwm_top #(
        .NUM_SERVOS(NUM_SERVOS),
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .PWM_PERIOD_MS(PWM_PERIOD_MS),
        .SERVO_CHANNEL_MAP(SERVO_CHANNEL_MAP),
        .SERVO_SAFE_US_MAP(SERVO_SAFE_US_MAP),
        .FAILSAFE_TIMEOUT_MS(FAILSAFE_TIMEOUT_MS),
        .FAILSAFE_RECOVERY_FRAMES(FAILSAFE_RECOVERY_FRAMES),
        .RESET_ACTIVE_LOW(RESET_ACTIVE_LOW)
    ) servoPwmTop (
        .clk(clk),
        .reset(reset),
        .sbus_rx_line(sbus_rx_line),
        .servo_pwm_out(servo_pwm_out),
        .failsafe_active(failsafe_active)
    );
 
    sbus_tty_monitor #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .PC_BAUD_RATE(PC_BAUD_RATE),
        .UPDATE_INTERVAL_MS(UPDATE_INTERVAL_MS),
        .FAILSAFE_TIMEOUT_MS(FAILSAFE_TIMEOUT_MS),
        .FAILSAFE_RECOVERY_FRAMES(FAILSAFE_RECOVERY_FRAMES),
        .RESET_ACTIVE_LOW(RESET_ACTIVE_LOW)
    ) sbusTtyMonitor (
        .clk(clk),
        .reset(reset),
        .sbus_rx_line(sbus_rx_line),
        .pc_tx_line(pc_tx_line)
    );
 
endmodule
