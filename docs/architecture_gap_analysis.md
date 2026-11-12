# Proposal compliance and scope

SPI-X now uses the register map and major capabilities in the supplied proposal. The proposal itself is preserved in [proposed_architecture.md](proposed_architecture.md); the detailed implemented contract is in [register_map.md](register_map.md).

## Implemented

| Proposal item | Implemented result |
|---|---|
| APB3 bus and register bank | Fixed-latency APB3 with 12 aligned registers, setup/access-compatible access, and `PSLVERR` on unmapped or misaligned accesses. |
| SPI master | Modes 0–3, 8/16/32-bit frames, MSB/LSB first, four chip selects, programmable divider, loopback, and multi-frame transfers under one CS. |
| SPI slave | Modes 0–3, 8/16/32-bit frames, both bit orders, RX/TX, one frame per CS assertion; short frames are discarded and extra clocks ignored. |
| FIFOs | 16-entry × 32-bit synchronous FIFOs for the PCLK-driven master path; 16-entry × 32-bit Gray-pointer asynchronous FIFOs on slave clock crossings. Full/empty guards, overflow reporting and software flush are present. |
| Interrupt/error handling | Eight interrupt bits: done, RX nonempty, TX space, RX overflow, TX underflow, timeout, configuration/protocol error, TX overflow. Sticky events are write-one-to-clear; RX/TX level sources are live. Five sticky error bits are separately reported and W1C. |
| Firmware | C register structure, configuration, FIFO, IRQ, status and reset helpers; bounded full-duplex transfer helper; polling demo. Strict host C tests exercise API behavior. |
| Verification | Python reference checks; RTL mode/width/order matrices for master and slave; CS/divider matrix; bursts; short/overlong slave frames; FIFO full/empty/reset/flush; IRQ W1C; APB errors; paired master/slave exchange; MCP3008 behavioral simulation; assertions and bounded FIFO proofs. |
| Target synthesis | iCEBreaker UP5K/MCP3008 wrapper is synthesized and routed with the bundled iCE40 tools; the behavioral MCP3008 model checks the 32-bit command/result. No physical board is required for this software project. |

## Explicit boundaries

- APB is zero-wait (`PREADY=1`). There is no wait-state insertion.
- FIFO thresholds are fixed; programmable thresholds and DMA are not part of the proposal's required baseline.
- `spi_x_transfer`'s timeout bounds CPU polling. It does not cancel a frame already started in hardware.
- The top selects master or slave role per instance. Use two instances for a simulated master-to-slave link.
- The iCEBreaker flow is a target implementation check, not physical board validation. The complete generic slave-clock CDC path still needs dedicated static CDC/MTBF sign-off for a real product; bounded FIFO formal checks do not prove analog metastability behavior.
- Icarus emits a usable simulation image but the compiler process terminates abnormally afterward in this Windows setup. VVP runs the fresh image successfully; Verilator is the clean-build fallback.

These boundaries are documented capabilities and limits, not silently assumed features.
