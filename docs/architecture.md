# I2C Controller — Architecture

## 1. Block Diagram

```
                    ┌─────────────────────────────────────┐
                    │              i2c_top                 │
                    │                                     │
  WB / regs ──────▶ │  i2c_regs         i2c_master        │
                    │  ┌──────────┐    ┌──────────────┐   │
                    │  │  CR      │    │  FSM         │   │
                    │  │  SR      │    │  bit counter │   │
                    │  │  ADDR    │    │  shift reg   │   │
                    │  │  DATA    │    │  ack checker │   │
                    │  └──────────┘    └──────┬───────┘   │
                    │                          │           │
                    │                     ┌────▼──────┐   │
                    │                     │  scl_gen   │   │
                    │                     │  ───────── │   │
                    │                     │  divider   │   │
                    │                     │  scl_out   │   │
                    │                     │  sda_in/out│   │
                    │                     └───────────┘   │
                    └─────────────────────────────────────┘
                                   │
                             ┌─────┴─────┐
                             │  IOBUFs   │
                             ├─────┬─────┤
                             │ SCL │ SDA │
                             └──┬──┴──┬──┘
                                │     │
                              (to pins)
```

## 2. Module Hierarchy

| Module      | Description                                  |
|-------------|----------------------------------------------|
| `i2c_top`   | Top-level: instantiate regs + master + IOBUF |
| `i2c_regs`  | Register file (CR, SR, ADDR, DATA)           |
| `i2c_master`| I2C protocol engine (FSM, bit counter)       |
| `i2c_scl_gen`| SCL clock divider + open-drain control      |

## 3. Submodule Details

### 3.1 i2c_top

- IOBUF primitive for SCL and SDA (inout → in + out + enable)
- Routes control/status between register file and master
- Instantiates all submodules

### 3.2 i2c_regs

- 4 registers: CR (write), SR (read), ADDR (write), DATA (write/read)
- Busy/ack_err/done updated by master
- Posedge detection on CR bits to trigger START/STOP

### 3.3 i2c_master

- FSM: IDLE → START → ADDR → ACK → DATA → ACK → STOP → IDLE
- Shift register for address (8 bits: addr + R/W)
- Shift register for data (8 bits)
- ACK checker: samples SDA after 9th SCL pulse
- SCL control: asserts/releases SCL via scl_gen
- SDA control: drives SDA for master transactions, releases for slave
- Repeated Start: re-enters START state from DATA state

### 3.4 i2c_scl_gen

- Counter-based divider: count = sys_clk / (2 × SCL_freq)
- For 100 kHz with 50 MHz: count to 250, toggle SCL
- Generates scl_enable signal for master timing

## 4. I/O Buffering

SCL and SDA are inout. Internal implementation:

```verilog
IOBUF #(DRIVE(8), IBUF_LOW_PWR("TRUE"), SLEW("SLOW"))
  scl_obuf (.IO(scl), .I(scl_out), .O(scl_in), .T(scl_oe_n));
IOBUF #(DRIVE(8), IBUF_LOW_PWR("TRUE"), SLEW("SLOW"))
  sda_obuf (.IO(sda), .I(sda_out), .O(sda_in), .T(sda_oe_n));
```

- `_oe_n = 1` → high-Z (release line, pull-up holds high)
- `_oe_n = 0` → drive `_out` value

## 5. Timing Diagram

### Write Byte

```
SCL:  ████████░░████████░░████████░░████████░░████████░░...
SDA:  ▓▓▓▓██░░██░░██░░██░░██░░██░░██░░██░░██░░██░░██▓▓▓▓
      Start   A6  A5 .. A0  W   ACK  D7  D6 .. D0  ACK Stop
```

### Read Byte

```
SCL:  ████████░░████████░░████████░░████████░░████████░░...
SDA:  ▓▓▓▓██░░██░░██░░██░░██░░██░░██░░██░░██░░██░░████▓▓
      Start   A6  A5 .. A0  R   ACK  D7  D6 .. D0  NACK Stop
```

## 6. Clock / Reset

| Signal | Domain | Description                |
|--------|--------|----------------------------|
| clk    | sysclk | 50 MHz system clock        |
| rst_n  | sysclk | Async active-low reset     |
| scl    | async  | I2C clock (100 kHz external, synchronized inside with 2 flops) |
| sda    | async  | I2C data (synchronized inside with 2 flops) |

## 7. Design Decisions

1. **No clock stretching**: Master-only, slave cannot stretch clock in standard mode.
2. **No multi-master arbitration**: Simple master-only implementation.
3. **SCL generated by divider**: Counter-based, not bit-banged.
4. **State machine encoded**: One-hot or binary FSM for clarity.
5. **Busy flag**: Prevents new transaction while one is in progress.
