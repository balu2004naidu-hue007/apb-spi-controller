# SPI-X: DESIGN AND VERIFICATION OF AN ADVANCED APB-BASED SPI MASTER/SLAVE CONTROLLER WITH ASYNCHRONOUS FIFOs AND EMBEDDED C DRIVER

## 1. PROJECT OVERVIEW

Project Name: SPI-X

Project Category: Digital Design, RTL Design, SoC Peripheral IP and Embedded Systems

Implementation Languages:
- SystemVerilog
- Embedded C
- C++
- Python

Development Environment:
- Windows
- MSYS2 UCRT64
- Verilator
- Yosys
- GTKWave
- GCC
- Python
- Make

Hardware Requirement: None

Project Type: Completely software-based development, simulation, verification and synthesis.

### Project Objective

The objective of SPI-X is to design, implement, simulate, verify and synthesise an advanced SPI Master/Slave Controller with an APB3-compatible register interface, transmit and receive FIFOs, asynchronous FIFO architecture, programmable clock generation, interrupt handling and an Embedded C driver.

The project aims to demonstrate the complete development of a reusable communication peripheral IP, from RTL architecture and digital protocol implementation to firmware development, functional verification and synthesis analysis.

No physical FPGA, microcontroller, development board or external electronic components are required.

---

## 2. PROBLEM STATEMENT

Processors and microcontrollers frequently communicate with external peripherals such as sensors, memory devices, displays, ADCs, DACs and wireless communication modules using the Serial Peripheral Interface (SPI) protocol.

Implementing SPI communication requires handling clock generation, data shifting, sampling edges, transfer timing, chip selection, buffering and error conditions.

A processor should not need to manually manage every serial clock transition and data bit.

SPI-X addresses this problem by providing a programmable hardware peripheral architecture that manages SPI communication independently while allowing software to configure and control its operation through an APB3 interface.

The design also addresses data buffering, clock-domain crossing, communication status reporting and firmware-level peripheral control.

---

## 3. COMPLETE SYSTEM ARCHITECTURE

The project consists of five major engineering layers:

1. Hardware Description Layer
2. APB3 Bus and Register Layer
3. Embedded Firmware Layer
4. Verification and Simulation Layer
5. Synthesis and Analysis Layer

### Overall Data Flow

Embedded C Application
        |
        v
SPI-X C Driver
        |
        v
APB3 Bus Interface
        |
        v
Register Bank and Control Logic
        |
        +-----------------------+
        |                       |
        v                       v
SPI Master Subsystem       SPI Slave Subsystem
        |                       |
        v                       v
TX FIFO / RX FIFO          TX FIFO / RX FIFO
        |                       |
        v                       v
SPI Master Engine          SPI Slave Engine
        |                       |
        +----------+------------+
                   |
                   v
       Simulated SPI Communication
                   |
                   v
          Verification Testbench
                   |
                   v
          Python Reference Model

The master and slave can operate independently and can also be connected together in a simulation environment to verify complete communication.

---

## 4. HARDWARE DESCRIPTION LAYER

All digital hardware modules will be implemented using synthesizable SystemVerilog.

### MODULE 1: APB3 INTERFACE

Purpose:

Provides a standard peripheral bus interface between the processor-side software and SPI-X.

Responsibilities:

- APB setup and access phases.
- Address decoding.
- Register read operations.
- Register write operations.
- Peripheral selection.
- Ready and error responses.
- FIFO register access.
- Control and status register access.

APB3 Signals:

- PCLK
- PRESETn
- PADDR
- PSEL
- PENABLE
- PWRITE
- PWDATA
- PRDATA
- PREADY
- PSLVERR

Verification:

The APB3 interface will be tested using SystemVerilog testbenches without requiring an actual processor or physical bus.

### MODULE 2: REGISTER BANK

Purpose:

Stores SPI configuration values and communication status information.

Proposed Register Map:

0x00 - CTRL
Function: Peripheral enable and reset controls.

0x04 - STATUS
Function: Busy, FIFO and error status.

0x08 - CLK_DIV
Function: Programmable SPI clock divider.

