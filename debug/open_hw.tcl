##============================================================================
## open_hw.tcl  —  Vivado Hardware Manager
##============================================================================
open_hw_manager
connect_hw_server -allow_non_jtag
current_hw_target [get_hw_targets -of_objects [get_hw_servers -quiet] -quiet]
if {[llength [get_hw_targets]] > 0} {
  open_hw_target
  set_property PROGRAM.FILE {i2c_project.bit} [lindex [get_hw_devices] 0]
  program_hw_devices [lindex [get_hw_devices] 0]
  puts "Hardware manager ready."
} else {
  puts "No hardware target found."
}
