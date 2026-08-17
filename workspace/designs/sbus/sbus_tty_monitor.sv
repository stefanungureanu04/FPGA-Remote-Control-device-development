`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07/28/2026 05:48:40 PM
// Design Name:
// Module Name: sbus_tty_monitor
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


module sbus_tty_monitor #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int PC_BAUD_RATE = 115_200,
    parameter int UPDATE_INTERVAL_MS = 100,
    parameter int FAILSAFE_TIMEOUT_MS = 200,
    parameter int FAILSAFE_RECOVERY_FRAMES = 3,
    parameter bit RESET_ACTIVE_LOW = 1'b1
)(
    input logic clk,
    input logic reset,
 
    input logic sbus_rx_line,
    output logic pc_tx_line
);
 
    logic reset_active_high;
    logic failsafe_active;
 
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
 
    logic [7:0] pc_uart_tx_data;
    logic pc_uart_tx_start;
    logic pc_uart_tx_busy;
 
    localparam int INTERVAL_TICKS = (CLK_FREQ_HZ / 1000) * UPDATE_INTERVAL_MS;
    localparam int INTERVAL_CNT_WIDTH = $clog2(INTERVAL_TICKS);
 
    logic [INTERVAL_CNT_WIDTH-1:0] interval_cnt;
    logic trigger;
 
    always_ff @(posedge clk) begin
        if (reset_active_high) begin
            interval_cnt <= '0;
            trigger <= 1'b0;
        end
        else if (interval_cnt == INTERVAL_TICKS - 1) begin
            interval_cnt <= '0;
            trigger <= 1'b1;
        end
        else begin
            interval_cnt <= interval_cnt + 1'b1;
            trigger <= 1'b0;
        end
    end
 
    typedef enum logic [1:0] {
        STATE_IDLE,
        STATE_ASSERT_START,
        STATE_WAIT_BUSY_HIGH,
        STATE_WAIT_BUSY_LOW
    } state_e;
 
    typedef enum logic [2:0] {
        PHASE_PREFIX,
        PHASE_CHANNELS,
        PHASE_DIGITAL,
        PHASE_FAILSAFE
    } phase_e;
 
    localparam int FAILSAFE_FIELD_COUNT = 24;
    localparam int DIGITAL_FIELD_COUNT = 36;
 
    state_e state;
    phase_e phase;
    logic first_report_done;
 
    logic [2:0] prefix_idx;
    logic [2:0] prefix_len;
 
    assign prefix_len = first_report_done ? 3'd3 : 3'd7;
 
    logic [7:0] prefix_byte;

    always_comb begin
        if (first_report_done) begin
            unique case (prefix_idx)
                3'd0: prefix_byte = 8'h1B;
                3'd1: prefix_byte = "[";
                3'd2: prefix_byte = "H";
                default: prefix_byte = 8'h20;
            endcase
        end
        else begin
            unique case (prefix_idx)
                3'd0: prefix_byte = 8'h1B;
                3'd1: prefix_byte = "[";
                3'd2: prefix_byte = "2";
                3'd3: prefix_byte = "J";
                3'd4: prefix_byte = 8'h1B;
                3'd5: prefix_byte = "[";
                3'd6: prefix_byte = "H";
                default: prefix_byte = 8'h20;
            endcase
        end
    end
 
    logic [3:0] chan_idx;
    logic [5:0] field_idx;
    logic [4:0] field_count;
    logic is_two_digit;
 
    assign is_two_digit = (chan_idx >= 4'd9);
    assign field_count = is_two_digit ? 5'd18 : 5'd17;
 
    logic [10:0] pwm_us;
 
    assign pwm_us = pwm_us_all[chan_idx*11 +: 11];
 
    logic [3:0] pwm_thousands;
    logic [9:0] pwm_rem1;
    logic [3:0] pwm_hundreds;
    logic [6:0] pwm_rem2;
    logic [3:0] pwm_tens;
    logic [3:0] pwm_units;
 
    assign pwm_thousands = pwm_us / 11'd1000;
    assign pwm_rem1 = pwm_us % 11'd1000;
    assign pwm_hundreds = pwm_rem1 / 10'd100;
    assign pwm_rem2 = pwm_rem1 % 10'd100;
    assign pwm_tens = pwm_rem2 / 7'd10;
    assign pwm_units = pwm_rem2 % 7'd10;
 
    logic [4:0] chan_num;
    logic [3:0] chan_tens;
    logic [3:0] chan_units;
 
    assign chan_num = chan_idx + 5'd1;
    assign chan_tens = chan_num / 5'd10;
    assign chan_units = chan_num % 5'd10;
 
    logic [4:0] var_idx;
    logic [7:0] channel_byte;
    
    assign var_idx = field_idx - 5'd8;

    always_comb begin
        if (field_idx < 5'd8) begin
            unique case (field_idx)
                5'd0: channel_byte = "C";
                5'd1: channel_byte = "H";
                5'd2: channel_byte = "A";
                5'd3: channel_byte = "N";
                5'd4: channel_byte = "N";
                5'd5: channel_byte = "E";
                5'd6: channel_byte = "L";
                5'd7: channel_byte = " ";
                default: channel_byte = " ";
            endcase
        end
        else if (is_two_digit) begin
            unique case (var_idx)
                5'd0: channel_byte = 8'h30 + chan_tens;
                5'd1: channel_byte = 8'h30 + chan_units;
                5'd2: channel_byte = ":";
                5'd3: channel_byte = " ";
                5'd4: channel_byte = 8'h30 + pwm_thousands;
                5'd5: channel_byte = 8'h30 + pwm_hundreds;
                5'd6: channel_byte = 8'h30 + pwm_tens;
                5'd7: channel_byte = 8'h30 + pwm_units;
                5'd8: channel_byte = 8'h0D;
                5'd9: channel_byte = 8'h0A;
                default: channel_byte = " ";
            endcase
        end
        else begin
            unique case (var_idx)
                5'd0: channel_byte = 8'h30 + chan_units;
                5'd1: channel_byte = ":";
                5'd2: channel_byte = " ";
                5'd3: channel_byte = 8'h30 + pwm_thousands;
                5'd4: channel_byte = 8'h30 + pwm_hundreds;
                5'd5: channel_byte = 8'h30 + pwm_tens;
                5'd6: channel_byte = 8'h30 + pwm_units;
                5'd7: channel_byte = 8'h0D;
                5'd8: channel_byte = 8'h0A;
                default: channel_byte = " ";
            endcase
        end
    end
 
    logic [7:0] failsafe_byte;
 
    always_comb begin
        unique case (field_idx)
            5'd0: failsafe_byte = 8'h0D;
            5'd1: failsafe_byte = 8'h0A;
            5'd2: failsafe_byte = "F";
            5'd3: failsafe_byte = "A";
            5'd4: failsafe_byte = "I";
            5'd5: failsafe_byte = "L";
            5'd6: failsafe_byte = "S";
            5'd7: failsafe_byte = "A";
            5'd8: failsafe_byte = "F";
            5'd9: failsafe_byte = "E";
            5'd10: failsafe_byte = "_";
            5'd11: failsafe_byte = "E";
            5'd12: failsafe_byte = "N";
            5'd13: failsafe_byte = "A";
            5'd14: failsafe_byte = "B";
            5'd15: failsafe_byte = "L";
            5'd16: failsafe_byte = "E";
            5'd17: failsafe_byte = "D";
            5'd18: failsafe_byte = " ";
            5'd19: failsafe_byte = "=";
            5'd20: failsafe_byte = " ";
            5'd21: failsafe_byte = 8'h30 + failsafe_active;
            5'd22: failsafe_byte = 8'h0D;
            5'd23: failsafe_byte = 8'h0A;
            default: failsafe_byte = " ";
        endcase
    end
 
    logic [7:0] digital_byte;
 
    always_comb begin
        unique case (field_idx)
            6'd0: digital_byte = 8'h0D;
            6'd1: digital_byte = 8'h0A;
            6'd2: digital_byte = "D";
            6'd3: digital_byte = "I";
            6'd4: digital_byte = "G";
            6'd5: digital_byte = "I";
            6'd6: digital_byte = "T";
            6'd7: digital_byte = "A";
            6'd8: digital_byte = "L";
            6'd9: digital_byte = " ";
            6'd10: digital_byte = "C";
            6'd11: digital_byte = "H";
            6'd12: digital_byte = "1";
            6'd13: digital_byte = "7";
            6'd14: digital_byte = ":";
            6'd15: digital_byte = " ";
            6'd16: digital_byte = 8'h30 + sbus_digital_ch17;
            6'd17: digital_byte = 8'h0D;
            6'd18: digital_byte = 8'h0A;
            6'd19: digital_byte = "D";
            6'd20: digital_byte = "I";
            6'd21: digital_byte = "G";
            6'd22: digital_byte = "I";
            6'd23: digital_byte = "T";
            6'd24: digital_byte = "A";
            6'd25: digital_byte = "L";
            6'd26: digital_byte = " ";
            6'd27: digital_byte = "C";
            6'd28: digital_byte = "H";
            6'd29: digital_byte = "1";
            6'd30: digital_byte = "8";
            6'd31: digital_byte = ":";
            6'd32: digital_byte = " ";
            6'd33: digital_byte = 8'h30 + sbus_digital_ch18;
            6'd34: digital_byte = 8'h0D;
            6'd35: digital_byte = 8'h0A;
            default: digital_byte = " ";
        endcase
    end
 
    always_comb begin
        unique case (phase)
            PHASE_PREFIX: pc_uart_tx_data = prefix_byte;
            PHASE_CHANNELS: pc_uart_tx_data = channel_byte;
            PHASE_FAILSAFE: pc_uart_tx_data = failsafe_byte;
            PHASE_DIGITAL: pc_uart_tx_data = digital_byte;
            default: pc_uart_tx_data = 8'h20;
        endcase
    end
 
    always_ff @(posedge clk) begin
 
        if (reset_active_high) begin
            state <= STATE_IDLE;
            phase <= PHASE_PREFIX;
            prefix_idx <= '0;
            chan_idx <= '0;
            field_idx <= '0;
            pc_uart_tx_start <= 1'b0;
            first_report_done <= 1'b0;
        end
        else begin
 
            unique case (state)
 
                STATE_IDLE: begin
                    pc_uart_tx_start <= 1'b0;
                    if (trigger) begin
                        phase <= PHASE_PREFIX;
                        prefix_idx <= '0;
                        chan_idx <= '0;
                        field_idx <= '0;
                        state <= STATE_ASSERT_START;
                    end
                end
 
                STATE_ASSERT_START: begin
                    if (!pc_uart_tx_busy) begin
                        pc_uart_tx_start <= 1'b1;
                        state <= STATE_WAIT_BUSY_HIGH;
                    end
                end
 
                STATE_WAIT_BUSY_HIGH: begin
                    pc_uart_tx_start <= 1'b0;
                    if (pc_uart_tx_busy) begin
                        state <= STATE_WAIT_BUSY_LOW;
                    end
                end
 
                STATE_WAIT_BUSY_LOW: begin
                    if (!pc_uart_tx_busy) begin
 
                        if (phase == PHASE_PREFIX) begin
                            if (prefix_idx == prefix_len - 1'b1) begin
                                phase <= PHASE_CHANNELS;
                                first_report_done <= 1'b1;
                                chan_idx <= '0;
                                field_idx <= '0;
                                state <= STATE_ASSERT_START;
                            end
                            else begin
                                prefix_idx <= prefix_idx + 1'b1;
                                state <= STATE_ASSERT_START;
                            end
                        end
                        else if (phase == PHASE_CHANNELS) begin
                            if (field_idx == field_count - 1) begin
                                field_idx <= '0;
                                if (chan_idx == 4'd15) begin
                                    phase <= PHASE_DIGITAL;
                                    state <= STATE_ASSERT_START;
                                end
                                else begin
                                    chan_idx <= chan_idx + 1'b1;
                                    state <= STATE_ASSERT_START;
                                end
                            end
                            else begin
                                field_idx <= field_idx + 1'b1;
                                state <= STATE_ASSERT_START;
                            end
                        end
                        else if (phase == PHASE_DIGITAL) begin
                            if (field_idx == DIGITAL_FIELD_COUNT - 1) begin
                                field_idx <= '0;
                                phase <= PHASE_FAILSAFE;
                                state <= STATE_ASSERT_START;
                            end
                            else begin
                                field_idx <= field_idx + 1'b1;
                                state <= STATE_ASSERT_START;
                            end
                        end
                        else begin
                            if (field_idx == FAILSAFE_FIELD_COUNT - 1) begin
                                field_idx <= '0;
                                chan_idx <= '0;
                                state <= STATE_IDLE;
                            end
                            else begin
                                field_idx <= field_idx + 1'b1;
                                state <= STATE_ASSERT_START;
                            end
                        end
                    end
                end
 
                default: state <= STATE_IDLE;
 
            endcase
        end
    end
 
    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(PC_BAUD_RATE),
        .DATA_BITS(8),
        .PARITY_TYPE("NONE"),
        .STOP_BITS(1),
        .INVERT_LINE(1'b0)
    ) uartTx (
        .clk(clk),
        .reset(reset_active_high),
        .uart_tx_start(pc_uart_tx_start),
        .uart_tx_data(pc_uart_tx_data),
        .uart_tx_line(pc_tx_line),
        .uart_tx_busy(pc_uart_tx_busy)
    );
 
endmodule


