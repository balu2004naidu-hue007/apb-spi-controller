`default_nettype none
`timescale 1ns/1ps
module spi_master (
    input logic clk, input logic rst_n, input logic enable,
    input logic cpol, input logic cpha, input logic lsb_first,
    input logic [5:0] width_bits, input logic [1:0] cs_index,
    input logic [15:0] baud_div, input logic [15:0] transfer_len,
    input logic [31:0] tx_data, input logic tx_empty,
    output logic tx_pop,
    input logic miso, input logic loopback,
    output logic mosi, output logic sclk,
    output logic [3:0] cs_n,
    output logic [31:0] rx_data, output logic rx_push,
    output logic busy, output logic done, output logic underflow, output logic timeout
);
    logic [31:0] frame_tx, frame_rx;
    logic [5:0] bit_count;
    logic [15:0] divider;
    logic [5:0] edge_count;
    logic sample_edge;
    logic [5:0] safe_width;
    logic [4:0] selected_bit;
    logic last_sampled;
    logic waiting_next;
    logic [15:0] frames_left, wait_cycles;

    always @* begin
        safe_width = (width_bits == 8 || width_bits == 16 || width_bits == 32) ? width_bits : 8;
        sample_edge = cpha ? (edge_count[0] == 1'b1) : (edge_count[0] == 1'b0);
        selected_bit = lsb_first ? bit_count[4:0] : safe_width[4:0] - 5'd1 - bit_count[4:0];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_tx <= '0;
            frame_rx <= '0;
            bit_count <= '0;
            divider <= '0;
            edge_count <= '0;
            last_sampled <= 1'b0;
            tx_pop <= 1'b0;
            rx_push <= 1'b0;
            rx_data <= '0;
            busy <= 1'b0;
            done <= 1'b0;
            underflow <= 1'b0;
            timeout <= 1'b0;
            waiting_next <= 1'b0;
            frames_left <= 16'd1;
            wait_cycles <= 16'b0;
            mosi <= 1'b0;
            sclk <= 1'b0;
            cs_n <= 4'hF;
        end else begin
            tx_pop <= 1'b0;
            rx_push <= 1'b0;
            done <= 1'b0;
            underflow <= 1'b0;
            timeout <= 1'b0;
            if (!busy) begin
                sclk <= cpol;
                cs_n <= 4'hF;
                if (enable && !tx_empty) begin
                    frame_tx <= tx_data;
                    frame_rx <= '0;
                    bit_count <= '0;
                    edge_count <= '0;
                    last_sampled <= 1'b0;
                    divider <= (baud_div == 0) ? 16'd0 : baud_div - 1'b1;
                    tx_pop <= 1'b1;
                    busy <= 1'b1;
                    waiting_next <= 1'b0;
                    frames_left <= (transfer_len == 0) ? 16'd1 : transfer_len;
                    wait_cycles <= 16'b0;
                    cs_n <= 4'hF ^ (4'b0001 << cs_index);
                    mosi <= tx_data[lsb_first ? 5'd0 : safe_width[4:0] - 5'd1];
                end
            end else if (waiting_next) begin
                if (!tx_empty) begin
                    frame_tx <= tx_data;
                    frame_rx <= '0;
                    bit_count <= '0;
                    edge_count <= '0;
                    last_sampled <= 1'b0;
                    divider <= (baud_div == 0) ? 16'd0 : baud_div - 1'b1;
                    tx_pop <= 1'b1;
                    mosi <= tx_data[lsb_first ? 5'd0 : safe_width[4:0] - 5'd1];
                    waiting_next <= 1'b0;
                    wait_cycles <= 16'b0;
                end else if (wait_cycles == 16'hFFFF) begin
                    busy <= 1'b0;
                    waiting_next <= 1'b0;
                    cs_n <= 4'hF;
                    sclk <= cpol;
                    done <= 1'b1;
                    timeout <= 1'b1;
                end else begin
                    wait_cycles <= wait_cycles + 1'b1;
                end
            end else if (divider != 0) begin
                divider <= divider - 1'b1;
            end else begin
                divider <= (baud_div == 0) ? 16'd0 : baud_div - 1'b1;
                sclk <= ~sclk;

                if (sample_edge) begin
                    frame_rx[selected_bit] <= loopback ? mosi : miso;
                    if (bit_count == safe_width - 1'b1) begin
                        if (cpha) begin
                            rx_data <= frame_rx;
                            rx_data[selected_bit] <= loopback ? mosi : miso;
                            rx_push <= 1'b1;
                            if (frames_left > 1) begin
                                frames_left <= frames_left - 1'b1;
                                sclk <= cpol;
                                wait_cycles <= 16'b0;
                                if (!tx_empty) begin
                                    frame_tx <= tx_data;
                                    frame_rx <= '0;
                                    bit_count <= '0;
                                    edge_count <= '0;
                                    last_sampled <= 1'b0;
                                    divider <= (baud_div == 0) ? 16'd0 : baud_div - 1'b1;
                                    tx_pop <= 1'b1;
                                    mosi <= tx_data[lsb_first ? 5'd0 : safe_width[4:0] - 5'd1];
                                end else begin
                                    waiting_next <= 1'b1;
                                    underflow <= 1'b1;
                                end
                            end else begin
                                busy <= 1'b0;
                                cs_n <= 4'hF;
                                sclk <= cpol;
                                done <= 1'b1;
                            end
                        end else
                            last_sampled <= 1'b1;
                    end else begin
                        bit_count <= bit_count + 1'b1;
                    end
                end else if (!cpha) begin
                    if (last_sampled) begin
                        rx_push <= 1'b1;
                        done <= 1'b1;
                        rx_data <= frame_rx;
                        if (frames_left > 1) begin
                            frames_left <= frames_left - 1'b1;
                            sclk <= cpol;
                            wait_cycles <= 16'b0;
                            if (!tx_empty) begin
                                frame_tx <= tx_data;
                                frame_rx <= '0;
                                bit_count <= '0;
                                edge_count <= '0;
                                last_sampled <= 1'b0;
                                divider <= (baud_div == 0) ? 16'd0 : baud_div - 1'b1;
                                tx_pop <= 1'b1;
                                mosi <= tx_data[lsb_first ? 5'd0 : safe_width[4:0] - 5'd1];
                                done <= 1'b0;
                            end else begin
                                waiting_next <= 1'b1;
                                underflow <= 1'b1;
                                done <= 1'b0;
                            end
                        end else begin
                            busy <= 1'b0;
                            cs_n <= 4'hF;
                            sclk <= cpol;
                        end
                    end else
                        mosi <= frame_tx[selected_bit];
                end else begin
                    if (bit_count < safe_width)
                        mosi <= frame_tx[selected_bit];
                end

                edge_count <= edge_count + 1'b1;
            end
        end
    end
endmodule
`default_nettype wire
