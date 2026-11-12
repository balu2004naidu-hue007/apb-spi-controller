`default_nettype none
`timescale 1ns/1ps
module spi_slave (
    input logic rst_n, input logic event_reset_n, input logic sclk, input logic cs_n,
    input logic enable, input logic cpol, input logic cpha,
    input logic lsb_first, input logic [5:0] width_bits,
    input logic [31:0] tx_data, input logic tx_empty, input logic rx_full,
    output logic tx_pop, input logic mosi,
    output logic miso, output logic miso_oe,
    output logic [31:0] rx_data, output logic rx_push,
    output logic busy, output logic event_pending,
    output logic underflow_toggle, output logic rx_overflow_toggle
);
    logic sample_clk;
    logic [5:0] bit_count;
    logic [31:0] tx_frame, rx_shift;
    logic [5:0] width_safe;
    logic [4:0] rx_bit, tx_bit;
    logic [31:0] rx_complete;
    logic active_n;

    // CPOL/CPHA are programmed only while disabled. This selects the physical
    // SCLK edge that samples MOSI; integration must hold mode stable per frame.
    always @* begin
        active_n = rst_n && !cs_n;
        sample_clk = (cpol == cpha) ? sclk : ~sclk;
        width_safe = (width_bits == 8 || width_bits == 16 || width_bits == 32) ? width_bits : 8;
        rx_bit = (bit_count < width_safe) ?
            (lsb_first ? bit_count[4:0] : width_safe[4:0] - 5'd1 - bit_count[4:0]) : 5'd0;
        tx_bit = (bit_count < width_safe) ?
            (lsb_first ? bit_count[4:0] : width_safe[4:0] - 5'd1 - bit_count[4:0]) : 5'd0;
        rx_complete = rx_shift;
        rx_complete[rx_bit] = mosi;
        busy = !cs_n && enable;
        tx_pop = !cs_n && enable && (bit_count == 0) && !tx_empty;
        rx_push = !cs_n && enable && (bit_count == width_safe - 1'b1);
        rx_data = rx_complete;
        miso_oe = !cs_n && enable;
        if (bit_count == 0)
            miso = tx_empty ? 1'b0 : (lsb_first ? tx_data[0] : tx_data[width_safe[4:0] - 5'd1]);
        else
            miso = tx_frame[tx_bit];
    end

    always_ff @(posedge sample_clk or negedge active_n) begin
        if (!active_n) begin
            bit_count <= '0;
            tx_frame <= '0;
            rx_shift <= '0;
        end else if (enable && bit_count < width_safe) begin
            if (bit_count == 0) begin
                tx_frame <= tx_empty ? 32'b0 : tx_data;
            end
            rx_shift[rx_bit] <= mosi;
            bit_count <= bit_count + 1'b1;
        end
    end

    /* verilator lint_off SYNCASYNCNET */
    always_ff @(posedge sample_clk or negedge rst_n) begin
        if (!rst_n) underflow_toggle <= 1'b0;
        else if (active_n && enable && bit_count == 0 && tx_empty)
            underflow_toggle <= ~underflow_toggle;
    end

    always_ff @(posedge sample_clk or negedge rst_n) begin
        if (!rst_n) rx_overflow_toggle <= 1'b0;
        else if (active_n && enable && bit_count == width_safe - 1'b1 && rx_full)
            rx_overflow_toggle <= ~rx_overflow_toggle;
    end
    /* verilator lint_on SYNCASYNCNET */

    always_ff @(posedge sample_clk or negedge event_reset_n) begin
        if (!event_reset_n)
            event_pending <= 1'b0;
        else if (!cs_n && enable && bit_count == width_safe - 1'b1)
            event_pending <= 1'b1;
    end

`ifndef SYNTHESIS
    // Runtime invariants complement directed short/overlong-frame tests.
    /* verilator lint_off SYNCASYNCNET */
    always @(posedge sample_clk) begin
        if (active_n && enable) begin
            assert (bit_count <= width_safe)
                else $error("SPI slave bit counter exceeded frame width");
            if (rx_push)
                assert (bit_count == width_safe - 1'b1)
                    else $error("SPI slave RX push occurred outside final bit");
            if (bit_count >= width_safe)
                assert (!rx_push)
                    else $error("SPI slave accepted an overlong frame bit");
        end
    end
    /* verilator lint_on SYNCASYNCNET */
`endif
endmodule
`default_nettype wire
