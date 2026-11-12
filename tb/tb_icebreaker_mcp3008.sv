`timescale 1ns/1ps
module tb_icebreaker_mcp3008;
    /* verilator lint_off PROCASSINIT */
    logic clk_12m = 0;
    logic btn_n = 1;
    logic adc_miso = 0;
    wire adc_sclk, adc_mosi, adc_cs_n, led_r_n, led_g_n;
    logic [9:0] expected_adc = 10'h2D3;
    logic [31:0] command_word = 0;
    integer clock_count = 0;
    integer timeout_count = 0;
    /* verilator lint_on PROCASSINIT */

    always #41.667 clk_12m = ~clk_12m;

    spi_x_icebreaker_mcp3008 dut (.*);

    // Behavioral MCP3008 serial timing model: it drives DOUT on falling SCLK
    // edges. The 32-bit SPI-X command inserts seven leading zero clocks, then
    // Start/SGL/CH2:0. Null is followed by the 10-bit conversion result.
    /* verilator lint_off BLKSEQ */
    always @(negedge adc_cs_n) begin
        clock_count = 0;
        command_word = 0;
        adc_miso = 0;
    end
    always @(posedge adc_sclk) begin
        if (!adc_cs_n) begin
            clock_count = clock_count + 1;
            command_word = {command_word[30:0], adc_mosi};
        end
    end
    always @(negedge adc_sclk) begin
        if (!adc_cs_n && clock_count >= 14 && clock_count <= 23)
            adc_miso = expected_adc[23-clock_count];
        else
            adc_miso = 0;
    end
    always @(posedge adc_cs_n) begin
        if (clock_count != 0 && clock_count != 32)
            $fatal(1, "MCP3008 frame clock count=%0d expected 32", clock_count);
        if (clock_count == 32 && command_word !== 32'h01800000)
            $fatal(1, "MCP3008 command mismatch got=%h", command_word);
    end
    /* verilator lint_on BLKSEQ */

    initial begin
        #1 btn_n=0;
        repeat (4) @(negedge clk_12m);
        btn_n=1;
        while (({~led_r_n,~led_g_n} !== expected_adc[9:8]) && timeout_count<200000) begin
            @(negedge clk_12m);
            timeout_count=timeout_count+1;
        end
        if (timeout_count>=200000) $fatal(1, "ADC result was not displayed");
        if (dut.adc_code !== expected_adc)
            $fatal(1, "MCP3008 result extraction got=%h expected=%h", dut.adc_code, expected_adc);
        $display("PASS: iCEBreaker APB sequencer and MCP3008 32-bit SPI transaction");
        #100;
        $finish;
    end
endmodule