0x0C - CONFIG
Function: CPOL, CPHA, bit order and data width configuration.

0x10 - TX_DATA
Function: Transmit data register.

0x14 - RX_DATA
Function: Receive data register.

0x18 - INT_ENABLE
Function: Interrupt enable configuration.

0x1C - INT_STATUS
Function: Interrupt status information.

0x20 - FIFO_CTRL
Function: FIFO reset and configuration.

0x24 - CS_CTRL
Function: Chip-select configuration.

0x28 - TRANSFER_LEN
Function: Transfer length configuration.

0x2C - ERROR_STATUS
Function: Error information.

All register reset values, read/write permissions, status behaviour and interrupt-clearing mechanisms will be documented.

### MODULE 3: SPI MASTER CONTROLLER

Purpose:

Generates the SPI clock and controls serial communication with external slave devices.

Internal Components:

- Programmable clock divider.
- SPI mode controller.
- Transmit shift register.
- Receive shift register.
- Bit counter.
- Frame controller.
- Chip-select controller.
- Transfer-complete logic.
- FIFO interface.

Supported Features:

- SPI Mode 0.
- SPI Mode 1.
- SPI Mode 2.
- SPI Mode 3.
- 8-bit data transfers.
- 16-bit data transfers.
- 32-bit data transfers.
- MSB-first transmission.
- LSB-first transmission.
- Four chip-select outputs.
- Full-duplex communication.
- Programmable clock division.

### MODULE 4: SPI SLAVE CONTROLLER

Purpose:

Receives SPI clock and chip-select signals from an external master and performs serial data communication.

Internal Components:

- SPI clock sampling logic.
- Receive shift register.
- Transmit shift register.
- Bit counter.
- Frame completion logic.
- Chip-select detection.
- TX FIFO interface.
- RX FIFO interface.

Supported Features:

- All four SPI modes.
- 8-bit, 16-bit and 32-bit frames.
- MSB-first and LSB-first.
- Serial data reception.
- Serial data transmission.
- Full-duplex communication.
- Chip-select-controlled frame handling.

The slave will be independently verified using simulated SPI master signals.

### MODULE 5: TRANSMIT AND RECEIVE FIFOs

Purpose:

Temporarily store data during SPI communication and reduce the need for continuous processor intervention.

Proposed Configuration:

TX FIFO:
- Depth: 16 entries.
- Width: 32 bits.

RX FIFO:
- Depth: 16 entries.
- Width: 32 bits.

Required Features:

- Read and write pointer management.
- Full detection.
- Empty detection.
- Simultaneous read/write support.
- Overflow protection.
- Underflow protection.
- FIFO reset.
- Status reporting.
- Programmable thresholds as an optional extension.

### MODULE 6: ASYNCHRONOUS FIFO AND CLOCK-DOMAIN CROSSING

Purpose:

Safely transfer data between independent clock domains.

Clock Domains:

1. APB clock domain.
2. SPI slave clock domain.

Proposed Architecture:

- Binary read and write pointers.
- Gray-code pointer conversion.
- Two-stage pointer synchronizers.
- Full and empty detection.
- Reset synchronisation.
- Clock-domain crossing assertions.
- Multi-clock simulation tests.

The asynchronous FIFO will be used where a genuine clock-domain crossing exists.

The SPI master will normally use the APB/system clock internally while generating its SPI clock output. An asynchronous FIFO is not automatically required inside the master.

### MODULE 7: INTERRUPT CONTROLLER

Purpose:

Reports important SPI events to the processor-side software.

Interrupt Sources:

- Transfer complete.
- RX FIFO not empty.
- TX FIFO space available.
- RX FIFO overflow.
- TX FIFO underflow.
- Transfer timeout.
- Configuration and protocol errors.

Interrupt functionality will be verified through simulated interrupt signals and testbench monitoring.

### MODULE 8: SPI SYSTEM INTEGRATION

Purpose:

Connects the independent SPI master and slave modules to verify end-to-end communication.

Simulated Connections:

- Master SCLK to Slave SCLK.
- Master MOSI to Slave MOSI.
- Slave MISO to Master MISO.
- Master CS_n to Slave CS_n.

