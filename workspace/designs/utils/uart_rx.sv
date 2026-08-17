`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/28/2026 04:28:09 PM
// Design Name: 
// Module Name: uart_rx
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


module uart_rx #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE = 115_200,
    parameter int DATA_BITS = 8,
    parameter string PARITY_TYPE  = "NONE",
    parameter int STOP_BITS = 1,
    parameter int OVERSAMPLE = 16,
    parameter bit INVERT_LINE = 1'b0
)(
    input logic clk,
    input logic reset,
    input logic uart_rx_line,

    output logic [DATA_BITS-1:0] uart_rx_data,
    output logic uart_rx_frame_ready,
    output logic uart_rx_parity_err,
    output logic uart_rx_frame_err
);

    localparam int TICK_DIV = CLK_FREQ_HZ / (BAUD_RATE * OVERSAMPLE);
    localparam int TICK_DIV_WIDTH = $clog2(TICK_DIV) - 1;

    logic [TICK_DIV_WIDTH:0] tick_cnt;
    logic tick;

    always_ff @(posedge clk) begin
        if (reset) begin
            tick_cnt <= '0;
            tick <= 1'b0;
        end
        else if (tick_cnt == TICK_DIV - 1) begin
            tick_cnt <= '0;
            tick <= 1'b1;
        end
        else begin
            tick_cnt <= tick_cnt + 1'b1;
            tick <= 1'b0;
        end
    end
 
    logic rx_sync0;
    logic rx_sync1;
    logic rx_line;
 
    always_ff @(posedge clk) begin
        rx_sync0 <= uart_rx_line;
        rx_sync1 <= rx_sync0;
    end

    assign rx_line = INVERT_LINE ? ~rx_sync1 : rx_sync1;

    typedef enum logic [2:0] {
        STATE_IDLE,
        STATE_START,
        STATE_DATA,
        STATE_PARITY,
        STATE_STOP,
        STATE_DONE
    } state_e;

    state_e state;

    logic [$clog2(OVERSAMPLE)-1:0] bit_tick_cnt;
    logic [$clog2(DATA_BITS)-1:0] data_bit_idx;
    logic [DATA_BITS-1:0] data_buff;
    logic [1:0] stop_bit_cnt;
    logic parity_acc;

    always_ff @(posedge clk) begin

        if (reset) begin
            state <= STATE_IDLE;
            uart_rx_frame_ready <= 1'b0;
            uart_rx_parity_err <= 1'b0;
            uart_rx_frame_err <= 1'b0;
            bit_tick_cnt <= '0;
            data_bit_idx <= '0;
            data_buff <= '0;
            parity_acc <= 1'b0;
            stop_bit_cnt <= '0;
            uart_rx_data <= '0;
        end 
        else begin

            uart_rx_frame_ready <= 1'b0;

            if (tick) begin
                
                unique case (state)
                    
                    STATE_IDLE: begin
                        uart_rx_parity_err <= 1'b0;
                        uart_rx_frame_err  <= 1'b0;
                        if (rx_line == 1'b0) begin
                            bit_tick_cnt <= '0;
                            state <= STATE_START;
                        end
                    end

                    STATE_START: begin
                        if (bit_tick_cnt == (OVERSAMPLE/2 - 1)) begin
                            if (rx_line == 1'b0) begin
                                bit_tick_cnt <= '0;
                                data_bit_idx <= '0;
                                parity_acc <= 1'b0;
                                state <= STATE_DATA;
                            end 
                            else begin
                                state <= STATE_IDLE;
                            end
                        end 
                        else begin
                            bit_tick_cnt <= bit_tick_cnt + 1'b1;
                        end
                    end

                    STATE_DATA: begin
                        if(bit_tick_cnt == OVERSAMPLE - 1) begin
                            bit_tick_cnt <= '0;
                            data_buff[data_bit_idx] <= rx_line;
                            parity_acc <= parity_acc ^ rx_line;
                            if(data_bit_idx == DATA_BITS - 1) begin
                                state <= (PARITY_TYPE == "NONE") ? STATE_STOP: STATE_PARITY;
                            end
                            else begin
                                data_bit_idx <= data_bit_idx + 1'b1;
                            end
                        end
                        else begin
                            bit_tick_cnt <= bit_tick_cnt + 1'b1;
                        end
                    end

                    STATE_PARITY: begin
                        if(bit_tick_cnt == OVERSAMPLE - 1) begin
                            bit_tick_cnt <= '0;
                            uart_rx_parity_err <= (PARITY_TYPE == "EVEN") ? (rx_line != parity_acc) : (rx_line != ~parity_acc);
                            stop_bit_cnt <= '0;
                            state <= STATE_STOP;
                        end
                        else begin
                            bit_tick_cnt <= bit_tick_cnt + 1'b1;
                        end
                    end

                    STATE_STOP: begin
                        if(bit_tick_cnt == OVERSAMPLE - 1) begin
                            bit_tick_cnt <= '0;
                            if(rx_line != 1'b1) begin
                                uart_rx_frame_err <= 1'b1;
                            end
                            if(stop_bit_cnt == STOP_BITS - 1) begin
                                state <= STATE_DONE;
                            end
                            else begin
                                stop_bit_cnt <= stop_bit_cnt + 1'b1;
                            end
                        end
                        else begin
                            bit_tick_cnt <= bit_tick_cnt + 1'b1;
                        end
                    end

                    STATE_DONE: begin
                        uart_rx_data <= data_buff;
                        uart_rx_frame_ready <= 1'b1;
                        state <= STATE_IDLE;
                    end

                    default: state <= STATE_IDLE;

                endcase
            end
        end
    end

endmodule
