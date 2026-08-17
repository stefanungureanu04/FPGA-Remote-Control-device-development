`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/28/2026 05:48:58 PM
// Design Name: 
// Module Name: sbus_tty_monitor_TB
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


module sbus_tty_monitor_TB();
 
    localparam int CLK_FREQ_HZ = 1_600_000;
    localparam int SBUS_BAUD_RATE = 100_000;
    localparam int SBUS_OVERSAMPLE = 16;
    localparam int SBUS_BIT_CYCLES = CLK_FREQ_HZ / (SBUS_BAUD_RATE * SBUS_OVERSAMPLE);
    localparam int SBUS_BIT_PERIOD = SBUS_OVERSAMPLE * SBUS_BIT_CYCLES;
 
    localparam int PC_BAUD_RATE = 160_000;
    localparam int PC_BIT_PERIOD = CLK_FREQ_HZ / PC_BAUD_RATE;
 
    localparam int UPDATE_INTERVAL_MS = 4;
    localparam int INTERVAL_TICKS = (CLK_FREQ_HZ / 1000) * UPDATE_INTERVAL_MS;
    localparam int FAILSAFE_TIMEOUT_MS = 100; 
    localparam int FAILSAFE_TIMEOUT_TICKS = (CLK_FREQ_HZ / 1000) * FAILSAFE_TIMEOUT_MS;
    localparam int FAILSAFE_RECOVERY_FRAMES = 3;
    localparam int REPORT_CYCLES_MARGIN = 346 * 10 * (CLK_FREQ_HZ / PC_BAUD_RATE);
 
    localparam logic [7:0] SBUS_START_BYTE = 8'h0F;
    localparam logic [7:0] SBUS_END_BYTE = 8'h00;
 
    logic clk;
    logic reset;
    logic sbus_rx_line;
    logic pc_tx_line;
 
    int error_count;
    int test_count;
 
    sbus_tty_monitor #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .PC_BAUD_RATE(PC_BAUD_RATE),
        .UPDATE_INTERVAL_MS(UPDATE_INTERVAL_MS),
        .FAILSAFE_TIMEOUT_MS(FAILSAFE_TIMEOUT_MS),
        .FAILSAFE_RECOVERY_FRAMES(FAILSAFE_RECOVERY_FRAMES),
        .RESET_ACTIVE_LOW(1'b0)
    ) uutLink (
        .clk(clk),
        .reset(reset),
        .sbus_rx_line(sbus_rx_line),
        .pc_tx_line(pc_tx_line)
    );
 
    logic reset_active_low_raw;
    logic dummy_sbus_rx_line;
    logic dummy_pc_tx_line;
 
    sbus_tty_monitor #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .PC_BAUD_RATE(PC_BAUD_RATE),
        .UPDATE_INTERVAL_MS(UPDATE_INTERVAL_MS),
        .RESET_ACTIVE_LOW(1'b1)
    ) uutLink_i (
        .clk(clk),
        .reset(reset_active_low_raw),
        .sbus_rx_line(dummy_sbus_rx_line),
        .pc_tx_line(dummy_pc_tx_line)
    );
 
    always #5 clk = ~clk;
 
    task automatic drive_sbus_bit(input logic logical_bit);
        sbus_rx_line = ~logical_bit;
        repeat (SBUS_BIT_PERIOD) @(negedge clk);
    endtask
 
    task automatic send_sbus_byte(input logic [7:0] data);
        logic parity_bit;
        parity_bit = ^data;
        drive_sbus_bit(1'b0);
        for (int i = 0; i < 8; i++) drive_sbus_bit(data[i]);
        drive_sbus_bit(parity_bit);
        drive_sbus_bit(1'b1);
        drive_sbus_bit(1'b1);
    endtask
 
    task automatic send_sbus_frame(input logic [175:0] ch_bits, input logic [7:0] flags);
        send_sbus_byte(SBUS_START_BYTE);
        for (int i = 0; i < 22; i++) send_sbus_byte(ch_bits[i*8 +: 8]);
        send_sbus_byte(flags);
        send_sbus_byte(SBUS_END_BYTE);
    endtask
 
    logic [7:0] rx_buffer [0:16383];
    int rx_count;
 
    initial begin
        rx_count = 0;
        forever begin
            @(negedge pc_tx_line);
            begin
                logic [7:0] byte_val;
                repeat (PC_BIT_PERIOD / 2) @(posedge clk);
                for (int i = 0; i < 8; i++) begin
                    repeat (PC_BIT_PERIOD) @(posedge clk);
                    byte_val[i] = pc_tx_line;
                end
                repeat (PC_BIT_PERIOD) @(posedge clk); 
                rx_buffer[rx_count] = byte_val;
                rx_count = rx_count + 1;
            end
        end
    end
 
    function automatic logic [10:0] expected_pwm(input logic [10:0] raw);
        logic [13:0] m5;
        logic [11:0] ext;
        m5 = raw * 5;
        ext = (m5 >> 3) + 12'd880;
        if (ext > 12'd2000) return 11'd2000;
        else if (ext < 12'd1000) return 11'd1000;
        else return ext[10:0];
    endfunction
 
    int read_idx;
 
    task automatic check_byte(input logic [7:0] expected, input string label);
        test_count++;
        if (rx_buffer[read_idx] !== expected) begin
            error_count++;
            $display("[ERROR] %s: expected=%0d('%s') actual=%0d('%s') at offset %0d", label, expected, expected, rx_buffer[read_idx], rx_buffer[read_idx], read_idx);
        end
        read_idx++;
    endtask
 
    task automatic verify_prefix();
        check_byte(8'h1B, "prefix ESC 1");
        check_byte("[", "prefix '['");
        check_byte("2", "prefix '2'");
        check_byte("J", "prefix 'J'");
        check_byte(8'h1B, "prefix ESC 2");
        check_byte("[", "prefix '['");
        check_byte("H", "prefix 'H'");
    endtask
 
    task automatic verify_failsafe_line(input logic expected_failsafe);
        check_byte(8'h0D, "failsafe CR (blank line)");
        check_byte(8'h0A, "failsafe LF (blank line)");
        check_byte("F", "failsafe 'F'");
        check_byte("A", "failsafe 'A' 1");
        check_byte("I", "failsafe 'I'");
        check_byte("L", "failsafe 'L' 1");
        check_byte("S", "failsafe 'S'");
        check_byte("A", "failsafe 'A' 2");
        check_byte("F", "failsafe 'F' 2");
        check_byte("E", "failsafe 'E' 1");
        check_byte("_", "failsafe '_'");
        check_byte("E", "failsafe 'E' 2");
        check_byte("N", "failsafe 'N'");
        check_byte("A", "failsafe 'A' 3");
        check_byte("B", "failsafe 'B'");
        check_byte("L", "failsafe 'L' 2");
        check_byte("E", "failsafe 'E' 3");
        check_byte("D", "failsafe 'D'");
        check_byte(" ", "failsafe space 1");
        check_byte("=", "failsafe '='");
        check_byte(" ", "failsafe space 2");
        check_byte(8'h30 + expected_failsafe, "failsafe digit");
        check_byte(8'h0D, "failsafe final CR");
        check_byte(8'h0A, "failsafe final LF");
    endtask
 
    task automatic verify_digital_lines(input logic expected_ch17, input logic expected_ch18);
        check_byte(8'h0D, "digital CR (blank line)");
        check_byte(8'h0A, "digital LF (blank line)");
        check_byte("D", "digital 'D' 1");
        check_byte("I", "digital 'I' 1");
        check_byte("G", "digital 'G' 1");
        check_byte("I", "digital 'I' 2");
        check_byte("T", "digital 'T' 1");
        check_byte("A", "digital 'A' 1");
        check_byte("L", "digital 'L' 1");
        check_byte(" ", "digital space 1");
        check_byte("C", "digital 'C' 1");
        check_byte("H", "digital 'H' 1");
        check_byte("1", "digital '1' 1");
        check_byte("7", "digital '7'");
        check_byte(":", "digital ':' 1");
        check_byte(" ", "digital space 2");
        check_byte(8'h30 + expected_ch17, "digital digit ch17");
        check_byte(8'h0D, "digital CR 1");
        check_byte(8'h0A, "digital LF 1");
        check_byte("D", "digital 'D' 2");
        check_byte("I", "digital 'I' 3");
        check_byte("G", "digital 'G' 2");
        check_byte("I", "digital 'I' 4");
        check_byte("T", "digital 'T' 2");
        check_byte("A", "digital 'A' 2");
        check_byte("L", "digital 'L' 2");
        check_byte(" ", "digital space 3");
        check_byte("C", "digital 'C' 2");
        check_byte("H", "digital 'H' 2");
        check_byte("1", "digital '1' 2");
        check_byte("8", "digital '8'");
        check_byte(":", "digital ':' 2");
        check_byte(" ", "digital space 4");
        check_byte(8'h30 + expected_ch18, "digital digit ch18");
        check_byte(8'h0D, "digital final CR");
        check_byte(8'h0A, "digital final LF");
    endtask
 
    task automatic verify_line(input logic [175:0] ch_bits, input logic expected_failsafe, input logic expected_ch17, input logic expected_ch18);
        logic [10:0] raw;
        logic [10:0] pwm;
        logic [4:0] chan_num;
        read_idx = 0;
        verify_prefix();
        for (int ch = 0; ch < 16; ch++) begin
            raw = ch_bits[ch*11 +: 11];
            pwm = expected_pwm(raw);
            chan_num = ch + 1;
            check_byte("C", $sformatf("ch%0d 'C'", ch));
            check_byte("H", $sformatf("ch%0d 'H'", ch));
            check_byte("A", $sformatf("ch%0d 'A'", ch));
            check_byte("N", $sformatf("ch%0d 'N' 1", ch));
            check_byte("N", $sformatf("ch%0d 'N' 2", ch));
            check_byte("E", $sformatf("ch%0d 'E'", ch));
            check_byte("L", $sformatf("ch%0d 'L'", ch));
            check_byte(" ", $sformatf("ch%0d space after CHANNEL", ch));
            if (chan_num >= 10) begin
                check_byte(8'h30 + (chan_num / 10), $sformatf("ch%0d tens digit of channel number", ch));
            end
            check_byte(8'h30 + (chan_num % 10), $sformatf("ch%0d units digit of channel number", ch));
            check_byte(":", $sformatf("ch%0d ':'", ch));
            check_byte(" ", $sformatf("ch%0d space after ':'", ch));
            check_byte(8'h30 + (pwm / 1000), $sformatf("ch%0d pwm thousands", ch));
            check_byte(8'h30 + ((pwm / 100) % 10), $sformatf("ch%0d pwm hundreds", ch));
            check_byte(8'h30 + ((pwm / 10) % 10), $sformatf("ch%0d pwm tens", ch));
            check_byte(8'h30 + (pwm % 10), $sformatf("ch%0d pwm units", ch));
            check_byte(8'h0D, $sformatf("ch%0d CR", ch));
            check_byte(8'h0A, $sformatf("ch%0d LF", ch));
        end
        verify_digital_lines(expected_ch17, expected_ch18);
        verify_failsafe_line(expected_failsafe);
    endtask
 
    task automatic wait_and_verify_failsafe_text(input logic expected_failsafe, input string label);
        logic [7:0] expected_seq [0:23];
        int i;
        int match_start;
        bit ok;
        bit found;
 
        expected_seq[0] = 8'h0D; expected_seq[1] = 8'h0A;
        expected_seq[2] = "F"; expected_seq[3] = "A"; expected_seq[4] = "I"; expected_seq[5] = "L";
        expected_seq[6] = "S"; expected_seq[7] = "A"; expected_seq[8] = "F"; expected_seq[9] = "E";
        expected_seq[10] = "_"; expected_seq[11] = "E"; expected_seq[12] = "N"; expected_seq[13] = "A";
        expected_seq[14] = "B"; expected_seq[15] = "L"; expected_seq[16] = "E"; expected_seq[17] = "D";
        expected_seq[18] = " "; expected_seq[19] = "="; expected_seq[20] = " ";
        expected_seq[21] = 8'h30 + expected_failsafe;
        expected_seq[22] = 8'h0D; expected_seq[23] = 8'h0A;
 
        repeat (INTERVAL_TICKS + 2 * REPORT_CYCLES_MARGIN) @(negedge clk);
 
        found = 1'b0;
        for (match_start = rx_count - 24; match_start >= 0 && !found; match_start--) begin
            ok = 1'b1;
            for (i = 0; i < 24; i++) begin
                if (rx_buffer[match_start + i] !== expected_seq[i]) ok = 1'b0;
            end
            if (ok) found = 1'b1;
        end
 
        test_count++;
        if (!found) begin
            error_count++;
            $display("[ERROR] %s: the FAILSAFE_ENABLED = %0b line was not found in the captured TTY stream", label, expected_failsafe);
        end
    endtask
 
    task automatic wait_and_verify_digital_text(input logic expected_ch17, input logic expected_ch18, input string label);
        logic [7:0] expected_seq [0:35];
        int i;
        int match_start;
        bit ok;
        bit found;
 
        expected_seq[0] = 8'h0D; expected_seq[1] = 8'h0A;
        expected_seq[2] = "D"; expected_seq[3] = "I"; expected_seq[4] = "G"; expected_seq[5] = "I";
        expected_seq[6] = "T"; expected_seq[7] = "A"; expected_seq[8] = "L"; expected_seq[9] = " ";
        expected_seq[10] = "C"; expected_seq[11] = "H"; expected_seq[12] = "1"; expected_seq[13] = "7";
        expected_seq[14] = ":"; expected_seq[15] = " ";
        expected_seq[16] = 8'h30 + expected_ch17;
        expected_seq[17] = 8'h0D; expected_seq[18] = 8'h0A;
        expected_seq[19] = "D"; expected_seq[20] = "I"; expected_seq[21] = "G"; expected_seq[22] = "I";
        expected_seq[23] = "T"; expected_seq[24] = "A"; expected_seq[25] = "L"; expected_seq[26] = " ";
        expected_seq[27] = "C"; expected_seq[28] = "H"; expected_seq[29] = "1"; expected_seq[30] = "8";
        expected_seq[31] = ":"; expected_seq[32] = " ";
        expected_seq[33] = 8'h30 + expected_ch18;
        expected_seq[34] = 8'h0D; expected_seq[35] = 8'h0A;
 
        repeat (INTERVAL_TICKS + 2 * REPORT_CYCLES_MARGIN) @(negedge clk);
 
        found = 1'b0;
        for (match_start = rx_count - 36; match_start >= 0 && !found; match_start--) begin
            ok = 1'b1;
            for (i = 0; i < 36; i++) begin
                if (rx_buffer[match_start + i] !== expected_seq[i]) ok = 1'b0;
            end
            if (ok) found = 1'b1;
        end
 
        test_count++;
        if (!found) begin
            error_count++;
            $display("[ERROR] %s: the DIGITAL CH17=%0b/CH18=%0b lines were not found in the captured TTY stream", label, expected_ch17, expected_ch18);
        end
    endtask
 
    initial begin
 
        clk = 1'b0;
        reset = 1'b1;
        sbus_rx_line = 1'b0; 
        reset_active_low_raw = 1'b0;
        dummy_sbus_rx_line = 1'b0;
        error_count = 0;
        test_count = 0;
 
        repeat (5) @(negedge clk);
        reset = 1'b0;
        repeat (5) @(negedge clk);
 
        begin
            logic [175:0] ch_bits;
            ch_bits = '0;
            for (int ch = 0; ch < 16; ch++) begin
                ch_bits[ch*11 +: 11] = 11'(100 + ch * 30);
            end
 
            send_sbus_frame(ch_bits, 8'h00);
 
            repeat (INTERVAL_TICKS + 45_000) @(negedge clk);
 
            test_count++;
            if (rx_count < 346) begin
                error_count++;
                $display("[ERROR] incomplete report on pc_tx_line: only %0d bytes received (expected at least 346)", rx_count);
            end
 
            verify_line(ch_bits, 1'b0, 1'b0, 1'b0);
        end
 
        begin
            logic [175:0] ch_bits_dig;
            ch_bits_dig = '0;
            for (int ch = 0; ch < 16; ch++) begin
                ch_bits_dig[ch*11 +: 11] = 11'(100 + ch * 30);
            end
 
            send_sbus_frame(ch_bits_dig, 8'b0000_0000); 
            test_count++;
            if (uutLink.sbus_digital_ch17 !== 1'b0 || uutLink.sbus_digital_ch18 !== 1'b0) begin
                error_count++;
                $display("[ERROR] digital ch17=0/ch18=0: actual ch17=%0b ch18=%0b", uutLink.sbus_digital_ch17, uutLink.sbus_digital_ch18);
            end
 
            send_sbus_frame(ch_bits_dig, 8'b0000_0001);
            test_count++;
            if (uutLink.sbus_digital_ch17 !== 1'b1 || uutLink.sbus_digital_ch18 !== 1'b0) begin
                error_count++;
                $display("[ERROR] digital ch17=1/ch18=0: actual ch17=%0b ch18=%0b", uutLink.sbus_digital_ch17, uutLink.sbus_digital_ch18);
            end
            wait_and_verify_digital_text(1'b1, 1'b0, "digital ch17=1/ch18=0 reflected in the TTY report");
 
            send_sbus_frame(ch_bits_dig, 8'b0000_0010); 
            test_count++;
            if (uutLink.sbus_digital_ch17 !== 1'b0 || uutLink.sbus_digital_ch18 !== 1'b1) begin
                error_count++;
                $display("[ERROR] digital ch17=0/ch18=1: actual ch17=%0b ch18=%0b", uutLink.sbus_digital_ch17, uutLink.sbus_digital_ch18);
            end
            wait_and_verify_digital_text(1'b0, 1'b1, "digital ch17=0/ch18=1 reflected in the TTY report");
 
            send_sbus_frame(ch_bits_dig, 8'b0000_0011);
            test_count++;
            if (uutLink.sbus_digital_ch17 !== 1'b1 || uutLink.sbus_digital_ch18 !== 1'b1) begin
                error_count++;
                $display("[ERROR] digital ch17=1/ch18=1: actual ch17=%0b ch18=%0b", uutLink.sbus_digital_ch17, uutLink.sbus_digital_ch18);
            end
            wait_and_verify_digital_text(1'b1, 1'b1, "digital ch17=1/ch18=1 reflected in the TTY report");
        end
 
        reset = 1'b1;
        @(negedge clk);
        reset = 1'b0;
        repeat (5) @(negedge clk);
        begin
            logic [175:0] ch_bits_fs;
            ch_bits_fs = '0;
            for (int ch = 0; ch < 16; ch++) begin
                ch_bits_fs[ch*11 +: 11] = 11'd992;
            end
 
            send_sbus_frame(ch_bits_fs, 8'h00);
            test_count++;
            if (uutLink.failsafe_active !== 1'b0) begin
                error_count++;
                $display("[ERROR] failsafe_active: expected=0 after a valid frame, actual=%0b", uutLink.failsafe_active);
            end
 
            repeat (FAILSAFE_TIMEOUT_TICKS + 50) @(negedge clk);
            test_count++;
            if (uutLink.failsafe_active !== 1'b1) begin
                error_count++;
                $display("[ERROR] failsafe_active: expected=1 after missing frames, actual=%0b", uutLink.failsafe_active);
            end
 
            send_sbus_frame(ch_bits_fs, 8'h00);
            test_count++;
            if (uutLink.failsafe_active !== 1'b1) begin
                error_count++;
                $display("[ERROR] failsafe_active: expected=1 after a single frame (RECOVERY_FRAMES=3), actual=%0b", uutLink.failsafe_active);
            end
 
            send_sbus_frame(ch_bits_fs, 8'h00);
            test_count++;
            if (uutLink.failsafe_active !== 1'b1) begin
                error_count++;
                $display("[ERROR] failsafe_active: expected=1 after the second consecutive frame, actual=%0b", uutLink.failsafe_active);
            end
 
            send_sbus_frame(ch_bits_fs, 8'h00);
            test_count++;
            if (uutLink.failsafe_active !== 1'b0) begin
                error_count++;
                $display("[ERROR] failsafe_active: expected=0 after the third consecutive frame, actual=%0b", uutLink.failsafe_active);
            end
        end
 
        begin
            logic [175:0] ch_bits_flag;
            ch_bits_flag = '0;
            for (int ch = 0; ch < 16; ch++) begin
                ch_bits_flag[ch*11 +: 11] = 11'd992;
            end
 
            send_sbus_frame(ch_bits_flag, 8'b0000_1000);
            test_count++;
            if (uutLink.failsafe_active !== 1'b1) begin
                error_count++;
                $display("[ERROR] failsafe_active: expected=1 on the sbus_failsafe protocol flag, actual=%0b", uutLink.failsafe_active);
            end
 
            wait_and_verify_failsafe_text(1'b1, "sbus_failsafe protocol flag reflected in the TTY report");
 
            send_sbus_frame(ch_bits_flag, 8'b0000_1000);
            test_count++;
            if (uutLink.failsafe_active !== 1'b1) begin
                error_count++;
                $display("[ERROR] failsafe_active: expected=1, the protocol flag persists, actual=%0b", uutLink.failsafe_active);
            end
 
            send_sbus_frame(ch_bits_flag, 8'h00);
            test_count++;
            if (uutLink.failsafe_active !== 1'b0) begin
                error_count++;
                $display("[ERROR] failsafe_active: expected=0 after a frame with clean flags, actual=%0b", uutLink.failsafe_active);
            end
 
            wait_and_verify_failsafe_text(1'b0, "cleared protocol flag reflected in the TTY report");
 
            send_sbus_frame(ch_bits_flag, 8'b0000_0100);
            test_count++;
            if (uutLink.failsafe_active !== 1'b1) begin
                error_count++;
                $display("[ERROR] failsafe_active: expected=1 on the sbus_frame_lost protocol flag, actual=%0b", uutLink.failsafe_active);
            end
 
            send_sbus_frame(ch_bits_flag, 8'h00);
            test_count++;
            if (uutLink.failsafe_active !== 1'b0) begin
                error_count++;
                $display("[ERROR] failsafe_active: expected=0 after a frame with clean flags (frame_lost), actual=%0b", uutLink.failsafe_active);
            end
        end
 
        reset = 1'b1;
        @(negedge clk);
        reset = 1'b0;
        repeat (5) @(negedge clk);
        begin
            logic [175:0] ch_bits_gate;
            ch_bits_gate = '0;
            for (int ch = 0; ch < 16; ch++) begin
                ch_bits_gate[ch*11 +: 11] = 11'd992;
            end
 
            for (int i = 0; i < 3; i++) begin
                send_sbus_frame(ch_bits_gate, 8'b0000_1000);
                test_count++;
                if (uutLink.failsafe_active !== 1'b0) begin
                    error_count++;
                    $display("[ERROR] gate has_ever_had_live_link: iteration %0d, failsafe-flagged frame before real link, expected=0 actual=%0b", i, uutLink.failsafe_active);
                end
            end
 
            repeat (FAILSAFE_TIMEOUT_TICKS * 3) @(negedge clk);
            test_count++;
            if (uutLink.failsafe_active !== 1'b0) begin
                error_count++;
                $display("[ERROR] gate has_ever_had_live_link: expected=0 after missing frames before real link, actual=%0b", uutLink.failsafe_active);
            end
 
            send_sbus_frame(ch_bits_gate, 8'h00);
            test_count++;
            if (uutLink.failsafe_active !== 1'b0) begin
                error_count++;
                $display("[ERROR] gate has_ever_had_live_link: expected=0 at the first frame with real content, actual=%0b", uutLink.failsafe_active);
            end
 
            wait_and_verify_failsafe_text(1'b0, "gate has_ever_had_live_link, final state reflected in the TTY report");
        end
 
        begin
            reset_active_low_raw = 1'b0;
            #1;
            test_count++;
            if (uutLink_i.reset_active_high !== 1'b1) begin
                error_count++;
                $display("[ERROR] RESET_ACTIVE_LOW=1, external reset=0 (asserted): internal reset_active_high expected=1 actual=%0b", uutLink_i.reset_active_high);
            end
 
            reset_active_low_raw = 1'b1; 
            #1;
            test_count++;
            if (uutLink_i.reset_active_high !== 1'b0) begin
                error_count++;
                $display("[ERROR] RESET_ACTIVE_LOW=1, external reset=1 (idle): internal reset_active_high expected=0 actual=%0b", uutLink_i.reset_active_high);
            end
 
            reset = 1'b1;
            #1;
            test_count++;
            if (uutLink.reset_active_high !== 1'b1) begin
                error_count++;
                $display("[ERROR] RESET_ACTIVE_LOW=0 (explicit), external reset=1 (asserted): internal reset_active_high expected=1 actual=%0b", uutLink.reset_active_high);
            end
 
            reset = 1'b0; 
            #1;
            test_count++;
            if (uutLink.reset_active_high !== 1'b0) begin
                error_count++;
                $display("[ERROR] RESET_ACTIVE_LOW=0 (explicit), external reset=0 (idle): internal reset_active_high expected=0 actual=%0b", uutLink.reset_active_high);
            end
        end
 
        $display("==========================================");
        $display("TEST MARKS: %0d/%0d passed", test_count - error_count, test_count);
        $display("==========================================");
 
        $finish;
    end
 
endmodule