# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Deploy a bitstream to hardware without Vivado GUI.
# Auto-discovers the connected FPGA via JTAG.
#
# Usage:
#   vivado -mode batch -source scripts/deploy.tcl -tclargs <bitstream.bit> [<probes.ltx>]

# Check argument count
if { $argc < 1 || $argc > 2 } {
    puts "Error: Expected 1 or 2 arguments, got ${argc}: ${argv}."
    puts "Usage: vivado -mode batch -source scripts/deploy.tcl -tclargs <bitstream.bit> \[<probes.ltx>\]"
    return -code error
}

# Get arguments
set bitstream [lindex $argv 0]
set probes ""
if { $argc == 2 } {
    set probes [lindex $argv 1]
}

# Validate bitstream file
if { ![file exists $bitstream] } {
    puts "Error: Bitstream file not found: ${bitstream}"
    return -code error
}

# Validate probes file if provided
if { $probes ne "" && ![file exists $probes] } {
    puts "Error: Probes file not found: ${probes}"
    return -code error
}

# Connect to hardware
open_hw_manager
connect_hw_server

# Auto-discover target and device
set hw_tgt [lindex [get_hw_targets -of_objects [get_hw_servers localhost*]] 0]
open_hw_target $hw_tgt
set hw_device [lindex [get_hw_devices] 0]
current_hw_device $hw_device
refresh_hw_device -update_hw_probes false $hw_device

puts "Deploying bitstream: ${bitstream}"
puts "Target device: ${hw_device}"

# Configure bitstream and optional debug probes
set_property PROGRAM.FILE $bitstream $hw_device
if { $probes ne "" } {
    puts "Loading debug probes: ${probes}"
    set_property PROBES.FILE $probes $hw_device
}

# Program the FPGA
program_hw_devices $hw_device
puts "Bitstream deployed successfully."

# Disconnect
close_hw_target $hw_tgt
disconnect_hw_server
close_hw_manager
puts "Disconnected from HW server."