Example:

Master transmits: 0xA5
Slave receives: 0xA5

Slave transmits: 0x3C
Master receives: 0x3C

Expected Result:

Master RX = 0x3C
Slave RX = 0xA5
Communication = PASS

This complete communication will be tested without physical hardware.

---

## 5. EMBEDDED C SOFTWARE ARCHITECTURE

The firmware layer provides software control of the SPI peripheral through memory-mapped register operations.

### Proposed Software APIs

SPI_Init()
Initialises the SPI peripheral.

SPI_SetMode()
Configures CPOL and CPHA.

SPI_SetClock()
Configures the SPI clock divider.

SPI_SetDataWidth()
Configures 8-bit, 16-bit or 32-bit transfers.

SPI_SetBitOrder()
Configures MSB-first or LSB-first operation.

SPI_Transmit()
Transmits data through the TX FIFO.

SPI_Receive()
Receives data from the RX FIFO.

SPI_Transfer()
Performs full-duplex communication.

SPI_GetStatus()
Reads peripheral status information.

SPI_EnableInterrupt()
Enables selected interrupt sources.

SPI_ClearInterrupt()
Clears interrupt status flags.

SPI_ResetFIFO()
Resets FIFO state.

### Firmware Examples

1. Basic SPI transmission.
2. Basic SPI reception.
3. Full-duplex communication.
4. SPI loopback testing.
5. Interrupt-based transfer.
6. FIFO operation.
7. Error handling.
8. Different SPI modes and data widths.

The C driver will be compiled using GCC and connected to a simulated register interface through the verification environment.

The project will not claim physical memory-mapped hardware communication. Firmware and RTL integration will be demonstrated through simulation.

---

## 6. VERIFICATION AND TESTING ARCHITECTURE

Verification is one of the most important parts of SPI-X.

The project will use multiple levels of testing.

### STAGE A: UNIT TESTING

APB3 Tests:
- Setup phase.
- Access phase.
- Read operations.
- Write operations.
- Wait states.
- Invalid access handling.

Register Bank Tests:
- Reset values.
- Writable registers.
- Read-only registers.
- Status updates.
- Interrupt clearing.

Master Tests:
- SPI clock generation.
- Clock polarity.
- Clock phase.
- Data shifting.
- Bit order.
- Frame length.

Slave Tests:
- Clock sampling.
- Data reception.
- Data transmission.
- Chip-select behaviour.
- Frame completion.

FIFO Tests:
- Empty condition.
- Full condition.
- Simultaneous read/write.
- Overflow.
- Underflow.
- Pointer correctness.

### STAGE B: SPI PROTOCOL TESTING

Test all four SPI modes.

Test:
- 8-bit transfers.
- 16-bit transfers.
- 32-bit transfers.
- MSB-first.
- LSB-first.
- Different clock divider values.
- Back-to-back transfers.
- Multiple chip-select lines.
- Supported clock configurations.

### STAGE C: SYSTEM INTEGRATION TESTING

- Master-to-slave data transfer.
- Slave-to-master data transfer.
- Full-duplex communication.
- Multiple consecutive frames.
- FIFO boundary conditions.
- Reset during idle operation.
- Reset during active transfers.
- Chip-select deassertion during a frame.
- Incorrect or incomplete transactions.
- Interrupt and error propagation.

### STAGE D: RANDOMISED TESTING

Randomly generate:

- Transfer lengths.
- SPI modes.
- Data values.
- Bit orders.
- Clock dividers.
- FIFO read/write operations.
- APB transactions.
- Reset timing.

Compare the RTL outputs against an independent Python SPI reference model.

### STAGE E: SYSTEMVERILOG ASSERTIONS

Implement assertions to check:

- FIFO pointer boundaries.
- FIFO occupancy limits.
- No reading from empty FIFO.
- No writing into full FIFO.
- APB protocol compliance.
- SPI sampling-edge correctness.
- Chip-select behaviour.
- Interrupt status and clearing.
- Clock-domain crossing assumptions.

### STAGE F: LINT, SIMULATION AND SYNTHESIS

