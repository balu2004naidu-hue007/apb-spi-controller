`default_nettype none
`timescale 1ns/1ps
module spi_x_top (
    input logic pclk, input logic presetn,
    input logic psel, input logic penable, input logic pwrite,
    input logic [7:0] paddr, input logic [31:0] pwdata,
    output logic pready, output logic pslverr, output logic [31:0] prdata,
    input logic spi_sclk_in, input logic spi_mosi_in, input logic spi_miso_in,
    output logic spi_sclk_out, output logic spi_mosi_out,
    output logic spi_miso_out, output logic spi_miso_oe,
    input logic spi_cs_in_n, output logic [3:0] spi_cs_out_n,
    output logic irq
);
    localparam logic [7:0] A_CTRL=8'h00, A_STATUS=8'h04, A_CLK_DIV=8'h08,
        A_CONFIG=8'h0C, A_TX=8'h10, A_RX=8'h14, A_IEN=8'h18,
        A_IST=8'h1C, A_FIFO_CTRL=8'h20, A_CS_CTRL=8'h24,
        A_TRANSFER_LEN=8'h28, A_ERROR_STATUS=8'h2C;

    logic [1:0] ctrl;
    logic [7:0] config_reg;
    logic [15:0] clk_div, transfer_len;
    logic [1:0] cs_ctrl;
    logic [7:0] irq_enable, irq_status;
    logic [4:0] error_status;
    logic [31:0] tx_data_master, tx_data_slave, rx_data_master, rx_data_slave;
    logic [4:0] tx_level_master, tx_level_slave, rx_level_master, rx_level_slave;
    logic tx_full_master, tx_empty_master, tx_full_slave, tx_empty_slave;
    logic rx_full_master, rx_empty_master, rx_full_slave, rx_full_slave_pclk, rx_empty_slave;
    logic tx_wr, tx_pop_master, tx_pop_slave, rx_push_master, rx_push_slave, rx_pop;
    logic master_rx_push, slave_sample_clk;
    logic master_busy, master_done, master_underflow, master_timeout;
    logic slave_busy, slave_busy_pclk, slave_event_pending, slave_underflow_toggle, slave_rx_overflow_toggle;
    (* ASYNC_REG = "TRUE" *) logic slave_evt_q1, slave_evt_q2;
    (* ASYNC_REG = "TRUE" *) logic slave_underflow_q1, slave_underflow_q2;
    logic slave_underflow_q3, slave_underflow_pulse;
    (* ASYNC_REG = "TRUE" *) logic slave_overflow_q1, slave_overflow_q2;
    logic slave_overflow_q3, slave_overflow_pulse;
    (* ASYNC_REG = "TRUE" *) logic rx_full_slave_q1, rx_full_slave_q2;
    (* ASYNC_REG = "TRUE" *) logic tx_empty_slave_q1, tx_empty_slave_q2;
    (* ASYNC_REG = "TRUE" *) logic slave_busy_q1, slave_busy_q2;
    logic slave_event_ack;
    logic slave_ack_reset_n, slave_event_reset_n;
    logic master_mosi, master_sclk, master_miso;
    logic pclk_reset_n, slave_reset_n;
    logic [3:0] master_cs_n;
    logic slave_miso, slave_miso_oe, slave_rx_push;
    logic [31:0] master_rx_data, slave_rx_data;
    logic apb_access, apb_write, apb_read, address_error, config_error;
    logic [7:0] event_set, irq_status_read;
    logic [31:0] status_value;
    logic selected_master;
    logic selected_tx_full, selected_tx_empty, selected_rx_full, selected_rx_empty;
    logic [4:0] selected_tx_level, selected_rx_level;
    logic flush_master_tx, flush_master_rx, flush_slave_tx, flush_slave_rx;
    logic slave_tx_rd_reset_n, slave_rx_wr_reset_n;
    logic [5:0] width_bits;

    assign pready = 1'b1;
    assign apb_access = psel && penable;
    assign apb_write = apb_access && pwrite;
    assign apb_read = apb_access && !pwrite;
    assign selected_master = ctrl[1];
    assign selected_tx_full = selected_master ? tx_full_master : tx_full_slave;
    assign selected_tx_empty = selected_master ? tx_empty_master : tx_empty_slave_q2;
    assign selected_rx_full = selected_master ? rx_full_master : rx_full_slave_pclk;
    assign selected_rx_empty = selected_master ? rx_empty_master : rx_empty_slave;
    assign selected_tx_level = selected_master ? tx_level_master : tx_level_slave;
    assign selected_rx_level = selected_master ? rx_level_master : rx_level_slave;
    assign slave_underflow_pulse = slave_underflow_q2 ^ slave_underflow_q3;
    assign slave_overflow_pulse = slave_overflow_q2 ^ slave_overflow_q3;
    assign rx_full_slave_pclk = rx_full_slave_q2;
    assign slave_busy_pclk = slave_busy_q2;
    assign width_bits = (config_reg[4:3] == 2'b00) ? 6'd8 :
                        (config_reg[4:3] == 2'b01) ? 6'd16 : 6'd32;

    reset_sync u_pclk_reset (.clk(pclk), .arst_n(presetn), .srst_n(pclk_reset_n));
    reset_sync u_slave_reset (.clk(slave_sample_clk), .arst_n(presetn), .srst_n(slave_reset_n));
    reset_sync u_slave_ack_reset (
        .clk(slave_sample_clk), .arst_n(!slave_event_ack), .srst_n(slave_ack_reset_n)
    );
    assign slave_event_reset_n = slave_reset_n && slave_ack_reset_n;
    reset_sync u_slave_tx_rd_fifo_reset (
        .clk(slave_sample_clk), .arst_n(pclk_reset_n && !flush_slave_tx), .srst_n(slave_tx_rd_reset_n)
    );
    reset_sync u_slave_rx_wr_fifo_reset (
        .clk(slave_sample_clk), .arst_n(pclk_reset_n && !flush_slave_rx), .srst_n(slave_rx_wr_reset_n)
    );

    assign tx_wr = apb_write && (paddr == A_TX) && !selected_tx_full;
    assign rx_pop = apb_read && (paddr == A_RX) && !selected_rx_empty;

    always_comb begin
        address_error = (paddr[1:0] != 2'b00) ||
            !(paddr == A_CTRL || paddr == A_STATUS || paddr == A_CLK_DIV ||
              paddr == A_CONFIG || paddr == A_TX || paddr == A_RX ||
              paddr == A_IEN || paddr == A_IST || paddr == A_FIFO_CTRL ||
              paddr == A_CS_CTRL || paddr == A_TRANSFER_LEN || paddr == A_ERROR_STATUS);
        config_error = (apb_write && paddr == A_CTRL && (master_busy || slave_busy_pclk)) ||
            (apb_write && paddr == A_CONFIG &&
             (master_busy || slave_busy_pclk || pwdata[4:3] == 2'b11)) ||
            (apb_write && (paddr == A_CLK_DIV || paddr == A_CS_CTRL ||
                           paddr == A_TRANSFER_LEN || paddr == A_FIFO_CTRL) &&
             (master_busy || slave_busy_pclk));
        pslverr = apb_access && address_error;

        status_value = 32'b0;
        status_value[0] = selected_master ? master_busy : slave_busy_pclk;
        status_value[1] = selected_tx_full;
        status_value[2] = selected_tx_empty;
        status_value[3] = selected_rx_full;
        status_value[4] = selected_rx_empty;
        status_value[12:8] = selected_tx_level;
        status_value[20:16] = selected_rx_level;
        status_value[21] = irq;

        irq_status_read = irq_status;
        irq_status_read[1] = !selected_rx_empty;
        irq_status_read[2] = !selected_tx_full;

        prdata = 32'b0;
        if (psel && !pwrite) begin
            case (paddr)
                A_CTRL: prdata = {30'b0, ctrl};
                A_STATUS: prdata = status_value;
                A_CLK_DIV: prdata = {16'b0, clk_div};
                A_CONFIG: prdata = {24'b0, config_reg};
                A_RX: prdata = selected_rx_empty ? 32'b0 :
                    (selected_master ? rx_data_master : rx_data_slave);
                A_IEN: prdata = {24'b0, irq_enable};
                A_IST: prdata = {24'b0, irq_status_read};
                A_CS_CTRL: prdata = {30'b0, cs_ctrl};
                A_TRANSFER_LEN: prdata = {16'b0, transfer_len};
                A_ERROR_STATUS: prdata = {27'b0, error_status};
                default: prdata = 32'b0;
            endcase
        end

        event_set = 8'b0;
        event_set[0] = master_done | slave_evt_q2;
        event_set[1] = !selected_rx_empty;
        event_set[2] = !selected_tx_full;
        event_set[3] = (selected_master && master_rx_push && rx_full_master) || slave_overflow_pulse;
        event_set[4] = master_underflow | slave_underflow_pulse;
        event_set[5] = master_timeout;
        event_set[6] = config_error;
        event_set[7] = apb_write && paddr == A_TX && selected_tx_full;
    end

    always_ff @(posedge pclk or negedge pclk_reset_n) begin
        if (!pclk_reset_n) begin
            ctrl <= 2'b10;
            config_reg <= 8'b0;
            clk_div <= 16'd2;
            cs_ctrl <= 2'b0;
            transfer_len <= 16'd1;
            irq_enable <= 8'b0;
            irq_status <= 8'b0;
            error_status <= 5'b0;
            slave_evt_q1 <= 1'b0;
            slave_evt_q2 <= 1'b0;
            slave_underflow_q1 <= 1'b0;
            slave_underflow_q2 <= 1'b0;
            slave_underflow_q3 <= 1'b0;
            slave_overflow_q1 <= 1'b0;
            slave_overflow_q2 <= 1'b0;
            slave_overflow_q3 <= 1'b0;
            rx_full_slave_q1 <= 1'b0;
            rx_full_slave_q2 <= 1'b0;
            tx_empty_slave_q1 <= 1'b1;
            tx_empty_slave_q2 <= 1'b1;
            slave_busy_q1 <= 1'b0;
            slave_busy_q2 <= 1'b0;
            slave_event_ack <= 1'b0;
            flush_master_tx <= 1'b0;
            flush_master_rx <= 1'b0;
            flush_slave_tx <= 1'b0;
            flush_slave_rx <= 1'b0;
        end else begin
            slave_evt_q1 <= slave_event_pending;
            slave_evt_q2 <= slave_evt_q1;
            slave_underflow_q1 <= slave_underflow_toggle;
            slave_underflow_q2 <= slave_underflow_q1;
            slave_underflow_q3 <= slave_underflow_q2;
            slave_overflow_q1 <= slave_rx_overflow_toggle;
            slave_overflow_q2 <= slave_overflow_q1;
            slave_overflow_q3 <= slave_overflow_q2;
            rx_full_slave_q1 <= rx_full_slave;
            rx_full_slave_q2 <= rx_full_slave_q1;
            tx_empty_slave_q1 <= tx_empty_slave;
            tx_empty_slave_q2 <= tx_empty_slave_q1;
            slave_busy_q1 <= slave_busy;
            slave_busy_q2 <= slave_busy_q1;
            slave_event_ack <= slave_evt_q2;
            flush_master_tx <= 1'b0;
            flush_master_rx <= 1'b0;
            flush_slave_tx <= 1'b0;
            flush_slave_rx <= 1'b0;

            if (apb_write && paddr == A_CTRL && !config_error)
                ctrl <= pwdata[1:0];
            if (apb_write && paddr == A_CONFIG && !config_error)
                config_reg <= pwdata[7:0];
            if (apb_write && paddr == A_CLK_DIV && !config_error)
                clk_div <= pwdata[15:0];
            if (apb_write && paddr == A_CS_CTRL && !config_error)
                cs_ctrl <= pwdata[1:0];
            if (apb_write && paddr == A_TRANSFER_LEN && !config_error)
                transfer_len <= (pwdata[15:0] == 0) ? 16'd1 : pwdata[15:0];
            if (apb_write && paddr == A_IEN)
                irq_enable <= pwdata[7:0];

            if (apb_write && paddr == A_FIFO_CTRL && !config_error) begin
                if (selected_master) begin
                    flush_master_tx <= pwdata[0];
                    flush_master_rx <= pwdata[1];
                end else begin
                    flush_slave_tx <= pwdata[0];
                    flush_slave_rx <= pwdata[1];
                end
            end

            if (apb_write && paddr == A_IST)
                irq_status <= (irq_status & ~(pwdata[7:0] & 8'hF9)) | (event_set & 8'hF9);
            else
                irq_status <= irq_status | (event_set & 8'hF9);

            if (apb_write && paddr == A_ERROR_STATUS)
                error_status <= (error_status & ~pwdata[4:0]) |
                    {event_set[6], event_set[5], event_set[4], event_set[3], event_set[7]};
            else
                error_status <= error_status |
                    {event_set[6], event_set[5], event_set[4], event_set[3], event_set[7]};
        end
    end

    assign irq = |(irq_status_read & irq_enable);
    assign spi_sclk_out = selected_master ? master_sclk : 1'b0;
    assign spi_mosi_out = selected_master ? master_mosi : 1'b0;
    assign spi_cs_out_n = selected_master ? master_cs_n : 4'hF;
    assign spi_miso_out = selected_master ? master_miso : slave_miso;
    assign spi_miso_oe = selected_master ? 1'b0 : slave_miso_oe;

    /* verilator lint_off PINCONNECTEMPTY */
    sync_fifo #(.DATA_WIDTH(32), .ADDR_WIDTH(4)) u_tx_master (
        .clk(pclk), .rst_n(pclk_reset_n && !flush_master_tx),
        .wr_en(tx_wr && selected_master), .wr_data(pwdata),
        .full(tx_full_master), .wr_level(tx_level_master),
        .rd_en(tx_pop_master), .rd_data(tx_data_master), .empty(tx_empty_master), .rd_level()
    );
    sync_fifo #(.DATA_WIDTH(32), .ADDR_WIDTH(4)) u_rx_master (
        .clk(pclk), .rst_n(pclk_reset_n && !flush_master_rx),
        .wr_en(rx_push_master), .wr_data(master_rx_data),
        .full(rx_full_master), .wr_level(), .rd_en(rx_pop && selected_master),
        .rd_data(rx_data_master), .empty(rx_empty_master), .rd_level(rx_level_master)
    );
    async_fifo #(.DATA_WIDTH(32), .ADDR_WIDTH(4)) u_tx_slave (
        .wr_clk(pclk), .wr_rst_n(pclk_reset_n && !flush_slave_tx),
        .wr_en(tx_wr && !selected_master), .wr_data(pwdata),
        .full(tx_full_slave), .wr_level(tx_level_slave),
        .rd_clk(slave_sample_clk), .rd_rst_n(slave_tx_rd_reset_n),
        .rd_en(tx_pop_slave), .rd_data(tx_data_slave), .empty(tx_empty_slave), .rd_level()
    );
    async_fifo #(.DATA_WIDTH(32), .ADDR_WIDTH(4)) u_rx_slave (
        .wr_clk(slave_sample_clk), .wr_rst_n(slave_rx_wr_reset_n),
        .wr_en(rx_push_slave), .wr_data(slave_rx_data),
        .full(rx_full_slave), .wr_level(), .rd_clk(pclk),
        .rd_rst_n(pclk_reset_n && !flush_slave_rx), .rd_en(rx_pop && !selected_master),
        .rd_data(rx_data_slave), .empty(rx_empty_slave), .rd_level(rx_level_slave)
    );
    /* verilator lint_on PINCONNECTEMPTY */

    assign slave_sample_clk = (config_reg[0] == config_reg[1]) ? spi_sclk_in : ~spi_sclk_in;

    spi_master u_master (
        .clk(pclk), .rst_n(pclk_reset_n), .enable(ctrl[0] && selected_master),
        .cpol(config_reg[0]), .cpha(config_reg[1]), .lsb_first(config_reg[2]),
        .width_bits(width_bits), .cs_index(cs_ctrl), .baud_div(clk_div),
        .tx_data(tx_data_master), .tx_empty(tx_empty_master), .tx_pop(tx_pop_master),
        .miso(spi_miso_in), .loopback(config_reg[5]),
        .mosi(master_mosi), .sclk(master_sclk), .cs_n(master_cs_n),
        .rx_data(master_rx_data), .rx_push(master_rx_push), .busy(master_busy), .done(master_done),
        .transfer_len(transfer_len), .underflow(master_underflow), .timeout(master_timeout)
    );
    spi_slave u_slave (
        .rst_n(slave_reset_n), .sclk(spi_sclk_in), .cs_n(spi_cs_in_n), .enable(ctrl[0] && !selected_master),
        .cpol(config_reg[0]), .cpha(config_reg[1]), .lsb_first(config_reg[2]),
        .width_bits(width_bits), .tx_data(tx_data_slave), .tx_empty(tx_empty_slave),
        .rx_full(rx_full_slave),
        .tx_pop(tx_pop_slave), .mosi(spi_mosi_in), .miso(slave_miso), .miso_oe(slave_miso_oe),
        .rx_data(slave_rx_data), .rx_push(slave_rx_push), .busy(slave_busy),
        .event_pending(slave_event_pending), .event_reset_n(slave_event_reset_n),
        .underflow_toggle(slave_underflow_toggle), .rx_overflow_toggle(slave_rx_overflow_toggle)
    );
    assign master_miso = 1'b0;
    assign rx_push_master = master_rx_push && !rx_full_master;
    assign rx_push_slave = slave_rx_push && !rx_full_slave;

`ifndef SYNTHESIS
    always_comb begin
        if (pclk_reset_n) begin
            assert (pready) else $error("APB PREADY must remain asserted");
            assert (!pslverr || apb_access) else $error("PSLVERR outside APB access");
            assert (selected_tx_level <= 16 && selected_rx_level <= 16)
                else $error("FIFO level exceeded capacity");
        end
    end
`endif
endmodule
`default_nettype wire
