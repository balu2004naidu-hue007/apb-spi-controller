# SPI-X synthesis and target-flow report

Date: 2026-11-12

## Generic synthesis

Yosys generic synthesis and structural `check` completed with zero reported
structural problems for the `spi_x_top` design. The full synthesis transcript
is generated at `work/yosys.log` by `scripts/run_synthesis.ps1`.

## iCEBreaker reference implementation

Target: Lattice iCE40UP5K-SG48, 12 MHz board clock, reference wrapper
`targets/icebreaker_mcp3008/spi_x_icebreaker_mcp3008.sv`.

- Yosys iCE40 mapping and structural check: pass.
- nextpnr placement and routing: completed normally.
- Logic cells: 626 / 5,280 (11%).
- Block RAM: 0 / 30; the 16-entry FIFOs are mapped into logic registers.
- nextpnr maximum frequency: 34.74 MHz pre-route, 33.85 MHz post-route;
  both meet the wrapper's 12 MHz internal clock constraint.
- icetime critical path estimate: 31.12 ns (32.13 MHz).

These results cover the selected board wrapper and its internal clock. The
wrapper does not exercise the generic external-SCLK slave path. They are not
board-level I/O timing sign-off, full CDC analysis, or physical hardware
validation. The source templates and generated transcripts are described in
`docs/validation_report.md` and are reproduced by
`scripts/run_icebreaker_target.ps1`.
