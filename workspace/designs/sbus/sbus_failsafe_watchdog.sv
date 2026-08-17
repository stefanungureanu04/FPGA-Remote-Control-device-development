`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07/29/2026 02:19:13 AM
// Design Name:
// Module Name: sbus_failsafe_watchdog
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


module sbus_failsafe_watchdog #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int TIMEOUT_MS = 200,
    parameter int RECOVERY_FRAMES = 3
)(
    input logic clk,
    input logic reset,

    input logic sbus_frame_valid,
    input logic sbus_failsafe,
    input logic sbus_frame_lost,

    output logic failsafe_active
);

    localparam int TIMEOUT_TICKS = (CLK_FREQ_HZ / 1000) * TIMEOUT_MS;
    localparam int CNT_WIDTH = $clog2(TIMEOUT_TICKS + 1);
    localparam int RECOVERY_CNT_WIDTH = $clog2(RECOVERY_FRAMES + 1);

    logic [CNT_WIDTH-1:0] timeout_cnt;
    logic [RECOVERY_CNT_WIDTH-1:0] recovery_cnt;
    logic timeout_failsafe_latched;
    logic has_ever_had_live_link;

    always_ff @(posedge clk) begin
        if (reset) begin
            timeout_cnt <= '0;
            recovery_cnt <= '0;
            timeout_failsafe_latched <= 1'b0;
            has_ever_had_live_link <= 1'b0;
        end
        else begin

            if (sbus_frame_valid && !sbus_failsafe) begin
                has_ever_had_live_link <= 1'b1;
            end

            if (sbus_frame_valid) begin
                timeout_cnt <= '0;
            end
            else if (timeout_cnt < TIMEOUT_TICKS) begin
                timeout_cnt <= timeout_cnt + 1'b1;
            end

            if (!sbus_frame_valid && timeout_cnt >= TIMEOUT_TICKS && has_ever_had_live_link) begin
                timeout_failsafe_latched <= 1'b1;
                recovery_cnt <= '0;
            end
            else if (sbus_frame_valid && timeout_failsafe_latched) begin
                if (recovery_cnt == RECOVERY_FRAMES - 1) begin
                    timeout_failsafe_latched <= 1'b0;
                    recovery_cnt <= '0;
                end
                else begin
                    recovery_cnt <= recovery_cnt + 1'b1;
                end
            end
        end
    end

    assign failsafe_active = has_ever_had_live_link && (timeout_failsafe_latched || sbus_failsafe || sbus_frame_lost);

endmodule