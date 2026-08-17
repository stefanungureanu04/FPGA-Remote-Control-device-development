`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07/28/2026 05:32:30 PM
// Design Name:
// Module Name: sbus_channel_register_TB
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


module sbus_channel_register_TB();

    logic clk;
    logic reset;
    logic sbus_frame_valid;
    logic [175:0] sbus_channels_in;
    logic [175:0] sbus_channels_held;

    int error_count;
    int test_count;

    sbus_channel_register uut (
        .clk(clk),
        .reset(reset),
        .sbus_channels_in(sbus_channels_in),
        .sbus_frame_valid(sbus_frame_valid),
        .sbus_channels_held(sbus_channels_held)
    );

    always #5 clk = ~clk;

    task automatic check_held(input logic [175:0] expected, input string label);
        test_count++;
        if (sbus_channels_held !== expected) begin
            error_count++;
            $display("[ERROR] %s: expected=%h actual=%h", label, expected, sbus_channels_held);
        end
    endtask

    task automatic pulse_valid(input logic [175:0] data);
        
        @(negedge clk);
        sbus_channels_in = data;
        sbus_frame_valid = 1'b1;
        
        @(negedge clk);
        sbus_frame_valid = 1'b0;

    endtask

    initial begin

        clk = 1'b0;
        reset = 1'b1;
        sbus_channels_in = '0;
        sbus_frame_valid = 1'b0;
        error_count = 0;
        test_count = 0;

        repeat (3) @(negedge clk);
        check_held(176'h0, "test1 zero after reset");
        reset = 1'b0;

        repeat (2) @(negedge clk);
        sbus_channels_in = 176'hDEAD_BEEF_1234_5678_9ABC_DEF0_1122_3344_5566;
        
        repeat (3) @(negedge clk);
        check_held(176'h0, "test2 no update without a valid pulse");
        pulse_valid(176'hAAAA_1111_2222_3333_4444_5555_6666_7777_8888);
        check_held(176'hAAAA_1111_2222_3333_4444_5555_6666_7777_8888, "test3 load on valid pulse");

        sbus_channels_in = 176'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
        repeat (4) @(negedge clk);
        check_held(176'hAAAA_1111_2222_3333_4444_5555_6666_7777_8888, "test4 stable after pulse, no new valid");

        pulse_valid(176'h1357_9BDF_2468_ACE0_1357_9BDF_2468_ACE0_1357);
        check_held(176'h1357_9BDF_2468_ACE0_1357_9BDF_2468_ACE0_1357, "test5 overwrite on second pulse");

        begin
            @(negedge clk);
            sbus_channels_in = 176'h1111_1111_1111_1111_1111_1111_1111_1111_1111;
            sbus_frame_valid = 1'b1;
            
            @(negedge clk);
            sbus_channels_in = 176'h2222_2222_2222_2222_2222_2222_2222_2222_2222;
            
            @(negedge clk);
            sbus_frame_valid = 1'b0;
            check_held(176'h2222_2222_2222_2222_2222_2222_2222_2222_2222, "test6 two consecutive pulses, second value stays");
        end

        reset = 1'b1;
        
        @(negedge clk);
        check_held(176'h0, "test7 reset during operation");
        reset = 1'b0;

        repeat (2) @(negedge clk);
        pulse_valid(176'h0F0F_0F0F_0F0F_0F0F_0F0F_0F0F_0F0F_0F0F_0F0F);
        check_held(176'h0F0F_0F0F_0F0F_0F0F_0F0F_0F0F_0F0F_0F0F_0F0F, "test8 normal operation after reset");

        repeat (3) @(negedge clk);
        
        $display("==========================================");
        $display("TEST MARKS: %0d/%0d passed", test_count - error_count, test_count);
        $display("==========================================");

        $finish;
    end

endmodule