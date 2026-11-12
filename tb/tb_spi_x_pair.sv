`timescale 1ns/1ps
module tb_spi_x_pair;
    logic pclk;
    logic presetn = 0;
    initial begin pclk=0; forever #5 pclk=~pclk; end

    logic m_psel = 0, m_penable = 0, m_pwrite = 0;
    logic [7:0] m_paddr = 0;
    logic [31:0] m_pwdata = 0;
    wire m_pready, m_pslverr, m_irq;
    wire [31:0] m_prdata;
    wire m_sclk, m_mosi, m_miso, m_miso_oe;
    wire [3:0] m_cs_n;
    logic prime_clock = 0;
    logic prime_sclk = 0;
    wire sclk_link = prime_clock ? prime_sclk : m_sclk;

    logic s_psel = 0, s_penable = 0, s_pwrite = 0;
    logic [7:0] s_paddr = 0;
    logic [31:0] s_pwdata = 0;
    wire s_pready, s_pslverr, s_irq;
    wire [31:0] s_prdata;
    wire s_sclk_out, s_mosi_out;
    wire [3:0] s_cs_out_n;
    wire s_miso, s_miso_oe;
    logic [31:0] m_status, s_irq_status, m_rx, s_rx;
    integer timeout;

    spi_x_top master (
        .pclk(pclk), .presetn(presetn), .psel(m_psel), .penable(m_penable),
        .pwrite(m_pwrite), .paddr(m_paddr), .pwdata(m_pwdata), .pready(m_pready),
        .pslverr(m_pslverr), .prdata(m_prdata), .spi_sclk_in(1'b0),
        .spi_mosi_in(1'b0), .spi_miso_in(s_miso), .spi_sclk_out(m_sclk),
        .spi_mosi_out(m_mosi), .spi_miso_out(m_miso), .spi_miso_oe(m_miso_oe),
        .spi_cs_in_n(1'b1), .spi_cs_out_n(m_cs_n), .irq(m_irq)
    );

    spi_x_top slave (
        .pclk(pclk), .presetn(presetn), .psel(s_psel), .penable(s_penable),
        .pwrite(s_pwrite), .paddr(s_paddr), .pwdata(s_pwdata), .pready(s_pready),
        .pslverr(s_pslverr), .prdata(s_prdata), .spi_sclk_in(sclk_link),
        .spi_mosi_in(m_mosi), .spi_miso_in(1'b0), .spi_sclk_out(s_sclk_out),
        .spi_mosi_out(s_mosi_out), .spi_miso_out(s_miso), .spi_miso_oe(s_miso_oe),
        .spi_cs_in_n(m_cs_n[0]), .spi_cs_out_n(s_cs_out_n), .irq(s_irq)
    );

    task automatic master_write(input logic [7:0] addr, input logic [31:0] data);
        begin
            @(negedge pclk); m_psel=1; m_penable=0; m_pwrite=1; m_paddr=addr; m_pwdata=data;
            @(negedge pclk); m_penable=1;
            @(posedge pclk); if (!m_pready || m_pslverr) $fatal(1, "master APB write failed at %h", addr);
            @(negedge pclk); m_psel=0; m_penable=0; m_pwrite=0;
        end
    endtask

    task automatic master_read(input logic [7:0] addr, output logic [31:0] data);
        begin
            @(negedge pclk); m_psel=1; m_penable=0; m_pwrite=0; m_paddr=addr;
            @(negedge pclk); m_penable=1;
            @(posedge pclk); if (!m_pready || m_pslverr) $fatal(1, "master APB read failed at %h", addr); data=m_prdata;
            @(negedge pclk); m_psel=0; m_penable=0;
        end
    endtask

    task automatic slave_write(input logic [7:0] addr, input logic [31:0] data);
        begin
            @(negedge pclk); s_psel=1; s_penable=0; s_pwrite=1; s_paddr=addr; s_pwdata=data;
            @(negedge pclk); s_penable=1;
            @(posedge pclk); if (!s_pready || s_pslverr) $fatal(1, "slave APB write failed at %h", addr);
            @(negedge pclk); s_psel=0; s_penable=0; s_pwrite=0;
        end
    endtask

    task automatic slave_read(input logic [7:0] addr, output logic [31:0] data);
        begin
            @(negedge pclk); s_psel=1; s_penable=0; s_pwrite=0; s_paddr=addr;
            @(negedge pclk); s_penable=1;
            @(posedge pclk); if (!s_pready || s_pslverr) $fatal(1, "slave APB read failed at %h", addr); data=s_prdata;
            @(negedge pclk); s_psel=0; s_penable=0;
        end
    endtask

    initial begin
        $dumpfile("spi_x_pair.vcd");
        $dumpvars(0, tb_spi_x_pair);
        #1 presetn=1;
        #1 presetn=0;
        repeat (4) @(negedge pclk);
        presetn=1;
        repeat (4) @(negedge pclk);

        // Load the slave reply and provide idle SCLK edges so its local reset
        // and FIFO pointer synchronizers can release before selecting it.
        slave_write(8'h00, 32'h00000000);
        slave_write(8'h10, 32'h0000003C);
        prime_clock=1;
        repeat (6) begin #4 prime_sclk=1; #4 prime_sclk=0; end
        prime_clock=0;

        master_write(8'h00, 32'h00000002); // master, disabled
        master_write(8'h0C, 32'h00000000); // mode 0, 8-bit, loopback off
        master_write(8'h08, 32'd2);
        master_write(8'h10, 32'h000000A5);
        master_write(8'h18, 32'h00000001);
        slave_write(8'h0C, 32'h00000000); // mode 0, 8-bit
        slave_write(8'h00, 32'h00000000); // disabled slave
        slave_write(8'h18, 32'h00000001);
        slave_write(8'h00, 32'h00000001); // enable slave mode
        master_write(8'h00, 32'h00000003); // enable master mode

        timeout=0;
        do begin
            master_read(8'h04, m_status);
            timeout=timeout+1;
        end while (m_status[0] && timeout<1000);
        if (timeout>=1000) $fatal(1, "paired master transfer timed out");
        repeat (4) @(negedge pclk);
        slave_read(8'h1C, s_irq_status);
        if (!m_irq || !s_irq || !s_irq_status[0])
            $fatal(1, "completion IRQ did not propagate in both APB domains");
        master_read(8'h14, m_rx);
        slave_read(8'h14, s_rx);
        if (m_rx !== 32'h0000003C)
            $fatal(1, "master received %h, expected slave word 3C", m_rx);
        if (s_rx !== 32'h000000A5)
            $fatal(1, "slave received %h, expected master word A5", s_rx);
        if (s_miso_oe || m_cs_n !== 4'hF || m_miso_oe || m_miso !== 1'b0)
            $fatal(1, "SPI pins did not return to their idle/master values");
        if (s_sclk_out !== 1'b0 || s_mosi_out !== 1'b0 || s_cs_out_n !== 4'hF)
            $fatal(1, "slave instance incorrectly drove master-only pins");
        $display("PASS: paired SPI-X instances completed full-duplex master/slave transfer (A5 <-> 3C)");
        $finish;
    end

    always @(posedge pclk) begin
        if (m_cs_n[0] === 1'b0) begin
            if (!s_miso_oe) $fatal(1, "slave did not enable MISO while selected");
            if (m_cs_n[3:1] !== 3'b111) $fatal(1, "unexpected master chip select asserted");
        end
    end

    initial begin
        #200000;
        $fatal(1, "paired system integration timeout");
    end
endmodule
