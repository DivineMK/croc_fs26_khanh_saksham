source scripts/startup.tcl

# Load the gate-level netlist
read_verilog out/croc.v
# Link the design hierarchy using the top module name
link_design croc_chip
# Load timing constraints
read_sdc out/croc.sdc
# Load extracted parasitics
read_spef out/croc.spef
# Set uniform switching activity rate for all input ports, you may also replace -input with -global
#set_power_activity -input -activity 0.1
set_power_activity -input -activity 0.1
# Set known static inputs (e.g., reset) to zero activity
set_power_activity -input_port rst_ni -activity 0
# Generate the statistical power report for the typical corner
set filename "${report_dir}/07_${proj_name}.power_stat.rpt"
set fileId [open $filename w]
close $fileId
report_puts "Statistical power estimation"
report_power -corner tt >> $filename
