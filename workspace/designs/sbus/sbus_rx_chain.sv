`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07/29/2026 08:08:57 PM
// Design Name:
// Module Name: sbus_rx_chain
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


module sbus_rx_chain #(
    parameter int NUM_CHANNELS = 16,
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int FAILSAFE_TIMEOUT_MS = 200,
    parameter int FAILSAFE_RECOVERY_FRAMES = 3
)(
    input logic clk,
    input logic reset,
 
    input logic [7:0] uart_rx_data,
    input logic uart_rx_frame_ready,
    input logic uart_rx_parity_err,
    input logic uart_rx_frame_err,
 
    output logic [NUM_CHANNELS*11-1:0] pwm_us_channels,
    output logic failsafe_active,
    output logic sbus_digital_ch17,
    output logic sbus_digital_ch18
);
 
    logic [175:0] sbus_channels_raw;
    logic sbus_frame_lost;
    logic sbus_failsafe;
    logic sbus_frame_valid;
    logic sbus_frame_error;
 
    sbus_frame_decoder sbusFrameDecoder (
        .clk(clk),
        .reset(reset),
        .uart_rx_data(uart_rx_data),
        .uart_rx_frame_ready(uart_rx_frame_ready),
        .uart_rx_parity_err(uart_rx_parity_err),
        .uart_rx_frame_err(uart_rx_frame_err),
        .sbus_channels(sbus_channels_raw),
        .sbus_digital_ch17(sbus_digital_ch17),
        .sbus_digital_ch18(sbus_digital_ch18),
        .sbus_frame_lost(sbus_frame_lost),
        .sbus_failsafe(sbus_failsafe),
        .sbus_frame_valid(sbus_frame_valid),
        .sbus_frame_error(sbus_frame_error)
    );
 
    logic [175:0] sbus_channels_held;
 
    sbus_channel_register sbusChannelRegister (
        .clk(clk),
        .reset(reset),
        .sbus_channels_in(sbus_channels_raw),
        .sbus_frame_valid(sbus_frame_valid),
        .sbus_channels_held(sbus_channels_held)
    );
 
    sbus_pwm_converter #(
        .NUM_CHANNELS(NUM_CHANNELS)
    ) sbusPwmConverter (
        .raw_channels(sbus_channels_held[NUM_CHANNELS*11-1:0]),
        .pwm_us_channels(pwm_us_channels)
    );
 
    sbus_failsafe_watchdog #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .TIMEOUT_MS(FAILSAFE_TIMEOUT_MS),
        .RECOVERY_FRAMES(FAILSAFE_RECOVERY_FRAMES)
    ) sbusFailsafeWatchdog (
        .clk(clk),
        .reset(reset),
        .sbus_frame_valid(sbus_frame_valid),
        .sbus_failsafe(sbus_failsafe),
        .sbus_frame_lost(sbus_frame_lost),
        .failsafe_active(failsafe_active)
    );
 
endmodule