`default_nettype none
`timescale 1ns/1ps
module async_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 4
) (
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,
    output logic [ADDR_WIDTH:0]   wr_level,
    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty,
    output logic [ADDR_WIDTH:0]   rd_level
);
    localparam int DEPTH = 1 << ADDR_WIDTH;
    localparam logic [ADDR_WIDTH:0] DEPTH_COUNT = {1'b1, {ADDR_WIDTH{1'b0}}};
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH:0] wr_bin, wr_gray, rd_bin, rd_gray;
    (* ASYNC_REG = "TRUE" *) logic [ADDR_WIDTH:0] rd_gray_wq1, rd_gray_wq2;
    (* ASYNC_REG = "TRUE" *) logic [ADDR_WIDTH:0] wr_gray_rq1, wr_gray_rq2;
    logic [ADDR_WIDTH:0] wr_bin_next, wr_gray_next;
    logic [ADDR_WIDTH:0] rd_bin_next, rd_gray_next;

    function automatic [ADDR_WIDTH:0] gray_to_bin;
        input logic [ADDR_WIDTH:0] gray;
        logic [ADDR_WIDTH:0] bin;
        integer i;
        begin
            bin[ADDR_WIDTH] = gray[ADDR_WIDTH];
            for (i = ADDR_WIDTH-1; i >= 0; i = i-1)
                bin[i] = bin[i+1] ^ gray[i];
            gray_to_bin = bin;
        end
    endfunction

    always @* begin
        wr_bin_next  = wr_bin + {{ADDR_WIDTH{1'b0}}, (wr_en && !full)};
        wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;
        rd_bin_next  = rd_bin + {{ADDR_WIDTH{1'b0}}, (rd_en && !empty)};
        rd_gray_next = (rd_bin_next >> 1) ^ rd_bin_next;
    end

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_bin <= '0;
            wr_gray <= '0;
            rd_gray_wq1 <= '0;
            rd_gray_wq2 <= '0;
        end else begin
            rd_gray_wq1 <= rd_gray;
            rd_gray_wq2 <= rd_gray_wq1;
            if (wr_en && !full)
                mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;
            wr_bin <= wr_bin_next;
            wr_gray <= wr_gray_next;
        end
    end

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_bin <= '0;
            rd_gray <= '0;
            wr_gray_rq1 <= '0;
            wr_gray_rq2 <= '0;
        end else begin
            wr_gray_rq1 <= wr_gray;
            wr_gray_rq2 <= wr_gray_rq1;
            rd_bin <= rd_bin_next;
            rd_gray <= rd_gray_next;
        end
    end

    always @* begin
        full = ((wr_bin - gray_to_bin(rd_gray_wq2)) == DEPTH_COUNT);
        empty = (rd_gray == wr_gray_rq2);
        wr_level = wr_bin - gray_to_bin(rd_gray_wq2);
        rd_level = gray_to_bin(wr_gray_rq2) - rd_bin;
        rd_data = mem[rd_bin[ADDR_WIDTH-1:0]];
    end

`ifndef SYNTHESIS
    initial begin
        if (ADDR_WIDTH < 2) $error("async_fifo ADDR_WIDTH must be >= 2");
        if ((1 << ADDR_WIDTH) < 2) $error("async_fifo depth must be >= 2");
    end
`endif

`ifdef FORMAL
    logic formal_wr_past_valid = 1'b0;
    logic formal_rd_past_valid = 1'b0;
    always @(posedge wr_clk) begin
        if (!wr_rst_n) formal_wr_past_valid <= 1'b0;
        else begin
            assert(wr_level <= DEPTH_COUNT);
            assert(full == (wr_level == DEPTH_COUNT));
            if (formal_wr_past_valid) begin
                assert($onehot0(wr_gray ^ $past(wr_gray)));
                assert(wr_bin == ($past(wr_bin) + (($past(wr_en) && !$past(full)) ? 1'b1 : 1'b0)));
            end
            formal_wr_past_valid <= 1'b1;
        end
    end
    always @(posedge rd_clk) begin
        if (!rd_rst_n) formal_rd_past_valid <= 1'b0;
        else begin
            assert(rd_level <= DEPTH_COUNT);
            assert(empty == (rd_level == '0));
            if (formal_rd_past_valid) begin
                assert($onehot0(rd_gray ^ $past(rd_gray)));
                assert(rd_bin == ($past(rd_bin) + (($past(rd_en) && !$past(empty)) ? 1'b1 : 1'b0)));
            end
            formal_rd_past_valid <= 1'b1;
        end
    end
`endif
endmodule
`default_nettype wire
