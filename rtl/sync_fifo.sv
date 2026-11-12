`default_nettype none
`timescale 1ns/1ps
module sync_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 4
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,
    output logic [ADDR_WIDTH:0]   wr_level,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty,
    output logic [ADDR_WIDTH:0]   rd_level
);
    localparam int DEPTH = 1 << ADDR_WIDTH;
    localparam logic [ADDR_WIDTH:0] DEPTH_COUNT = {1'b1, {ADDR_WIDTH{1'b0}}};
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH:0] wr_ptr, rd_ptr;
    logic [ADDR_WIDTH:0] occupancy;
    logic wr_accept, rd_accept;

    always_comb begin
        occupancy = wr_ptr - rd_ptr;
        full = (occupancy == DEPTH_COUNT);
        empty = (occupancy == '0);
        rd_accept = rd_en && !empty;
        // A simultaneous read frees a slot for a write on a full FIFO.
        wr_accept = wr_en && (!full || rd_accept);
        wr_level = occupancy;
        rd_level = occupancy;
        rd_data = mem[rd_ptr[ADDR_WIDTH-1:0]];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
        end else begin
            if (wr_accept) begin
                mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (rd_accept)
                rd_ptr <= rd_ptr + 1'b1;
        end
    end

`ifndef SYNTHESIS
    initial begin
        if (ADDR_WIDTH < 1) $error("sync_fifo ADDR_WIDTH must be >= 1");
    end
    /* verilator lint_off SYNCASYNCNET */
    always @(posedge clk) begin
        if (rst_n) begin
            assert (occupancy <= DEPTH_COUNT)
                else $error("sync_fifo occupancy exceeded its capacity");
            assert (full == (occupancy == DEPTH_COUNT))
                else $error("sync_fifo full flag mismatch");
            assert (empty == (occupancy == '0))
                else $error("sync_fifo empty flag mismatch");
        end
    end
    /* verilator lint_on SYNCASYNCNET */
`endif
endmodule
`default_nettype wire
