##============================================================================
## check_cdc.tcl  —  Vivado CDC & RDC analysis
##============================================================================

set project [lindex $argv 0]
if {$project eq ""} { set project "i2c_project" }

set part [lindex $argv 1]
if {$part eq ""} { set part "xc7a35ticsg324-1L" }

set cdc_dir   [file dirname [file normalize [info script]]]
set proj_root [file dirname $cdc_dir]
set xpr_path  ${proj_root}/${project}.xpr

if {[file exists $xpr_path]} {
  open_project $xpr_path
} else {
  puts "Project not found — creating..."
  create_project -force $project $proj_root -part $part
  add_files -fileset sources_1 -norecurse [glob ${proj_root}/rtl/*.v]
  set xdc_file ${proj_root}/constraints/i2c.xdc
  if {[file exists $xdc_file]} {
    add_files -fileset constrs_1 -norecurse $xdc_file
  }
  set_property top i2c_top [current_fileset]
  set_property target_language Verilog [current_project]
  puts "Project created."
}

puts "\nRunning synthesis for CDC/RDC analysis..."
synth_design -top i2c_top -part $part

file mkdir ${proj_root}/reports

puts "\n=== CDC Report ==="
report_cdc -file ${proj_root}/reports/cdc_report.txt -details -verbose
puts "→ ${proj_root}/reports/cdc_report.txt"

puts "\n=== RDC Report ==="
if {[catch {report_rdc -file ${proj_root}/reports/rdc_report.txt -details -verbose}]} {
  puts "INFO: report_rdc not available (pre-2020.1 Vivado or unsupported)"
} else {
  puts "→ ${proj_root}/reports/rdc_report.txt"
}

close_project
exit
