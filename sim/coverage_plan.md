# Coverage Plan — I2C Controller

## 1. Functional Coverage (to add in testbench)

- [ ] Start condition
- [ ] Stop condition
- [ ] Repeated Start
- [ ] Single byte write (master → slave)
- [ ] Single byte read (slave → master)
- [ ] Multi-byte write
- [ ] Multi-byte read
- [ ] Combined write + repeated start + read
- [ ] ACK/NACK response
- [ ] Arbitration loss
- [ ] Clock stretching (slave)
- [ ] SCL frequency divider edge cases (min/max)

## 2. Code Coverage

| Type    | Tool     |
|---------|----------|
| Toggle  | scripts/coverage_toggle.py (VCD) |
| Line    | Verilator --coverage or commercial simulator |

## 3. Running

```bash
make sim                # run simulation
make coverage-toggle    # toggle analysis from VCD
```
