`timescale 1ns/1ps
module tb_spi_x;
  logic pclk=0, presetn=0;
  always #5 pclk=~pclk;
  logic psel=0, penable=0, pwrite=0;
  logic [7:0] paddr=0;
  logic [31:0] pwdata=0;
  wire pready, pslverr, spi_sclk_out, spi_mosi_out, spi_miso_out, spi_miso_oe, irq;
  wire [31:0] prdata;
  logic spi_sclk_in=0, spi_mosi_in=0, spi_miso_in=0, spi_cs_in_n=1;
  wire [3:0] spi_cs_out_n;
  integer mode, width_sel, order, cs, div, i, tries, bitidx;
  logic [31:0] tx, rx, status, mask;
  logic [31:0] prng;
  integer widths[0:2];
  integer divs[0:3];
  spi_x_top dut(.*);

  task automatic wr(input [7:0] a,input [31:0] d);
    begin
      @(negedge pclk); psel=1; penable=0; pwrite=1; paddr=a; pwdata=d;
      @(negedge pclk); penable=1;
      @(posedge pclk); if(!pready) $fatal(1,"APB write stalled");
      @(negedge pclk); psel=0; penable=0; pwrite=0;
    end
  endtask
  task automatic rd(input [7:0] a,output [31:0] d);
    begin
      @(negedge pclk); psel=1; penable=0; pwrite=0; paddr=a;
      @(negedge pclk); penable=1;
      @(posedge pclk); if(!pready) $fatal(1,"APB read stalled"); d=prdata;
      @(negedge pclk); psel=0; penable=0;
    end
  endtask
  task automatic wait_done;
    begin
      tries=0;
      do begin rd(8'h04,status); tries=tries+1; end while(status[0] && tries<60000);
      if(tries>=60000) $fatal(1,"transfer timeout");
    end
  endtask

  initial begin
    $dumpfile("spi_x.vcd");
    $dumpvars(0,tb_spi_x);
    widths[0]=8; widths[1]=16; widths[2]=32;
    divs[0]=0; divs[1]=1; divs[2]=2; divs[3]=5;
    #2 presetn=1; #2 presetn=0; repeat(4) @(negedge pclk); presetn=1;
    repeat(4) @(negedge pclk);

    // APB proposal map, reset defaults and unmapped/misaligned error response.
    rd(8'h00,rx); if(rx[1:0]!==2'b10) $fatal(1,"CTRL default mismatch");
    rd(8'h08,rx); if(rx!==2) $fatal(1,"CLK_DIV reset mismatch");
    rd(8'h28,rx); if(rx!==1) $fatal(1,"TRANSFER_LEN reset mismatch");
    @(negedge pclk); psel=1; penable=1; pwrite=0; paddr=8'h30; #1;
    if(!pslverr) $fatal(1,"unmapped APB address did not return PSLVERR");
    @(negedge pclk); psel=0; penable=0;

    // Master matrix: all modes, widths, bit orders, four CS pins and dividers.
    wr(8'h00,2); wr(8'h0c,8'h20); wr(8'h18,1);
    for(mode=0;mode<4;mode=mode+1)
      for(width_sel=0;width_sel<3;width_sel=width_sel+1)
        for(order=0;order<2;order=order+1) begin
          wr(8'h00,2); wr(8'h0c,(mode[1]<<0)|(mode[0]<<1)|(order<<2)|(width_sel<<3)|32'h20);
          wr(8'h08,2); wr(8'h24,mode); wr(8'h28,1);
          tx=32'hA5963CC3 ^ (mode*32'h10204081) ^ (widths[width_sel]<<4) ^ order;
          wr(8'h10,tx); wr(8'h00,3);
          // loopback is internal, so external MISO is intentionally irrelevant.
          wait_done(); rd(8'h14,rx);
          if(width_sel==0 && rx[7:0]!==tx[7:0]) $fatal(1,"8-bit loopback mismatch");
          if(width_sel==1 && rx[15:0]!==tx[15:0]) $fatal(1,"16-bit loopback mismatch");
          if(width_sel==2 && rx!==tx) $fatal(1,"32-bit loopback mismatch");
          wr(8'h00,2);
        end
    for(cs=0;cs<4;cs=cs+1)
      for(i=0;i<4;i=i+1) begin
        wr(8'h0c,8'h20); wr(8'h24,cs); wr(8'h08,divs[i]); wr(8'h00,2);
        tx=32'hA5+cs+i; wr(8'h10,tx); wr(8'h00,3);
        wait_done(); rd(8'h14,rx);
        if(rx[7:0]!==tx[7:0]) $fatal(1,"CS/divider loopback mismatch cs=%0d div=%0d",cs,divs[i]);
        wr(8'h00,2);
      end
    $display("PASS: proposal APB map; master modes, widths, order, CS and divider matrix");

    // Repeat with 24 reproducible pseudo-random frames and divider/mode choices.
    prng=32'h51a7c0de;
    for(i=0;i<24;i=i+1) begin
      prng={prng[30:0],prng[31]^prng[21]^prng[1]^prng[0]};
      wr(8'h00,2); wr(8'h0c,32'h20|(prng[0]<<0)|(prng[1]<<1)|(prng[2]<<2));
      wr(8'h08,prng[10:8]); tx=prng[23:16]; wr(8'h10,tx); wr(8'h00,3);
      wait_done(); rd(8'h14,rx);
      if(rx[7:0]!==tx[7:0]) $fatal(1,"seeded randomized loopback mismatch trial=%0d",i);
      wr(8'h00,2);
    end
    $display("PASS: 24 seeded pseudo-random loopback frames");

    // Burst transfer length keeps CS asserted across adjacent frames.
    wr(8'h0c,8'h20); wr(8'h24,0); wr(8'h28,3); wr(8'h00,2);
    wr(8'h10,32'h11); wr(8'h10,32'h22); wr(8'h10,32'h33); wr(8'h00,3);
    wait_done(); rd(8'h14,rx); if(rx[7:0]!==8'h11) $fatal(1,"burst frame 1 mismatch");
    rd(8'h14,rx); if(rx[7:0]!==8'h22) $fatal(1,"burst frame 2 mismatch");
    rd(8'h14,rx); if(rx[7:0]!==8'h33) $fatal(1,"burst frame 3 mismatch");
    wr(8'h00,2); $display("PASS: multi-frame master burst and RX FIFO ordering");

    // Slave independently receives and transmits every supported mode/width/order.
    for(mode=0;mode<4;mode=mode+1)
      for(width_sel=0;width_sel<3;width_sel=width_sel+1)
        for(order=0;order<2;order=order+1) begin
          wr(8'h00,0); wr(8'h20,3); repeat(3) @(negedge pclk);
          wr(8'h0c,(mode[1]<<0)|(mode[0]<<1)|(order<<2)|(width_sel<<3));
          tx=32'h5ac39e71 ^ (mode*32'h11223344) ^ widths[width_sel] ^ order;
          mask=tx;
          rx=32'ha6953c5a ^ (mode*32'h01020408) ^ (widths[width_sel]<<4) ^ order;
          if(width_sel==0) begin tx=tx&32'hff; rx=rx&32'hff; end
          if(width_sel==1) begin tx=tx&32'hffff; rx=rx&32'hffff; end
          wr(8'h10,tx);
          spi_sclk_in=mode[1]; spi_cs_in_n=1;
          repeat(6) begin #2 spi_sclk_in=~spi_sclk_in; #2 spi_sclk_in=~spi_sclk_in; end
          wr(8'h00,1); spi_cs_in_n=0;
          status=0;
          for(i=0;i<widths[width_sel];i=i+1) begin
            bitidx=order ? i : widths[width_sel]-1-i;
            spi_mosi_in=rx[bitidx]; #2;
            if(mode[0]) begin
              spi_sclk_in=~spi_sclk_in; #2;
              status[bitidx]=spi_miso_out;
              spi_sclk_in=~spi_sclk_in; #2;
            end else begin
              status[bitidx]=spi_miso_out;
              spi_sclk_in=~spi_sclk_in; #2;
              spi_sclk_in=~spi_sclk_in; #2;
            end
          end
          spi_cs_in_n=1; repeat(4) @(negedge pclk);
          rd(8'h14,tx);
          if(width_sel==0 && tx[7:0]!==rx[7:0]) $fatal(1,"slave RX mode=%0d 8-bit mismatch",mode);
          if(width_sel==1 && tx[15:0]!==rx[15:0]) $fatal(1,"slave RX mode=%0d 16-bit mismatch",mode);
          if(width_sel==2 && tx!==rx) $fatal(1,"slave RX mode=%0d 32-bit mismatch",mode);
          if(width_sel==0 && status[7:0]!==mask[7:0]) $fatal(1,"slave TX mismatch");
          if(width_sel==1 && status[15:0]!==mask[15:0]) $fatal(1,"slave TX mismatch");
          if(width_sel==2 && status!==mask) $fatal(1,"slave TX mismatch");
          wr(8'h00,0);
        end
    $display("PASS: slave modes 0-3, widths 8/16/32 and both bit orders");

    // Partial frames must be discarded; clocks beyond one frame must be ignored.
    wr(8'h00,0); wr(8'h20,3); repeat(3) @(negedge pclk); wr(8'h0c,0);
    spi_sclk_in=0; wr(8'h00,1); spi_cs_in_n=0;
    for(i=0;i<4;i=i+1) begin spi_mosi_in=(4'hb >> (3-i))&1; #2 spi_sclk_in=1; #2 spi_sclk_in=0; #2; end
    spi_cs_in_n=1; repeat(4) @(negedge pclk); rd(8'h04,status);
    if(status[20:16]!=0) $fatal(1,"short slave frame entered RX FIFO");
    spi_cs_in_n=0;
    for(i=0;i<12;i=i+1) begin
      spi_mosi_in=(i<8) ? ((8'hb3 >> (7-i))&1) : 1'b1;
      #2 spi_sclk_in=1; #2 spi_sclk_in=0; #2;
    end
    spi_cs_in_n=1; repeat(4) @(negedge pclk); rd(8'h04,status);
    if(status[20:16]!=1) $fatal(1,"overlong slave frame count is not one");
    rd(8'h14,rx); if(rx[7:0]!==8'hb3) $fatal(1,"overlong slave frame data mismatch");
    rd(8'h14,rx); if(rx!==0) $fatal(1,"overlong slave frame emitted an extra word");
    wr(8'h00,0); $display("PASS: short frames discarded and excess clocks ignored");

    // FIFO reset, full/empty boundaries, overflow sticky event and W1C.
    wr(8'h00,0); wr(8'h20,3); repeat(3) @(negedge pclk);
    rd(8'h04,status); if(!status[2] || !status[4]) $fatal(1,"FIFO reset did not restore empty flags");
    for(i=0;i<16;i=i+1) wr(8'h10,i);
    rd(8'h04,status); if(!status[1] || status[12:8]!=16) $fatal(1,"TX FIFO full/level wrong");
    wr(8'h10,32'hdeadbeef); rd(8'h1c,rx); if(!rx[7]) $fatal(1,"TX overflow IRQ event not sticky");
    wr(8'h1c,32'h80); rd(8'h1c,rx); if(rx[7]) $fatal(1,"TX overflow W1C failed");
    wr(8'h20,1); repeat(3) @(negedge pclk);
    rd(8'h04,status); if(!status[2]) $fatal(1,"TX FIFO flush did not empty FIFO");
    $display("PASS: FIFO boundaries, reset/flush, overflow event and W1C");

    // Invalid frame width is rejected and recorded; APB remains responsive.
    wr(8'h0c,8'h18); rd(8'h0c,rx); if(rx[4:3]==3) $fatal(1,"reserved width accepted");
    rd(8'h2c,rx); if(!rx[4]) $fatal(1,"configuration error not recorded");
    wr(8'h2c,32'h10); rd(8'h2c,rx); if(rx[4]) $fatal(1,"ERROR_STATUS W1C failed");
    $display("PASS: invalid config reporting and ERROR_STATUS W1C");

    // Master burst starvation must report underflow and finish on hardware timeout.
    wr(8'h1c,32'hff); wr(8'h18,32'h31); wr(8'h0c,32'h20);
    wr(8'h28,2); wr(8'h00,2); wr(8'h10,32'h5a); wr(8'h00,3);
    wait_done(); rd(8'h1c,rx);
    if(!rx[0] || !rx[4] || !rx[5]) $fatal(1,"master starvation done/underflow/timeout events missing: %h",rx);
    wr(8'h00,2); $display("PASS: master burst starvation underflow and timeout");

    // Slave TX starvation reports through a toggle synchronizer into PCLK.
    wr(8'h1c,32'hff); wr(8'h18,32'h10); wr(8'h28,1); wr(8'h00,0);
    wr(8'h20,3); repeat(3) @(negedge pclk); wr(8'h0c,0);
    spi_sclk_in=0; repeat(6) begin #2 spi_sclk_in=1; #2 spi_sclk_in=0; end
    wr(8'h00,1); spi_cs_in_n=0;
    for(i=0;i<8;i=i+1) begin spi_mosi_in=(8'h3c>>(7-i))&1; #2 spi_sclk_in=1; #2 spi_sclk_in=0; #2; end
    spi_cs_in_n=1; repeat(6) @(negedge pclk); rd(8'h1c,rx);
    if(!rx[4] || !irq) $fatal(1,"slave TX underflow event/IRQ missing: %h",rx);
    $display("PASS: slave TX underflow CDC event and IRQ");

    // Fill the asynchronous slave RX FIFO, reject the seventeenth frame, and
    // verify its overflow event crosses back into the APB clock domain.
    wr(8'h1c,32'hff); wr(8'h18,32'h08); wr(8'h00,0); wr(8'h20,3);
    repeat(3) @(negedge pclk); wr(8'h0c,0);
    spi_sclk_in=0; repeat(6) begin #2 spi_sclk_in=1; #2 spi_sclk_in=0; end
    wr(8'h00,1);
    for(mode=0;mode<17;mode=mode+1) begin
      spi_cs_in_n=0;
      for(i=0;i<8;i=i+1) begin spi_mosi_in=(mode>>(7-i))&1; #2 spi_sclk_in=1; #2 spi_sclk_in=0; #2; end
      spi_cs_in_n=1; repeat(3) @(negedge pclk);
    end
    rd(8'h04,status); if(status[20:16]!=16) $fatal(1,"slave RX FIFO did not fill: %h",status);
    rd(8'h1c,rx); if(!rx[3] || !irq) $fatal(1,"slave RX overflow event/IRQ missing: %h",rx);
    rd(8'h2c,rx); if(!rx[1]) $fatal(1,"slave RX overflow error status missing: %h",rx);
    rd(8'h14,rx); if(rx[7:0]!==0) $fatal(1,"slave RX overflow changed oldest data: %h",rx);
    wr(8'h00,0); wr(8'h20,2); repeat(3) @(negedge pclk);
    $display("PASS: asynchronous slave RX full/overflow and event CDC");
    $finish;
  end
  initial begin #20000000; $fatal(1,"global test timeout"); end
endmodule
