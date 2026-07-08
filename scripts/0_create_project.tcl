set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file dirname $script_dir]
set proj_name  [file tail $proj_root]

set part_name [lindex $argv 0]
if {$part_name eq ""} {
  set part_name "xc7a35ticsg324-1L"
}

puts "======================================================================"
puts "Creating Vivado project: $proj_name"
puts "Part: $part_name"
puts "Dir:  $proj_root"
puts "======================================================================"

create_project -force $proj_name $proj_root -part $part_name
add_files -fileset sources_1 -norecurse [glob $proj_root/rtl/*.v]
add_files -fileset constrs_1 -norecurse [glob $proj_root/constraints/*.xdc]
set_property top i2c_top [current_fileset]
set_property target_language Verilog [current_project]

puts "Project created: $proj_root/$proj_name/$proj_name.xpr"
