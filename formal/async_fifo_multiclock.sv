`default_nettype none
module async_fifo_multiclock;
    (* anyseq *) logic wr_clk, rd_clk;
    (* anyseq *) logic rst_n;
    (* anyseq *) logic wr_en, rd_en;
    (* anyseq *) logic [7:0] wr_data;
    (* gclk *) logic gclk;
    logic initialized = 1'b0;
    logic full, empty;
    logic [7:0] rd_data;
    logic [2:0] wr_level, rd_level;

    async_fifo #(.DATA_WIDTH(8), .ADDR_WIDTH(2)) dut (
        .wr_clk(wr_clk), .wr_rst_n(rst_n), .wr_en(wr_en), .wr_data(wr_data),
        .full(full), .wr_level(wr_level),
        .rd_clk(rd_clk), .rd_rst_n(rst_n), .rd_en(rd_en), .rd_data(rd_data),
        .empty(empty), .rd_level(rd_level)
    );

    // Inputs are unconstrained between global formal steps, allowing either
    // clock to advance independently or both to advance together. Reset is
    // asserted initially, then held released so safety is checked after reset.
    always @(posedge gclk) begin
        if (!initialized) begin
            assume(!rst_n);
            initialized <= 1'b1;
        end else begin
            assume(rst_n);
            assert(wr_level <= 3'd4);
            assert(rd_level <= 3'd4);
            assert(full == (wr_level == 3'd4));
            assert(empty == (rd_level == 3'd0));
        end
    end
endmodule
`default_nettype wire
