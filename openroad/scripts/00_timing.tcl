# Copyright (c) 2025 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# OpenSTA script template for VLSI-2 EX04
#
# Author: Philippe Sauter <phsauter@iis.ee.ethz.ch>
#         Bowen Wang      <bowwang@iis.ee.ethz.ch>
#         Enrico Zelioli  <ezelioli@iis.ee.ethz.ch>
#
# Last Modification: 19.02.2025

# Read library files
source scripts/startup.tcl
# Load netlist
# Student Task 12: Modify the path to the output netlist
read_verilog ../yosys/out/croc_yosys.v
link_design croc_chip

# Set constraints
create_clock -name clk_sys -period 10 [get_ports clk_i]

# Generate timing report
file mkdir reports
set filename reports/sta.rpt
set when $filename
set fileId [open $filename w]
close $fileId
report_puts "\n=========================================================================="
report_puts "$when report_checks -path_delay min"
report_puts "--------------------------------------------------------------------------"
report_checks -path_delay min -fields {slew cap input nets fanout} -format full_clock_expanded >> $filename

report_puts "\n=========================================================================="
report_puts "$when report_checks -path_delay max"
report_puts "--------------------------------------------------------------------------"
report_checks -path_delay max -fields {slew cap input nets fanout} -format full_clock_expanded >> $filename

report_puts "\n=========================================================================="
report_puts "$when report_checks -unconstrained"
report_puts "--------------------------------------------------------------------------"
report_checks -unconstrained -fields {slew cap input nets fanout} -format full_clock_expanded >> $filename

exit

