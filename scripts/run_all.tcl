set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file dirname $script_dir]
set proj_name  [file tail $proj_root]

set part_name [lindex $argv 0]
if {$part_name eq ""} { set part_name "xc7a35ticsg324-1L" }

create_project -force $proj_name $proj_root -part $part_name
add_files -fileset sources_1 -norecurse [glob $proj_root/rtl/*.v]
add_files -fileset constrs_1 -norecurse [glob $proj_root/constraints/*.xdc]
set_property top i2c_top [current_fileset]
set_property target_language Verilog [current_project]

set report_dir $proj_root/reports

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1 -name netlist_1
file mkdir $report_dir/synth $report_dir/timing $report_dir/power
report_utilization -file $report_dir/synth/synth_util.rpt
report_timing_summary -delay_type min_max -file $report_dir/timing/synth_timing.rpt

launch_runs impl_1 -jobs 4
wait_on_run impl_1
open_run impl_1 -name netlist_route
file mkdir $report_dir/impl
report_timing_summary -delay_type min_max -file $report_dir/timing/impl_timing.rpt
report_timing -delay_type min -max_paths 10 -file $report_dir/timing/impl_hold.rpt
report_timing -delay_type max -max_paths 10 -file $report_dir/timing/impl_setup.rpt
report_power -file $report_dir/power/impl_power.rpt
report_drc -file $report_dir/impl/impl_drc.rpt

set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
write_bitstream -force "$proj_root/$proj_name.bit"

puts "\n✓ Completed. Bitstream: $proj_root/$proj_name.bit"
close_project
