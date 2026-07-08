open_project [glob ../*.xpr][0]
open_run impl_1
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
write_bitstream -force "../[file tail [pwd]].bit"
puts "Bitstream: ../[file tail [pwd]].bit"
close_project
