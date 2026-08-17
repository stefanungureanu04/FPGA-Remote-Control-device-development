`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07/28/2026 04:28:25 PM
// Design Name:
// Module Name: uart_tx
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


module uart_tx #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE = 115_200,
    parameter int DATA_BITS = 8,
    parameter string PARITY_TYPE = "NONE",
    parameter int STOP_BITS = 1,
    parameter bit INVERT_LINE = 1'b0
)(
    input logic clk,
    input logic reset,
    input logic uart_tx_start,
    input logic [DATA_BITS-1:0] uart_tx_data,

    output logic uart_tx_line,
    output logic uart_tx_busy
);

    localparam int TICK_DIV = CLK_FREQ_HZ / BAUD_RATE;
    localparam int TICK_DIV_WIDTH = $clog2(TICK_DIV) - 1;
    
    logic [TICK_DIV_WIDTH:0] tick_cnt;
    logic tick;

    typedef enum logic [2:0]{
        STATE_IDLE,
        STATE_START,
        STATE_DATA,
        STATE_PARITY,
        STATE_STOP
    } state_e;

    state_e state;

    always_ff @(posedge clk) begin
        if(reset) begin
            tick_cnt <= '0;
            tick <= 1'b0;
        end
        else if (state == STATE_IDLE && !uart_tx_start) begin
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

    logic [$clog2(DATA_BITS)-1:0] data_bit_idx;
    logic [DATA_BITS-1:0] data_buff;
    logic [1:0] stop_bit_cnt;
    logic parity_acc;
    logic tx_line;

    assign uart_tx_line = INVERT_LINE ? ~tx_line: tx_line;
    assign uart_tx_busy = (state != STATE_IDLE);

    always_ff @(posedge clk) begin
        
        if(reset) begin
            state <= STATE_IDLE;
            tx_line <= 1'b1;
            data_bit_idx <= '0;
            data_buff <= '0;
            parity_acc <= 1'b0;
            stop_bit_cnt <= '0;
        end
        else begin
            
            if(state == STATE_IDLE) begin
                tx_line <= 1'b1;
                if(uart_tx_start) begin
                    data_buff <= uart_tx_data;
                    parity_acc <= 1'b0;
                    data_bit_idx <= '0;
                    state <= STATE_START;
                end
            end
            else if (tick) begin
            
                unique case (state)

                    STATE_START: begin
                        tx_line <= 1'b0;
                        state <= STATE_DATA;
                    end

                    STATE_DATA: begin
                        tx_line <= data_buff[data_bit_idx];
                        parity_acc <= parity_acc ^ data_buff[data_bit_idx];
                        if(data_bit_idx == DATA_BITS - 1) begin
                            state <= (PARITY_TYPE == "NONE") ? STATE_STOP : STATE_PARITY;
                        end
                        else begin
                            data_bit_idx <= data_bit_idx + 1'b1;
                        end
                    end

                    STATE_PARITY: begin
                        tx_line <= (PARITY_TYPE == "EVEN") ? parity_acc : ~parity_acc;
                        stop_bit_cnt <= '0;
                        state <= STATE_STOP;
                    end

                    STATE_STOP: begin
                        tx_line <= 1'b1;
                        if(stop_bit_cnt == STOP_BITS - 1) begin
                            state <= STATE_IDLE;
                        end
                        else begin
                            stop_bit_cnt <= stop_bit_cnt + 1'b1;
                        end
                    end

                    default: state <= STATE_IDLE;

                endcase
            end
        end
    end


endmodule
