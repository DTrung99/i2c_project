# CDC/RDC Analysis — I2C Controller

## 1. Overview

| Item        | Analysis                      |
|-------------|-------------------------------|
| Design      | i2c_top                      |
| Clock domains | TBD (update after RTL)     |
| Reset domains | TBD (update after RTL)     |
| Tool        | Vivado `report_cdc` / manual |
| Status      | **PENDING** — complete after RTL is written |

## 2. Notes

- I2C SCL may be an external input (clock domain crossing).
- SDA is inout open-drain — treat as async input.
- Add 2-flop synchronizers on SCL and SDA if they cross clock domains.
