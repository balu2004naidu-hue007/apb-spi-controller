`default_nettype none
module sync_fifo_formal(input logic clk);
    (* anyseq *) logic rst_n;
    (* anyseq *) logic wr_en, rd_en;
    (* anyseq *) logic [7:0] wr_data;
    logic full, empty;
    logic [7:0] rd_data;
    logic [2:0] wr_level, rd_level;
    logic past_valid = 1'b0;

    sync_fifo #(.DATA_WIDTH(8), .ADDR_WIDTH(2)) dut (
        .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .wr_data(wr_data),
        .full(full), .wr_level(wr_level), .rd_en(rd_en), .rd_data(rd_data),
        .empty(empty), .rd_level(rd_level)
    );

    always @(posedge clk) begin
        if (!past_valid) begin
            assume(!rst_n);
            past_valid <= 1'b1;
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
