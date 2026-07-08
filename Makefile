# ============================================================================
# Makefile — i2c_project (I2C Controller)
# ============================================================================

TOP      = tb_i2c
VTOP     = i2c_top
PROJECT  = $(notdir $(CURDIR))
PART    ?= xc7a35ticsg324-1L

VSRC     = $(sort $(wildcard rtl/*.v))
VTB      = sim/$(TOP).v
VVP      = sim/$(TOP).vvp
VCD      = sim/$(TOP).vcd

VIVADO  ?= vivado
SCRIPTS  = scripts

# ============================================================================
# Steps 4–6, 9: RTL Simulation (Icarus Verilog)
# ============================================================================
.PHONY: all
all: sim

.PHONY: sim
sim: $(VVP)
	vvp $(VVP)

$(VVP): $(VSRC) $(VTB)
	iverilog -g2012 -o $(VVP) $(VSRC) $(VTB)

.PHONY: sim-gui
sim-gui: $(VCD)
	gtkwave $(VCD) &

$(VCD): sim

# ============================================================================
# Step 7: Lint
# ============================================================================
.PHONY: lint
lint:
	verilator --lint-only -Wall -Wno-DECLFILENAME -Wno-PINCONNECTEMPTY \
	  --top $(VTOP) $(VSRC) 2>&1

# ============================================================================
# Steps 10–16: Vivado FPGA flow
# ============================================================================
.PHONY: vivado-create
vivado-create: $(SCRIPTS)/0_create_project.tcl $(VSRC)
	$(VIVADO) -source $(SCRIPTS)/0_create_project.tcl -mode batch -tclargs $(PART)

.PHONY: vivado-synth
vivado-synth: $(SCRIPTS)/1_synth.tcl
	$(VIVADO) -source $(SCRIPTS)/1_synth.tcl -mode batch

.PHONY: vivado-impl
vivado-impl: $(SCRIPTS)/2_impl.tcl
	$(VIVADO) -source $(SCRIPTS)/2_impl.tcl -mode batch

.PHONY: vivado-bit
vivado-bit: $(SCRIPTS)/3_bitstream.tcl
	$(VIVADO) -source $(SCRIPTS)/3_bitstream.tcl -mode batch

.PHONY: vivado-all
vivado-all: $(SCRIPTS)/run_all.tcl
	$(VIVADO) -source $(SCRIPTS)/run_all.tcl -mode batch -tclargs $(PART)

.PHONY: vivado-gui
vivado-gui:
	$(VIVADO) $(PROJECT)/$(PROJECT).xpr &

.PHONY: vivado-clean
vivado-clean:
	rm -rf $(PROJECT) .Xil reports .cache *.jou *.log

# ============================================================================
# Board Bring-up
# ============================================================================
.PHONY: prog
prog:
	openFPGALoader -b digilent_arty $(PROJECT).bit

# ============================================================================
# CDC / RDC
# ============================================================================
.PHONY: cdc
cdc:
	$(VIVADO) -mode batch -source cdc/check_cdc.tcl -tclargs $(PROJECT) $(PART)

.PHONY: cdc-report
cdc-report:
	@echo "=== CDC/RDC Analysis ==="
	@echo "See cdc/cdc_report.md"

# ============================================================================
# Coverage
# ============================================================================
.PHONY: coverage-toggle
coverage-toggle: $(VCD)
	python3 scripts/coverage_toggle.py $(VCD)

.PHONY: coverage-report
coverage-report:
	@echo "=== Coverage Report ==="
	@echo "Plan:   see sim/coverage_plan.md"

# ============================================================================
# Clean
# ============================================================================
.PHONY: clean
clean:
	rm -f $(VVP) $(VCD) sim/*.vcd sim/*.fst

.PHONY: distclean
distclean: clean vivado-clean
