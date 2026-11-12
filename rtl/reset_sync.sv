`default_nettype none
`timescale 1ns/1ps
// Asynchronous assertion, clock-synchronous deassertion. Instantiate one per
// independently clocked domain; do not share srst_n across clock domains.
module reset_sync (
    input  logic clk,
    input  logic arst_n,
    output logic srst_n
);
    (* ASYNC_REG = "TRUE" *) logic [1:0] release_pipe;

    // This is the standard async-assert/sync-release pattern: the vector is
    // asynchronously cleared and then shifted synchronously on local clocks.
    /* verilator lint_off SYNCASYNCNET */
    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n)
            release_pipe <= 2'b00;
        else
            release_pipe <= {release_pipe[0], 1'b1};
    end
    /* verilator lint_on SYNCASYNCNET */

    assign srst_n = release_pipe[1];
endmodule
`default_nettype wire
