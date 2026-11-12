# SPI-X register map

All offsets are byte offsets. APB accesses are 32-bit and fixed latency (`PREADY=1`). Misaligned and unmapped accesses assert `PSLVERR`. Register changes to active transfer configuration are ignored while master or slave is busy and set the configuration-error event.

| Offset | Register | Access | Meaning |
|---:|---|---|---|
| `0x00` | `CTRL` | RW | bit 0 enable; bit 1 selects master (`1`) or slave (`0`). Reset value `0x2` (disabled master). |
| `0x04` | `STATUS` | RO | bit 0 busy; bits 1:4 TX full, TX empty, RX full, RX empty; bits 12:8 TX level; bits 20:16 RX level; bit 21 enabled interrupt. |
| `0x08` | `CLK_DIV` | RW | Master half-period divider. `0` gives the minimum one-PCLK half-period; otherwise half-period is `CLK_DIV` PCLK cycles. Reset `2`. |
| `0x0C` | `CONFIG` | RW | bit 0 CPOL, bit 1 CPHA, bit 2 LSB-first, bits 4:3 width (`00`=8, `01`=16, `10`=32; `11` rejected), bit 5 master loopback. Reset `0`. |
| `0x10` | `TX_DATA` | WO | Pushes one 32-bit entry into the active role's TX FIFO. Writes while full are dropped and set TX-overflow status. |
| `0x14` | `RX_DATA` | RO/pop | Reads and removes the oldest active-role RX entry; reads while empty return zero. |
| `0x18` | `INT_ENABLE` | RW | Bit mask for the eight interrupt sources below. Reset `0`. |
| `0x1C` | `INT_STATUS` | RW1C/live | Sticky bits clear by writing one; bits 1 (RX nonempty) and 2 (TX space) are live level sources. |
| `0x20` | `FIFO_CTRL` | WO | bit 0 flush active-role TX FIFO; bit 1 flush active-role RX FIFO. |
| `0x24` | `CS_CTRL` | RW | Master chip-select index 0–3; active-low output. Slave uses external `spi_cs_in_n`. |
| `0x28` | `TRANSFER_LEN` | RW | Number of queued master frames for a transfer, clamped to at least one. CS stays asserted across frames. Reset `1`. |
| `0x2C` | `ERROR_STATUS` | RW1C | Sticky bits: 0 TX overflow, 1 RX overflow, 2 TX underflow, 3 transfer timeout, 4 configuration/protocol error. |

## Interrupt bits

| Bit | Source | Behavior |
|---:|---|---|
| 0 | Transfer complete | Sticky; includes completed slave frame or completed master burst. |
| 1 | RX FIFO not empty | Live level. |
| 2 | TX FIFO has space | Live level. |
| 3 | RX overflow | Sticky. New data is dropped; older queued data is preserved. |
| 4 | TX underflow | Sticky event when master burst waits for missing data or slave begins a frame with no TX word. |
| 5 | Transfer timeout | Sticky master burst starvation timeout. |
| 6 | Configuration/protocol error | Sticky invalid width or attempted active-transfer configuration write. |
| 7 | TX overflow | Sticky rejected write to a full TX FIFO. |

For sticky IRQ bits, writing one clears the corresponding bit. An event that is active on the same APB cycle as its clear remains set. Level IRQs clear only when the FIFO condition changes.

The C layout and constants are in [`../sw/include/spi_x.h`](../sw/include/spi_x.h). The synthesizable register implementation is in [`../rtl/spi_x_top.sv`](../rtl/spi_x_top.sv).