Verilator:
- RTL lint.
- Warning analysis.
- Simulation.
- Testbench execution.

Yosys:
- RTL synthesis.
- Logic analysis.
- Flip-flop count.
- Logic-cell statistics.
- Synthesis report generation.

GTKWave:
- SPI clock waveform inspection.
- MOSI and MISO analysis.
- APB transaction inspection.
- FIFO pointer analysis.
- Interrupt timing analysis.

GCC:
- Embedded C driver compilation.
- Firmware example compilation.

Python:
- Reference model.
- Randomised test generation.
- Test automation.
- Result analysis.

---

## 7. SOFTWARE-ONLY FEASIBILITY

Every functional feature in the proposed architecture can be developed and tested using software tools.

Feature | Software-only feasibility

APB3 Interface | Fully supported
Register Bank | Fully supported
SPI Master | Fully supported
SPI Slave | Fully supported
SPI Modes 0–3 | Fully supported
8/16/32-bit Frames | Fully supported
TX/RX FIFO | Fully supported
Asynchronous FIFO | Fully supported
Clock-Domain Crossing Simulation | Supported with simulation limitations
Interrupt Controller | Fully supported
Embedded C Driver | Fully supported
Master/Slave Integration | Fully supported
Randomised Verification | Fully supported
SystemVerilog Assertions | Supported
RTL Lint | Fully supported
RTL Simulation | Fully supported
Yosys Synthesis | Fully supported
Waveform Analysis | Fully supported

Physical FPGA testing, electrical signal validation and physical timing closure are outside the project scope.

The project will therefore be described as a software-verified RTL IP design rather than a physically validated hardware implementation.

---

## 8. PROPOSED PROJECT DIRECTORY STRUCTURE

SPI-X/
│
├── rtl/
│   ├── apb/
│   │   ├── apb_slave.sv
│   │   └── register_bank.sv
│   │
│   ├── master/
│   │   ├── spi_master.sv
│   │   ├── master_clock_divider.sv
│   │   └── master_engine.sv
│   │
│   ├── slave/
│   │   ├── spi_slave.sv
│   │   └── slave_engine.sv
│   │
│   ├── fifo/
│   │   ├── sync_fifo.sv
│   │   └── async_fifo.sv
│   │
│   ├── common/
│   │   ├── spi_types.sv
│   │   └── interrupt_controller.sv
│   │
│   └── top/
│       └── spi_x_top.sv
│
├── firmware/
│   ├── include/
│   │   └── spi_x.h
│   ├── src/
│   │   └── spi_x.c
│   └── examples/
│       ├── basic_transfer.c
│       ├── loopback_test.c
│       └── interrupt_test.c
│
├── verification/
│   ├── tb/
│   │   ├── tb_apb.sv
│   │   ├── tb_master.sv
│   │   ├── tb_slave.sv
│   │   ├── tb_async_fifo.sv
│   │   └── tb_spi_x_system.sv
│   │
│   ├── models/
│   │   └── spi_reference_model.py
│   │
│   └── tests/
│       ├── test_apb.py
│       ├── test_spi_modes.py
│       ├── test_fifo.py
│       ├── test_cdc.py
│       └── test_randomized.py
│
├── simulation/
│   ├── verilator/
│   └── waveforms/
│
├── synthesis/
│   ├── yosys/
│   └── reports/
│
├── docs/
│   ├── architecture.md
│   ├── register_map.md
│   ├── verification_plan.md
│   └── synthesis_report.md
│
└── Makefile

This is the proposed target structure. Actual filenames and hierarchy may be adjusted to preserve working modules and existing project implementation.

---

## 9. DEVELOPMENT PHASES

PHASE 1: Architecture and Specifications

- Finalise block diagram.
- Define APB3 register map.
- Define SPI timing requirements.
- Define FIFO architecture.
- Define clock-domain crossing strategy.
- Document module interfaces.

PHASE 2: APB3 and Register Bank

- Implement APB3 interface.
- Implement register bank.
- Verify read/write operations.
- Test reset and error conditions.

PHASE 3: SPI Master and Slave

