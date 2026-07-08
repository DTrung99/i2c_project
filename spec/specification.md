# I2C Controller — Specification

## 1. Overview

| Item          | Description                         |
|---------------|-------------------------------------|
| Module        | I2C Controller (master only)        |
| Protocol      | I2C standard mode (100 kbit/s)      |
| Clock         | 50 MHz system clock                 |
| Interface     | Wishbone / simple register file     |

## 2. Pin List

| Port   | Width | Dir  | Description                    |
|--------|-------|------|--------------------------------|
| clk    | 1     | I    | System clock (50 MHz)          |
| rst_n  | 1     | I    | Async reset, active low        |
| scl    | 1     | IO   | I2C clock line (open-drain)    |
| sda    | 1     | IO   | I2C data line (open-drain)     |
| addr   | 7     | I    | Slave address                  |
| wr_en  | 1     | I    | Write strobe                   |
| rd_en  | 1     | I    | Read strobe                    |
| wdata  | 8     | I    | Write data                     |
| rdata  | 8     | O    | Read data                      |
| busy   | 1     | O    | Transaction in progress        |
| ack_err| 1     | O    | NACK received                  |
| done   | 1     | O    | Transaction complete (pulse)   |

## 3. I2C Protocol (Standard Mode)

### 3.1 Timing

| Parameter | Value             |
|-----------|-------------------|
| SCL freq  | 100 kHz           |
| SCL period| 10 µs             |
| Divider   | 500 (clk 50 MHz)  |
| SDA setup | ≥ 250 ns          |
| SDA hold  | ≥ 0 ns            |

### 3.2 Frame Format

```
Start | ADDR[6:0] + R/W | ACK | DATA[7:0] | ACK | ... | Stop
```

- Start: SDA下降 trong khi SCL cao
- Stop:  SDA上升 trong khi SCL cao
- Data:  SDA chỉ thay đổi khi SCL thấp, lấy mẫu ở rising edge SCL
- ACK:   Master releases SDA → slave kéo SDA xuống
- NACK:  Slave không kéo SDA xuống → master tạo Stop hoặc Repeated Start

### 3.3 Supported Operations

1. **Single write**: Start + addr(W) + ACK + data + ACK + Stop
2. **Single read**:  Start + addr(R) + ACK + (data from slave) + NACK + Stop
3. **Multi-byte write**: Start + addr(W) + ACK + data0 + ACK + ... + dataN + ACK + Stop
4. **Multi-byte read**:  Start + addr(R) + ACK + data0 (master ACK) + ... + dataN-1 (master ACK) + dataN (master NACK) + Stop
5. **Repeated Start**:  ... + ACK + Start + addr + R/W + ...

## 4. Register Map

| Addr | Name    | R/W | Description                     |
|------|---------|-----|---------------------------------|
| 0x00 | CR      | W   | Control: {start, stop, rd, wr}  |
| 0x01 | SR      | R   | Status: {busy, ack_err, done}   |
| 0x02 | ADDR    | W   | Slave address [6:0]             |
| 0x03 | DATA    | R/W | Data byte                       |

### 4.1 Control Register (CR)

| Bit | Name  | Description                        |
|-----|-------|------------------------------------|
| 0   | START | Generate Start condition           |
| 1   | STOP  | Generate Stop condition            |
| 2   | WR    | Write transaction                  |
| 3   | RD    | Read transaction (NACK after read) |
| 4   | RD_ACK| Read with ACK (multi-byte read)    |

### 4.2 Status Register (SR)

| Bit | Name    | Description                    |
|-----|---------|--------------------------------|
| 0   | BUSY    | Transaction in progress        |
| 1   | ACK_ERR | NACK received                  |
| 2   | DONE    | Transaction complete (clear on read) |

## 5. FSM States

### Main Controller

```
IDLE → START → SEND_ADDR → CHECK_ACK → 
  ├── WR: SEND_DATA → CHECK_ACK → (repeat or STOP)
  └── RD: SEND_ACK (master) → READ_DATA → (repeat or NACK)
       → STOP → IDLE
```

## 6. Clock Divider

SCL frequency = sys_clk / (2 × DIVIDER)

For 100 kHz with 50 MHz: DIVIDER = 250
- SCL high: 250 clk cycles
- SCL low:  250 clk cycles
