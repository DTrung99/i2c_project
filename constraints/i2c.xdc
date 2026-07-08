##============================================================================
## I2C Controller — Timing Constraints
##============================================================================
## Clock: 50 MHz (period 20 ns)
## I2C:   SCL and SDA are open-drain (inout), no output delay needed
##============================================================================

create_clock -period 20.000 -name sysclk [get_ports clk]

set_false_path -from [get_ports rst_n]
