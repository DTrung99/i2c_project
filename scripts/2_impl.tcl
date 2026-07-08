open_project [glob ../*.xpr][0]
open_run synth_1 -name netlist_1
launch_runs impl_1 -jobs 4
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] != "route_design Complete!"} {
  error "IMPLEMENTATION FAILED"
}
open_run impl_1 -name netlist_route
file mkdir reports/timing reports/power reports/impl
report_timing_summary -delay_type min_max -file reports/timing/impl_timing.rpt
report_timing -delay_type min -max_paths 10 -file reports/timing/impl_hold.rpt
report_timing -delay_type max -max_paths 10 -file reports/timing/impl_setup.rpt
report_power -file reports/power/impl_power.rpt
report_drc -file reports/impl/impl_drc.rpt
close_project
