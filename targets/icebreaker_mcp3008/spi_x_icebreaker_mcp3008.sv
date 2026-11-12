`default_nettype none
`timescale 1ns/1ps
module spi_x_icebreaker_mcp3008 (
    input  logic clk_12m,
    input  logic btn_n,
    input  logic adc_miso,
    output logic adc_sclk,
    output logic adc_mosi,
    output logic adc_cs_n,
    output logic led_r_n,
    output logic led_g_n
);
    localparam logic [7:0] A_CTRL=8'h00, A_STATUS=8'h04, A_BAUD=8'h08,
        A_CONFIG=8'h0C, A_TX=8'h10, A_RX=8'h14,
        A_IEN=8'h18, A_IST=8'h1C;
    typedef enum logic [4:0] {
        RESET_WAIT, CTRL_SETUP, CTRL_ACCESS, CONFIG_SETUP, CONFIG_ACCESS, BAUD_SETUP, BAUD_ACCESS,
        IEN_SETUP, IEN_ACCESS, TX_SETUP, TX_ACCESS,
        STATUS_SETUP, STATUS_ACCESS, RX_SETUP, RX_ACCESS,
        CLEAR_SETUP, CLEAR_ACCESS, SAMPLE_GAP
    } state_t;

    state_t state;
    logic psel, penable, pwrite;
    logic [7:0] paddr;
    logic [31:0] pwdata;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] prdata;
    /* verilator lint_on UNUSEDSIGNAL */
    logic pready, pslverr, irq;
    logic [3:0] cs_n;
    logic sclk_out, mosi_out;
    logic [15:0] gap_counter;
    logic [9:0] adc_code;

    always_comb begin
        psel = 1'b0;
        penable = 1'b0;
        pwrite = 1'b0;
        paddr = 8'h00;
        pwdata = 32'b0;
        case (state)
            CTRL_SETUP, CTRL_ACCESS: begin
                psel=1'b1; pwrite=1'b1; paddr=A_CTRL; pwdata=32'h00000003;
                penable=(state == CTRL_ACCESS);
            end
            CONFIG_SETUP, CONFIG_ACCESS: begin
                psel=1'b1; pwrite=1'b1; paddr=A_CONFIG; pwdata=32'h00000010;
                penable=(state == CONFIG_ACCESS);
            end
            BAUD_SETUP, BAUD_ACCESS: begin
                psel=1'b1; pwrite=1'b1; paddr=A_BAUD; pwdata=32'd5;
                penable=(state == BAUD_ACCESS);
            end
            IEN_SETUP, IEN_ACCESS: begin
                psel=1'b1; pwrite=1'b1; paddr=A_IEN; pwdata=32'd1;
                penable=(state == IEN_ACCESS);
            end
            TX_SETUP, TX_ACCESS: begin
                psel=1'b1; pwrite=1'b1; paddr=A_TX; pwdata=32'h01800000;
                penable=(state == TX_ACCESS);
            end
            STATUS_SETUP, STATUS_ACCESS: begin
                psel=1'b1; paddr=A_STATUS;
                penable=(state == STATUS_ACCESS);
            end
            RX_SETUP, RX_ACCESS: begin
                psel=1'b1; paddr=A_RX;
                penable=(state == RX_ACCESS);
            end
            CLEAR_SETUP, CLEAR_ACCESS: begin
                psel=1'b1; pwrite=1'b1; paddr=A_IST; pwdata=32'h01;
                penable=(state == CLEAR_ACCESS);
            end
            default: begin end
        endcase
    end

    always_ff @(posedge clk_12m or negedge btn_n) begin
        if (!btn_n) begin
            state <= RESET_WAIT;
            gap_counter <= '0;
            adc_code <= '0;
        end else begin
            case (state)
                RESET_WAIT: state <= CTRL_SETUP;
                CTRL_SETUP: state <= CTRL_ACCESS;
                CTRL_ACCESS: state <= CONFIG_SETUP;
                CONFIG_SETUP: state <= CONFIG_ACCESS;
                CONFIG_ACCESS: state <= BAUD_SETUP;
                BAUD_SETUP: state <= BAUD_ACCESS;
                BAUD_ACCESS: state <= IEN_SETUP;
                IEN_SETUP: state <= IEN_ACCESS;
                IEN_ACCESS: state <= TX_SETUP;
                TX_SETUP: state <= TX_ACCESS;
                TX_ACCESS: state <= STATUS_SETUP;
                STATUS_SETUP: state <= STATUS_ACCESS;
                STATUS_ACCESS: begin
                    if (irq) state <= RX_SETUP;
                    else state <= STATUS_SETUP;
                end
                RX_SETUP: state <= RX_ACCESS;
                RX_ACCESS: begin
                    adc_code <= prdata[17:8];
                    state <= CLEAR_SETUP;
                end
                CLEAR_SETUP: state <= CLEAR_ACCESS;
                CLEAR_ACCESS: begin
                    gap_counter <= 16'd16;
                    state <= SAMPLE_GAP;
                end
                SAMPLE_GAP: begin
                    if (gap_counter == 0) state <= TX_SETUP;
                    else gap_counter <= gap_counter - 1'b1;
                end
                default: state <= RESET_WAIT;
            endcase
        end
    end

    spi_x_top u_spi_x (
        .pclk(clk_12m), .presetn(btn_n),
        .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr), .pwdata(pwdata),
        .pready(pready), .pslverr(pslverr), .prdata(prdata),
        .spi_sclk_in(1'b0), .spi_mosi_in(1'b0), .spi_miso_in(adc_miso),
        .spi_sclk_out(sclk_out), .spi_mosi_out(mosi_out),
        /* verilator lint_off PINCONNECTEMPTY */
        .spi_miso_out(), .spi_miso_oe(),
        .spi_cs_in_n(1'b1), .spi_cs_out_n(cs_n), .irq(irq)
    );

    assign adc_sclk = sclk_out;
    assign adc_mosi = mosi_out;
    assign adc_cs_n = cs_n[0];
    // The iCEBreaker user LEDs are active-low. Show the two most significant
    // conversion bits; the full 10-bit result remains in adc_code for probes.
    assign led_r_n = ~adc_code[9];
    assign led_g_n = ~adc_code[8];

`ifndef SYNTHESIS
    /* verilator lint_off SYNCASYNCNET */
    always_ff @(posedge clk_12m) begin
        if (btn_n) begin
            assert(pready) else $error("APB sequencer requires fixed-latency PREADY");
            assert(!pslverr) else $error("target APB sequencer accessed an invalid register");
            assert(cs_n[3:1] == 3'b111) else $error("unexpected chip-select output asserted");
        end
    end
    /* verilator lint_on SYNCASYNCNET */
`endif
endmodule
`default_nettype wire
