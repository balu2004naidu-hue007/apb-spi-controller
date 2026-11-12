# SPI-X architecture

SPI-X has a PCLK/APB control domain and an externally clocked SPI slave domain. A selected role bit activates either the master or slave engine for an instance; a system test links two instances over MOSI/MISO/SCLK/CS.

The APB register bank and master TX/RX queues operate in PCLK. The SPI master generates SCLK from PCLK and supports bursts. The slave's TX and RX queues use 16-entry Gray-pointer asynchronous FIFOs to cross the APB and external SCLK domains. Separate reset synchronizers release reset in each clock domain. Slave frame completion and TX-underflow event information cross back to PCLK through synchronizers.

The project follows the proposal's register map and major feature set. Exact access semantics, bit definitions, FIFO policy and interrupt behavior are specified in [register_map.md](register_map.md). The original user-provided proposal is in [proposed_architecture.md](proposed_architecture.md); deviations and remaining sign-off boundaries are listed in [architecture_gap_analysis.md](architecture_gap_analysis.md).

## FIFO and frame behavior

Both FIFO types have 16 entries of 32 bits. Full writes are rejected and reported; RX overflow drops the newest incoming word while preserving older unread words. FIFO_CTRL flushes one or both queues in the selected role. A slave frame is one CS assertion: incomplete frames do not enter RX, and clocks after the configured width are ignored. Master `TRANSFER_LEN` determines the number of consecutive frames; CS remains active between frames.

## Reset and CDC

Reset asserts asynchronously and releases synchronously in each local clock domain. Slave FIFO pointers use Gray-coded crossings with two-stage synchronizers. Simulation and bounded formal checks exercise pointer/level safety. A dedicated CDC tool and target-specific MTBF/STA review are still necessary for product sign-off; simulation cannot establish analog metastability behavior.
