`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/28/2026 10:49:19 PM
// Design Name: 
// Module Name: sbus_pwm_converter_TB
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


module sbus_pwm_converter_TB();
 
    int error_count;
    int test_count;
 
    function automatic logic [10:0] expected_pwm(input logic [10:0] raw);
        logic [13:0] m5;
        logic [11:0] ext;
        m5 = raw * 5;
        ext = (m5 >> 3) + 12'd880;
        if (ext > 12'd2000) return 11'd2000;
        else if (ext < 12'd1000) return 11'd1000;
        else return ext[10:0];
    endfunction
 
    localparam int N5 = 5;
    logic [N5*11-1:0] raw5;
    logic [N5*11-1:0] pwm5;
 
    sbus_pwm_converter #(.NUM_CHANNELS(N5)) uut5 (
        .raw_channels(raw5),
        .pwm_us_channels(pwm5)
    );
 
    localparam int N1 = 1;
    logic [N1*11-1:0] raw1;
    logic [N1*11-1:0] pwm1;
 
    sbus_pwm_converter #(.NUM_CHANNELS(N1)) uut1 (
        .raw_channels(raw1),
        .pwm_us_channels(pwm1)
    );
 
    localparam int N16 = 16;
    logic [N16*11-1:0] raw16;
    logic [N16*11-1:0] pwm16;
 
    sbus_pwm_converter #(.NUM_CHANNELS(N16)) uut16 (
        .raw_channels(raw16),
        .pwm_us_channels(pwm16)
    );
 
    logic [16*11-1:0] raw_default;
    logic [16*11-1:0] pwm_default;
 
    sbus_pwm_converter dutDefault (
        .raw_channels(raw_default),
        .pwm_us_channels(pwm_default)
    );
 
    task automatic check_channel(input logic [10:0] expected, input logic [10:0] actual, input string label);
        test_count++;
        if (actual !== expected) begin
            error_count++;
            $display("[ERROR] %s: expected=%0d actual=%0d", label, expected, actual);
        end
    endtask
 
    initial begin
 
        error_count = 0;
        test_count = 0;
 
        begin
            logic [10:0] vals [0:4];
            vals[0] = 11'd0;
            vals[1] = 11'd2047;
            vals[2] = 11'd992;
            vals[3] = 11'd400;
            vals[4] = 11'd1600;
 
            for (int i = 0; i < N5; i++) raw5[i*11 +: 11] = vals[i];
            #1;
 
            for (int i = 0; i < N5; i++) begin
                check_channel(expected_pwm(vals[i]), pwm5[i*11 +: 11], $sformatf("N5 channel %0d", i));
            end
        end
 
        begin
            raw1 = 11'd1234;
            #1;
            check_channel(expected_pwm(11'd1234), pwm1[10:0], "N1 single channel");
        end
 
        begin
            for (int i = 0; i < N16; i++) begin
                raw16[i*11 +: 11] = 11'(i * 130);
            end
            #1;
 
            for (int i = 0; i < N16; i++) begin
                check_channel(expected_pwm(11'(i * 130)), pwm16[i*11 +: 11], $sformatf("N16 channel %0d", i));
            end
        end
 
        begin
            for (int i = 0; i < 16; i++) begin
                raw_default[i*11 +: 11] = 11'(i * 130 + 7);
            end
            #1;
 
            for (int i = 0; i < 16; i++) begin
                check_channel(expected_pwm(11'(i * 130 + 7)), pwm_default[i*11 +: 11], $sformatf("default (no override) channel %0d", i));
            end
        end
 
        begin
            for (int i = 0; i < N5; i++) raw5[i*11 +: 11] = 11'd992;
            #1;
            for (int i = 0; i < N5; i++) begin
                check_channel(expected_pwm(11'd992), pwm5[i*11 +: 11], $sformatf("N5 after change, channel %0d", i));
            end
        end
 
        $display("==========================================");
        $display("TEST MARKS: %0d/%0d passed", test_count - error_count, test_count);
        $display("==========================================");
 
        $finish;
    end
 
endmodule