- Implement master controller.
- Implement slave controller.
- Implement clock divider.
- Implement mode control.
- Verify frame widths and bit order.

PHASE 4: FIFO and CDC

- Implement synchronous FIFOs.
- Implement asynchronous FIFO.
- Implement Gray-code pointer synchronisation.
- Verify full/empty conditions.
- Perform multi-clock simulation.

PHASE 5: Interrupts and System Integration

- Implement interrupt controller.
- Connect master and slave.
- Verify full-duplex communication.
- Verify error handling.

PHASE 6: Embedded C Driver

- Develop register definitions.
- Implement driver APIs.
- Develop firmware examples.
- Compile using GCC.
- Integrate with the simulation register interface.

PHASE 7: Complete Verification and Synthesis

- Run Verilator lint.
- Run all RTL testbenches.
- Run randomised testing.
- Run assertion checks.
- Run Yosys synthesis.
- Inspect GTKWave waveforms.
- Generate verification and synthesis reports.

PHASE 8: Final Documentation

- Finalise README.
- Prepare architecture diagram.
- Prepare register map.
- Prepare test reports.
- Prepare synthesis reports.
- Document known limitations.
- Prepare interview explanation.

---

## 10. FINAL PROJECT DELIVERABLES

The completed SPI-X project should contain:

1. Synthesizable SystemVerilog source code.
2. APB3 register interface.
3. Independent SPI master and slave modules.
4. Synchronous and asynchronous FIFO implementations.
5. Clock-domain crossing architecture.
6. Interrupt controller.
7. Embedded C driver.
8. Firmware examples.
9. Self-checking SystemVerilog testbenches.
10. Python reference model.
11. Automated regression test scripts.
12. Verilator lint report.
13. RTL simulation report.
14. Yosys synthesis report.
15. GTKWave waveform evidence.
16. Detailed technical documentation.

---

## 11. PROJECT EVALUATION

Proposed architecture rating:

Technical Complexity: 9.5/10

Embedded Systems Relevance: 9.4/10

RTL and Digital Design Relevance: 9.6/10

Software-only Feasibility: 9.5/10

Hardware-Software Integration: 9.4/10

Verification Opportunities: 9.5/10

Real-World Applicability: 9.2/10

Implementation Difficulty: 8.8/10

Portfolio Differentiation: 9.0/10

Overall Proposed Project Potential: 9.3/10

These scores represent the proposed architecture's potential, not the current implementation's verified completion status.

---

## 12. WHY THIS PROJECT IS IMPORTANT

SPI-X demonstrates how a communication peripheral can be designed from the RTL level and controlled through embedded firmware.

It combines:

- Digital logic design.
- SystemVerilog RTL development.
- APB bus architecture.
- SPI protocol implementation.
- FIFO architecture.
- Clock-domain crossing.
- Embedded C driver development.
- Functional verification.
- Simulation and synthesis.
- Hardware-software integration.

The project is relevant to:

- Embedded Systems Engineering.
- RTL Design Engineering.
- Digital Design Engineering.
- SoC Design Engineering.
- Design Verification Engineering.
- FPGA Development.
- VLSI Engineering.
- Embedded Firmware Development.

---

## 13. FINAL PROJECT SCOPE DECISION

SPI-X will be developed as a completely software-based RTL and firmware project.

No physical FPGA, microcontroller, development board, sensor, external SPI peripheral or electronic component will be used.

All functional implementation, simulation, testing, verification, synthesis and waveform analysis will be performed using software tools.

The initial scope will focus on APB3, SPI master/slave operation, FIFOs, asynchronous clock-domain crossing, interrupts, Embedded C drivers and complete verification.

Additional technologies such as AXI, DMA integration, RISC-V processor integration and physical FPGA deployment will remain outside the initial scope.

The main goal is not to create the largest possible design. It is to create a correct, reusable, synthesizable, thoroughly verified and professionally documented SPI peripheral IP.

TARGET COMPLETION RATING: 9.3/10

SPI-X will be considered complete only after its implementation, integration, lint, simulation, verification and synthesis checks have been successfully executed and documented.