`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07/28/2026 10:47:55 PM
// Design Name:
// Module Name: sbus_pwm_converter
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


module sbus_pwm_converter #(
    parameter int NUM_CHANNELS = 16
)(
    input logic [NUM_CHANNELS*11-1:0] raw_channels,
    output logic [NUM_CHANNELS*11-1:0] pwm_us_channels
);

    genvar i;
    generate
        for (i = 0; i < NUM_CHANNELS; i++) begin : gen_channel

            logic [13:0] mult5;
            logic [10:0] shifted;
            logic [11:0] pwm_us_ext;

            assign mult5 = raw_channels[i*11 +: 11] * 5;
            assign shifted = mult5[13:3];
            assign pwm_us_ext = {1'b0, shifted} + 12'd880;
            assign pwm_us_channels[i*11 +: 11] = (pwm_us_ext > 12'd2000) ? 11'd2000 : (pwm_us_ext < 12'd1000) ? 11'd1000 : pwm_us_ext[10:0];

        end
    endgenerate

endmodule