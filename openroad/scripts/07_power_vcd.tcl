source scripts/startup.tcl

# Load the gate-level netlist
read_verilog out/${proj_name}.v
# Link the design hierarchy using the top module name
link_design $top_design
# Load timing constraints
read_sdc out/${proj_name}.sdc
# Load extracted parasitics
read_spef out/${proj_name}.spef
# Set uniform switching activity rate for all input ports, you may also replace -input with -global
#set_power_activity -input -activity 0.1
#set_power_activity -global -activity 0.01
# Set known static inputs (e.g., reset) to zero activity
set_power_activity -input_port rst_ni -activity 0
# Load the VCD file and define the simulation scope
read_vcd -scope tb_croc_soc/i_croc_soc ../vsim/${proj_name}.vcd
# Generate the statistical power report for the typical corner
set filename "reports/power/06_${proj_name}.power_vcd.rpt"
set fileId [open $filename w]
close $fileId
report_puts "VCD based power estimation"
report_power -corner tt >> "reports/power/06_${proj_name}.power_vcd.rpt"
report_power -instances [get_cells -hierarchical {i_croc_soc/*}] -corner tt >> "reports/power/06_${proj_name}.power_vcd.rpt"
report_activity_annotation -report_unannotated > "reports/power/06_${proj_name}.activity.rpt"
