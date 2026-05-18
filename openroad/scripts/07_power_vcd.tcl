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
set suffix "_qrrls"
set dir "reports/power"
set common "$dir/06_${proj_name}"
set filename "$common.power_vcd$suffix.rpt"
set fileId [open $filename w]
close $fileId
report_puts "VCD based power estimation"
report_power -digits 12 -corner tt >> "$common.power_vcd$suffix.rpt"

# -highest_power_instances is not yet working, not to use sta:: calls directly
#report_power -highest_power_instances 30 -corner tt -digits 12 >> "$common.power_vcd.rpt"
# equivalent to command above
sta::redirect_file_append_begin "$common.power_vcd$suffix.rpt"
sta::report_power_highest_insts 100 [sta::find_scene tt] 12
sta::redirect_file_end
#report_power -digits 12 -instances [get_cells -hierarchical {i_croc_soc/*}] -corner tt >> "$common.power_vcd.rpt"
# check vcd annotations
report_activity_annotation -report_annotated > "$common.activity$suffix.rpt"
report_activity_annotation -report_unannotated >> "$common.activity$suffix.rpt"
