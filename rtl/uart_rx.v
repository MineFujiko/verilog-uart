/*

Copyright (c) 2014 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`timescale 1ns / 1ps

/*
 * AXI4-Stream UART
 */
module uart_rx #
(
    parameter DATA_WIDTH = 8
)
(
    input  wire                   clk,
    input  wire                   rst,

    /*
     * AXI output
     */
    output wire [DATA_WIDTH-1:0]  output_axis_tdata,
    output wire                   output_axis_tvalid,
    input  wire                   output_axis_tready,

    /*
     * UART interface
     */
    input  wire                   rxd,

    /*
     * Status
     */
    output wire                   busy,
    output wire                   overrun_error,
    output wire                   frame_error,

    /*
     * Configuration
     */
    input  wire [15:0]            prescale

);

reg [DATA_WIDTH-1:0] output_axis_tdata_reg = 0;
reg output_axis_tvalid_reg = 0;

reg busy_reg = 0;
reg overrun_error_reg = 0;
reg frame_error_reg = 0;

reg [DATA_WIDTH-1:0] data_reg = 0;
reg [18:0] prescale_reg = 0;
reg [3:0] bit_cnt = 0;

assign output_axis_tdata = output_axis_tdata_reg;
assign output_axis_tvalid = output_axis_tvalid_reg;

assign busy = busy_reg;
assign overrun_error = overrun_error_reg;
assign frame_error = frame_error_reg;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        output_axis_tdata_reg <= 0;
        output_axis_tvalid_reg <= 0;
        prescale_reg <= 0;
        bit_cnt <= 0;
        busy_reg <= 0;
        overrun_error_reg <= 0;
        frame_error_reg <= 0;
    end else begin
        overrun_error_reg <= 0;
        frame_error_reg <= 0;

        if (output_axis_tvalid & output_axis_tready) begin
            output_axis_tvalid_reg <= 0;
        end

        if (prescale_reg > 0) begin
            prescale_reg <= prescale_reg - 1;
        end else if (bit_cnt > 0) begin
            if (bit_cnt > DATA_WIDTH+1) begin
                if (~rxd) begin
                    bit_cnt <= bit_cnt - 1;
                    prescale_reg <= (prescale << 3)-1;
                end else begin
                    bit_cnt <= 0;
                    prescale_reg <= 0;
                end
            end else if (bit_cnt > 1) begin
                bit_cnt <= bit_cnt - 1;
                prescale_reg <= (prescale << 3)-1;
                data_reg <= {rxd, data_reg[DATA_WIDTH-1:1]};
            end else if (bit_cnt == 1) begin
                bit_cnt <= bit_cnt - 1;
                if (rxd) begin
                    output_axis_tdata_reg <= data_reg;
                    output_axis_tvalid_reg <= 1;
                    overrun_error_reg <= output_axis_tvalid_reg;
                end else begin
                    frame_error_reg <= 1;
                end
            end
        end else begin
            busy_reg <= 0;
            if (~rxd) begin
                prescale_reg <= (prescale << 2)-2;
                bit_cnt <= DATA_WIDTH+2;
                data_reg <= 0;
                busy_reg <= 1;
            end
        end
    end
end

endmodule