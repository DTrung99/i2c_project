open_project [glob ../*.xpr][0]
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] != "synth_design Complete!"} {
  error "SYNTHESIS FAILED"
}
open_run synth_1 -name netlist_1
file mkdir reports/synth
report_utilization -file reports/synth/synth_util.rpt
report_timing_summary -delay_type min_max -file reports/synth/synth_timing.rpt
close_project
