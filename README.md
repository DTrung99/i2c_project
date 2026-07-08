# I2C Master Controller

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Vivado](https://img.shields.io/badge/synth+impl-passing-green)](https://www.amd.com/vivado)
[![Icarus Verilog](https://img.shields.io/badge/simulation-passing-green)](https://steveicarus.github.io/iverilog/)
[![Target](https://img.shields.io/badge/target-Artix--7%20(xc7a35ti)-blue)]()

> A synthesizable, register-programmable I2C master controller for AMD/Xilinx 7-series FPGAs. Standard mode (100 kHz), master-only, with a 4-register CPU interface.

## 🌟 Highlights

- **Register-based control plane** — 4-register memory-mapped interface (CR, SR, ADDR, DATA) for easy CPU integration
- **Standard-mode I2C** — 100 kHz SCL with counter-based divider
- **Single & multi-byte transfers** — write or read one or more bytes with repeated START support
- **ACK/NACK detection** — sticky status flags for error handling
- **Busy guard** — prevents writing new commands while a transaction is in progress
- **Fully synthesizable** — targets Artix-7 (xc7a35ticsg324-1L) with clean timing closure (WNS > 15 ns)
- **Minimal footprint** — ~90 LUTs, ~67 FFs, 0.061 W total on-chip power

## ℹ️ Overview

This I2C master controller is designed as an **embedded peripheral** for FPGA-based systems that need to communicate with I2C slave devices — sensors, EEPROMs, ADCs, display controllers, and more.

The controller exposes a simple **register file** (4 registers addressed by 2 bits) that a soft-core CPU or state machine can read and write to initiate I2C transactions and check results. The I2C protocol engine is implemented as a dedicated finite state machine with explicit binary state encoding.

The project is written in **Verilog-2012**, verified with **Icarus Verilog** (10 test cases including NACK, busy guard, back-to-back transactions), and built through a **Vivado 2026.1** automated flow. A full architecture document and design specification are included in `docs/` and `spec/`.

### Target FPGA

**AMD/Xilinx Artix-7 XC7A35T** (part `xc7a35ticsg324-1L`, Digilent Arty A7-35T board).

## 🚀 Quick start

### Simulation

```bash
make sim
```

Compiles all RTL sources plus the testbench with Icarus Verilog and runs 10 test cases:

| Test | Description |
|------|-------------|
| T1   | Write byte 0x55 to slave 0x50 |
| T2   | Read byte from slave 0x50 |
| T3   | NACK on wrong slave address |
| T4   | Busy flag assertion during transaction |
| T5   | Write byte 0x5A |
| T6   | Write 0x00 (all zeros boundary) |
| T7   | Write 0xFF (all ones boundary) |
| T8   | Back-to-back write transactions |
| T9   | CR write while busy (busy guard) |
| T10  | Read with modified slave data (0x3C) |

View waveforms:

```bash
make sim-gui    # opens GTKWave
```

### Synthesis & bitstream

```bash
make vivado-all   # creates project, runs synth + impl, generates bitstream
```

The bitstream is written to `i2c_project.bit`.

### Program the board

```bash
make prog   # programs Arty board via openFPGALoader
```

### Lint & coverage

```bash
make lint              # Verilator lint
make coverage-toggle   # toggle coverage from VCD
make cdc               # Vivado CDC/RDC analysis
```

## ⬇️ Installation

**Requirements:**
- Linux / macOS
- [Icarus Verilog](https://steveicarus.github.io/iverilog/) ≥ 11 (`iverilog -g2012`)
- (optional) [Vivado](https://www.amd.com/vivado) 2026.1+ for synthesis / bitstream
- (optional) [GTKWave](http://gtkwave.sourceforge.net/) for waveform viewing
- (optional) [openFPGALoader](https://github.com/trabucayre/openFPGALoader) for board programming

Clone and simulate:

```bash
git clone <repo-url>
cd i2c_project
make sim
```

## 🏗️ Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│  i2c_regs   │◄───►│  i2c_master  │◄───►│ i2c_scl_gen  │
│  (reg file) │     │  (FSM)       │     │ (divider)    │
└──────┬──────┘     └──────┬───────┘     └──────────────┘
       │                   │
       │  addr[1:0]        │  scl_oen        ◄── SCL pad
       │  wr_en            │  sda_oen        ◄── SDA pad
       │  wdata[7:0]       │  sda_i
       │  rd_en            │
       │  rdata[7:0]       │
       │                   │
       ▼                   ▼
    CPU interface       I2C bus (external)
```

| Module | File | Function |
|--------|------|----------|
| `i2c_top` | `rtl/i2c_top.v` | Top-level: wires submodules together |
| `i2c_scl_gen` | `rtl/i2c_scl_gen.v` | Counter-based divider (50 MHz → 200 kHz tick → 100 kHz SCL) |
| `i2c_master` | `rtl/i2c_master.v` | I2C protocol FSM (11 states: IDLE → START → TX_ADDR → ACK_ADDR → TX/RX DATA → STOP) |
| `i2c_regs` | `rtl/i2c_regs.v` | 4-register file: Control, Status, Address, Data |

### Register map

| Address | Name | Access | Description |
|---------|------|--------|-------------|
| `0x00`  | CR   | write  | Control: `{start, stop, write, read, 4'b0}` — triggers transaction |
| `0x00`  | SR   | read   | Status: `{busy, ack_err_sticky, done_sticky, 5'b0}` |
| `0x01`  | ADDR | write  | Slave address (7-bit, `wdata[7:1]`) |
| `0x10`  | DATA | write  | Data to transmit |
| `0x10`  | DATA | read   | Data received |

### I2C FSM states

All states use explicit binary encoding (not auto-width defaults):

```
IDLE    = 4'b0000    START   = 4'b0001    TX_ADDR  = 4'b0010
ACK_ADDR= 4'b0011    TX_DATA = 4'b0100    ACK_DATA = 4'b0101
RX_DATA = 4'b0110    ACK_RX  = 4'b0111    STOP_A/B = 4'b1000/1001
STOP_C  = 4'b1010
```

## 🧪 Test results

After `make sim`, expected output:

```
T1: Write byte 0x55 to 0x50           ✓ PASS
T2: Read byte from 0x50                ✓ PASS
T3: NACK on wrong address 0x7E        ✓ PASS
T4: Busy flag test                     ✓ PASS
T5: Write byte 0x5A                    ✓ PASS
T6: Write 0x00 boundary                ✓ PASS
T7: Write 0xFF boundary                ✓ PASS
T8: Back-to-back writes                ✓ PASS
T9: Busy guard                         ✓ PASS
T10: Read with modified slave data     ✓ PASS
```

## 📊 Resource utilization

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUT      | 90   | 20,800    | 0.43%       |
| FF       | 67   | 41,600    | 0.16%       |
| I/O      | 25   | 210       | 11.90%      |
| BUFG     | 1    | 32        | 3.13%       |

Timing: **WNS = +15.174 ns** (50 MHz clock, -1L speed grade)

## 💭 Feedback & Contributing

Found a bug or want a feature? Open an issue or start a discussion. If you'd like to contribute, check the coverage gaps below — help is welcome!

### Coverage gaps (from simulation plan)

- Repeated START (mid-transaction restart without STOP)
- Multi-byte reads (>1 byte)
- Clock stretching (not yet supported — master-only design)
- Arbitration loss handling (not yet supported — single-master design)

## ✍️ Authors

- Your name here

## 📄 License

MIT — see [LICENSE](LICENSE) for details.
