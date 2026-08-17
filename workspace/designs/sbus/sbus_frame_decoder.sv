`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07/28/2026 05:13:28 PM
// Design Name:
// Module Name: sbus_frame_decoder
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


module sbus_frame_decoder (
    input logic clk,
    input logic reset,

    input logic [7:0] uart_rx_data,
    input logic uart_rx_frame_ready,
    input logic uart_rx_parity_err,
    input logic uart_rx_frame_err,

    output logic [175:0] sbus_channels,
    output logic sbus_digital_ch17,
    output logic sbus_digital_ch18,
    output logic sbus_frame_lost,
    output logic sbus_failsafe,
    output logic sbus_frame_valid,
    output logic sbus_frame_error
);

    localparam logic [7:0] SBUS_START_BYTE = 8'h0F;
    localparam logic [7:0] SBUS_END_BYTE = 8'h00;
    localparam int SBUS_PAYLOAD_BYTES = 22;

    typedef enum logic [1:0] {
        STATE_WAIT_START,
        STATE_PAYLOAD,
        STATE_FLAGS,
        STATE_WAIT_END
    } state_e;

    state_e state;

    logic [7:0] payload_buff [0:SBUS_PAYLOAD_BYTES-1];
    logic [4:0] payload_idx;
    logic [7:0] flags_byte;
    logic uart_byte_err;

    assign uart_byte_err = uart_rx_frame_err | uart_rx_parity_err;

    always_ff @(posedge clk) begin

        if (reset) begin
            state <= STATE_WAIT_START;
            payload_idx <= '0;
            flags_byte <= '0;
            sbus_frame_valid <= 1'b0;
            sbus_frame_error <= 1'b0;
        end
        else begin

            sbus_frame_valid <= 1'b0;
            sbus_frame_error <= 1'b0;

            if (uart_rx_frame_ready) begin

                if (uart_byte_err) begin
                    sbus_frame_error <= 1'b1;
                    state <= STATE_WAIT_START;
                end
                else begin

                    unique case (state)

                        STATE_WAIT_START: begin
                            if (uart_rx_data == SBUS_START_BYTE) begin
                                payload_idx <= '0;
                                state <= STATE_PAYLOAD;
                            end
                        end

                        STATE_PAYLOAD: begin
                            payload_buff[payload_idx] <= uart_rx_data;
                            if (payload_idx == SBUS_PAYLOAD_BYTES - 1) begin
                                state <= STATE_FLAGS;
                            end
                            else begin
                                payload_idx <= payload_idx + 1'b1;
                            end
                        end

                        STATE_FLAGS: begin
                            flags_byte <= uart_rx_data;
                            state <= STATE_WAIT_END;
                        end

                        STATE_WAIT_END: begin
                            if (uart_rx_data == SBUS_END_BYTE) begin
                                sbus_frame_valid <= 1'b1;
                            end
                            else begin
                                sbus_frame_error <= 1'b1;
                            end
                            state <= STATE_WAIT_START;
                        end

                        default: state <= STATE_WAIT_START;

                    endcase
                end
            end
        end
    end

    assign sbus_channels[0*11 +: 11] = {payload_buff[1][2:0], payload_buff[0]};
    assign sbus_channels[1*11 +: 11] = {payload_buff[2][5:0], payload_buff[1][7:3]};
    assign sbus_channels[2*11 +: 11] = {payload_buff[4][0], payload_buff[3], payload_buff[2][7:6]};
    assign sbus_channels[3*11 +: 11] = {payload_buff[5][3:0], payload_buff[4][7:1]};
    assign sbus_channels[4*11 +: 11] = {payload_buff[6][6:0], payload_buff[5][7:4]};
    assign sbus_channels[5*11 +: 11] = {payload_buff[8][1:0], payload_buff[7], payload_buff[6][7]};
    assign sbus_channels[6*11 +: 11] = {payload_buff[9][4:0], payload_buff[8][7:2]};
    assign sbus_channels[7*11 +: 11] = {payload_buff[10], payload_buff[9][7:5]};
    assign sbus_channels[8*11 +: 11] = {payload_buff[12][2:0], payload_buff[11]};
    assign sbus_channels[9*11 +: 11] = {payload_buff[13][5:0], payload_buff[12][7:3]};
    assign sbus_channels[10*11 +: 11] = {payload_buff[15][0], payload_buff[14], payload_buff[13][7:6]};
    assign sbus_channels[11*11 +: 11] = {payload_buff[16][3:0], payload_buff[15][7:1]};
    assign sbus_channels[12*11 +: 11] = {payload_buff[17][6:0], payload_buff[16][7:4]};
    assign sbus_channels[13*11 +: 11] = {payload_buff[19][1:0], payload_buff[18], payload_buff[17][7]};
    assign sbus_channels[14*11 +: 11] = {payload_buff[20][4:0], payload_buff[19][7:2]};
    assign sbus_channels[15*11 +: 11] = {payload_buff[21], payload_buff[20][7:5]};

    assign sbus_digital_ch17 = flags_byte[0];
    assign sbus_digital_ch18 = flags_byte[1];
    
    assign sbus_frame_lost = flags_byte[2];
    assign sbus_failsafe = flags_byte[3];

endmodule
