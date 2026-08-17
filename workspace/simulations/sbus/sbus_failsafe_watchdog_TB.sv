`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07/29/2026 02:19:25 AM
// Design Name:
// Module Name: sbus_failsafe_watchdog_TB
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


module sbus_failsafe_watchdog_TB();

    localparam int CLK_FREQ_HZ = 100_000;
    localparam int TIMEOUT_MS = 1;
    localparam int RECOVERY_FRAMES = 3;

    logic clk;
    logic reset;
    logic sbus_frame_valid;
    logic sbus_failsafe;
    logic sbus_frame_lost;
    logic failsafe_active;

    sbus_failsafe_watchdog #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .TIMEOUT_MS(TIMEOUT_MS),
        .RECOVERY_FRAMES(RECOVERY_FRAMES)
    ) uut0 (
        .clk(clk),
        .reset(reset),
        .sbus_frame_valid(sbus_frame_valid),
        .sbus_failsafe(sbus_failsafe),
        .sbus_frame_lost(sbus_frame_lost),
        .failsafe_active(failsafe_active)
    );
 
    logic reset1;
    logic sbus_frame_valid1;
    logic sbus_failsafe1;
    logic sbus_frame_lost1;
    logic failsafe_active1;
 
    sbus_failsafe_watchdog #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .TIMEOUT_MS(TIMEOUT_MS),
        .RECOVERY_FRAMES(1)
    ) uut1 (
        .clk(clk),
        .reset(reset1),
        .sbus_frame_valid(sbus_frame_valid1),
        .sbus_failsafe(sbus_failsafe1),
        .sbus_frame_lost(sbus_frame_lost1),
        .failsafe_active(failsafe_active1)
    );

    logic reset2;
    logic sbus_frame_valid2;
    logic sbus_failsafe2;
    logic sbus_frame_lost2;
    logic failsafe_active2;
 
    sbus_failsafe_watchdog #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .TIMEOUT_MS(TIMEOUT_MS),
        .RECOVERY_FRAMES(RECOVERY_FRAMES)
    ) uut2 (
        .clk(clk),
        .reset(reset2),
        .sbus_frame_valid(sbus_frame_valid2),
        .sbus_failsafe(sbus_failsafe2),
        .sbus_frame_lost(sbus_frame_lost2),
        .failsafe_active(failsafe_active2)
    );

    int error_count;
    int test_count;
 
    always #5 clk = ~clk;
 
    task automatic check_failsafe(input logic expected, input string label);
        test_count++;
        if (failsafe_active !== expected) begin
            error_count++;
            $display("[ERROR] %s: expected=%0b actual=%0b", label, expected, failsafe_active);
        end
    endtask
 
    task automatic pulse_frame(input logic failsafe_flag, input logic frame_lost_flag);
        @(negedge clk);
        sbus_failsafe = failsafe_flag;
        sbus_frame_lost = frame_lost_flag;
        sbus_frame_valid = 1'b1;
        @(negedge clk);
        sbus_frame_valid = 1'b0;
    endtask
 
    initial begin
 
        clk = 1'b0;
        reset = 1'b1;
        sbus_frame_valid = 1'b0;
        sbus_failsafe = 1'b0;
        sbus_frame_lost = 1'b0;
        error_count = 0;
        test_count = 0;

        repeat (3) @(negedge clk);

        check_failsafe(1'b0, "no failsafe after reset");

        reset = 1'b0;
        repeat (2) @(negedge clk);

        for (int i = 0; i < 5; i++) begin
            pulse_frame(1'b1, 1'b0);
            check_failsafe(1'b0, $sformatf("iteration %0d, failsafe-flagged frame before real link", i));
        end

        repeat (300) @(negedge clk);
        check_failsafe(1'b0, "no false trigger, missing frames before real link (3x the threshold)");

        pulse_frame(1'b0, 1'b0);
        check_failsafe(1'b0, "no failsafe on the first frame with real content");

        repeat (95) @(negedge clk);
        check_failsafe(1'b0, "no failsafe before the threshold (95/100 cycles)");

        repeat (6) @(negedge clk); 
        check_failsafe(1'b1, "failsafe asserted after the threshold (timeout)");

        repeat (50) @(negedge clk);
        check_failsafe(1'b1, "failsafe stays asserted, no oscillation");

        pulse_frame(1'b0, 1'b0);
        check_failsafe(1'b1, "a single frame does NOT clear failsafe (RECOVERY_FRAMES=3)");

        pulse_frame(1'b0, 1'b0);
        check_failsafe(1'b1, "second consecutive frame, still in failsafe");

        pulse_frame(1'b0, 1'b0);
        check_failsafe(1'b0, "third consecutive frame clears failsafe");

        repeat (101) @(negedge clk);
        check_failsafe(1'b1, "failsafe reappears after a new absence of frames");

        pulse_frame(1'b0, 1'b0);
        check_failsafe(1'b1, "first frame of an interrupted streak, still failsafe");
        pulse_frame(1'b0, 1'b0);
        check_failsafe(1'b1, "second frame of the interrupted streak, still failsafe");
        repeat (101) @(negedge clk);
        check_failsafe(1'b1, "failsafe stays asserted after the streak breaks");
        pulse_frame(1'b0, 1'b0);
        check_failsafe(1'b1, "after the streak breaks, a new frame is still insufficient");
        pulse_frame(1'b0, 1'b0);
        check_failsafe(1'b1, "second new frame, still insufficient");
        pulse_frame(1'b0, 1'b0);
        check_failsafe(1'b0, "third new frame (count restarted) clears failsafe");

        pulse_frame(1'b1, 1'b0);
        check_failsafe(1'b1, "failsafe_active on the sbus_failsafe protocol flag");

        repeat (20) @(negedge clk);
        check_failsafe(1'b1, "the protocol flag persists with no new frames");

        pulse_frame(1'b0, 1'b0);
        check_failsafe(1'b0, "failsafe_active returns to 0 after a frame with clean flags");

        pulse_frame(1'b0, 1'b1);
        check_failsafe(1'b1, "failsafe_active on the sbus_frame_lost protocol flag");

        pulse_frame(1'b0, 1'b0);
        check_failsafe(1'b0, "failsafe_active returns to 0 after a frame with clean flags (frame_lost)");

        reset2 = 1'b1;
        sbus_frame_valid2 = 1'b0;
        sbus_failsafe2 = 1'b0;
        sbus_frame_lost2 = 1'b0;
        @(negedge clk);
        reset2 = 1'b0;
        repeat (2) @(negedge clk);

        @(negedge clk);
        sbus_failsafe2 = 1'b0;
        sbus_frame_lost2 = 1'b1;
        sbus_frame_valid2 = 1'b1;
        @(negedge clk);
        sbus_frame_valid2 = 1'b0;

        test_count++;
        if (failsafe_active2 !== 1'b1) begin
            error_count++;
            $display("[ERROR] gate opened by failsafe=0/frame_lost=1 frame, but the OR with frame_lost stays active — expected=1 actual=%0b", failsafe_active2);
        end

        @(negedge clk);
        sbus_frame_lost2 = 1'b0;
        #1;
        test_count++;
        if (failsafe_active2 !== 1'b0) begin
            error_count++;
            $display("[ERROR]: after frame_lost drops, failsafe_active expected=0 (gate already opened by D1) actual=%0b", failsafe_active2);
        end

        pulse_frame(1'b1, 1'b0);
        check_failsafe(1'b1, "failsafe active before reset (via protocol flag)");

        reset = 1'b1;
        @(negedge clk);
        check_failsafe(1'b0, "reset clears active failsafe instantly");
        reset = 1'b0;
        repeat (2) @(negedge clk);

        pulse_frame(1'b1, 1'b0);
        check_failsafe(1'b0, "after reset, a failsafe-flagged frame does NOT trigger (gate closed again)");

        repeat (300) @(negedge clk);
        check_failsafe(1'b0, "after reset, no false trigger on missing frames (gate still closed)");

        pulse_frame(1'b0, 1'b0);
        check_failsafe(1'b0, "after reset, the first real frame reopens the gate normally");

        reset1 = 1'b1;
        sbus_frame_valid1 = 1'b0;
        sbus_failsafe1 = 1'b0;
        sbus_frame_lost1 = 1'b0;
        @(negedge clk);
        reset1 = 1'b0;
        repeat (2) @(negedge clk);

        @(negedge clk);
        sbus_frame_valid1 = 1'b1;
        @(negedge clk);
        sbus_frame_valid1 = 1'b0;
        test_count++;
        if (failsafe_active1 !== 1'b0) begin
            error_count++;
            $display("[ERROR] F1 (RECOVERY_FRAMES=1): expected no failsafe after real sync, actual=%0b", failsafe_active1);
        end

        repeat (101) @(negedge clk);
        test_count++;
        if (failsafe_active1 !== 1'b1) begin
            error_count++;
            $display("[ERROR] F2 (RECOVERY_FRAMES=1): expected failsafe after the threshold, actual=%0b", failsafe_active1);
        end

        @(negedge clk);
        sbus_frame_valid1 = 1'b1;
        @(negedge clk);
        sbus_frame_valid1 = 1'b0;
        test_count++;
        if (failsafe_active1 !== 1'b0) begin
            error_count++;
            $display("[ERROR] F3 (RECOVERY_FRAMES=1): expected instant recovery on a single frame, actual=%0b", failsafe_active1);
        end

        $display("==========================================");
        $display("TEST MARKS: %0d/%0d passed", test_count - error_count, test_count);
        $display("==========================================");

        $finish;
    end

endmodule
