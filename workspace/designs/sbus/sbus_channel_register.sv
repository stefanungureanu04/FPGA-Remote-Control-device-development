`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07/28/2026 05:32:14 PM
// Design Name:
// Module Name: sbus_channel_register
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


module sbus_channel_register (
    input logic clk,
    input logic reset,

    input logic sbus_frame_valid,
    input logic [175:0] sbus_channels_in,
    
    output logic [175:0] sbus_channels_held
);

    always_ff @(posedge clk) begin
        if (reset) begin
            sbus_channels_held <= '0;
        end
        else if (sbus_frame_valid) begin
            sbus_channels_held <= sbus_channels_in;
        end
    end

endmodule
