# SPI-X — APB SPI Master/Slave Controller

SPI-X is a software-only SystemVerilog and embedded C project implementing the supplied proposal: an APB3 peripheral with SPI master and slave engines, FIFOs, interrupts, firmware helpers, verification and an optional iCEBreaker/MCP3008 target example. No physical board is required for the project checks.

## Implemented capabilities

- APB3 fixed-latency register interface, including `PSLVERR` for invalid addresses.
- SPI master and slave: modes 0–3, 8/16/32-bit frames, MSB/LSB order.
- Master: four chip selects, programmable divider, loopback and multi-frame bursts under one CS.
- 16 × 32-bit synchronous master FIFOs and 16 × 32-bit asynchronous slave FIFOs.
- W1C sticky interrupts/errors, live FIFO-level interrupts, FIFO flush controls and status.
- C driver header, polling transfer helper, demo, Python reference tests, RTL tests, formal FIFO checks, waveform checks and target examples.

Read [the full register map](docs/register_map.md), [architecture compliance and limits](docs/architecture_gap_analysis.md), and [the original supplied proposal](docs/proposed_architecture.md).

## Run the checks

Open PowerShell in this project directory and run:

```powershell
./scripts/run_all_checks.ps1
```

The runner executes Python checks, C builds/API tests, Verilator lint, SystemVerilog simulation and waveform assertions, paired master/slave simulation, bounded FIFO formal checks, Yosys synthesis, iCEBreaker placement/timing where the bundled tools support it, and MCP3008 behavioral simulation.

Individual scripts are in `scripts/`. Python 3 and a host C/C++ compiler are required. Bundled Verilator/Yosys tools are under `work/tools`; the source-only package does not contain bulky build outputs.

## Main files

- `rtl/spi_x_top.sv` — APB register bank, controller integration and IRQ/error logic.
- `rtl/spi_master.sv`, `rtl/spi_slave.sv` — serial engines.
- `rtl/sync_fifo.sv`, `rtl/async_fifo.sv` — PCLK FIFOs and Gray-pointer CDC FIFOs.
- `sw/include/spi_x.h`, `sw/src/demo.c` — C interface and example.
- `tb/` — controller, paired-system and MCP3008 simulations.
- `formal/` — bounded formal harnesses for FIFO safety.
- `targets/icebreaker_mcp3008/` — UP5K pin map, wrapper and synthesis files.

## Scope notes

The target example is synthesized and simulated, but physical board validation is not part of this software-only request. The FIFO bounded proof is not a complete CDC/MTBF sign-off for every external slave-clock crossing. On this Windows setup Icarus currently creates an image and then crashes; VVP runs that fresh image successfully, and the scripts can fall back to a fresh Verilator simulation.
