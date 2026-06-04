# Copyright 2023 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Authors:
# - Tobias Senti      <tsenti@ethz.ch>
# - Jannis Schönleber <janniss@iis.ee.ethz.ch>
# - Philippe Sauter   <phsauter@iis.ee.ethz.ch>

source scripts/startup.tcl
load_checkpoint 03_${proj_name}.cts
setDefaultParasitics
set_dont_use $dont_use_cells

utl::report "###############################################################################"
utl::report "# Stage 04: ROUTING"
utl::report "###############################################################################"

utl::report "###############################################################################"
utl::report "# 04-01: Global Route"
utl::report "###############################################################################"

set_global_routing_layer_adjustment TopMetal1 0.20
set_routing_layers -signal Metal2-TopMetal1 -clock Metal2-TopMetal1

utl::report "Global route"
global_route \
    -guide_file ${report_dir}/04_${proj_name}_route.guide \
    -congestion_report_file ${report_dir}/04_${proj_name}_route_congestionrpt \
    -allow_congestion

utl::report "Estimate parasitics"
estimate_parasitics -global_routing
report_metrics "04-01_${proj_name}.grt"
save_checkpoint 04-01_${proj_name}.grt
report_image "04-01_${proj_name}.grt" true false false true

grt::set_verbose 0

# ---------------------------------------------------------------------------
# Helper procs
# ---------------------------------------------------------------------------
proc get_wns {} {
    return [sta::worst_slack -max]
}

proc get_tns {} {
    return [sta::total_negative_slack -max]
}

proc get_hold_wns {} {
    return [sta::worst_slack -min]
}

proc has_drc_violations {} {
    set reports [list [report_check_types -max_fanout] \
                      [report_check_types -max_slew] \
                      [report_check_types -max_capacitance]]

    foreach rpt $reports {
        # Check if the string contains the word "violated" 
        # (Case-insensitive check is safer)
        if {[string match -nocase "*violated*" $rpt]} {
            return 1
        }
    }
    return 0
}
# ---------------------------------------------------------------------------
# repair_design loop
# ---------------------------------------------------------------------------
utl::report "###############################################################################"
utl::report "# Iterative repair_design"
utl::report "###############################################################################"

set max_iter 40
set iter     0
set prev_wns [get_wns]

while {$iter < $max_iter} {
    incr iter
    utl::report "repair_design iteration $iter"
    repair_design -verbose

    set wns [get_wns]
    utl::report "  WNS after iter $iter: $wns"

    if {$wns >= 0} {
        utl::report "  No setup violations. Done."
        break
    }
    if {$wns >= $prev_wns} {
        utl::report "  No improvement. Stopping."
        break
    }
    set prev_wns $wns
}

# ---------------------------------------------------------------------------
# Setup repair loop — interleaved repair_design + repair_timing
# ---------------------------------------------------------------------------
utl::report "###############################################################################"
utl::report "# Iterative repair_timing -setup"
utl::report "###############################################################################"

set max_iter 40
set iter     0
set prev_wns [get_wns]
set prev_tns [get_tns]

while {$iter < $max_iter} {
    incr iter
    set wns [get_wns]
    set tns [get_tns]

    utl::report "Setup repair iter $iter — WNS: $wns  TNS: $tns"

    if {$wns >= 0} {
        utl::report "  All setup violations closed. Done."
        break
    }

    repair_design -verbose
    repair_timing -setup -verbose -repair_tns 100

    set new_wns [get_wns]
    set new_tns [get_tns]
    utl::report "  After repair: WNS: $new_wns  TNS: $new_tns"

    if {$new_wns >= $prev_wns && $new_tns >= $prev_tns} {
        utl::report "  No improvement. Stopping setup repair loop."
        break
    }

    set prev_wns $new_wns
    set prev_tns $new_tns
}

if {[get_wns] < 0} {
    utl::report "WARNING: Setup violations remain — WNS=[get_wns] TNS=[get_tns]"
}

# ---------------------------------------------------------------------------
# Hold repair loop
# ---------------------------------------------------------------------------
utl::report "###############################################################################"
utl::report "# Iterative repair_timing -hold"
utl::report "###############################################################################"

set max_iter 40
set iter     0
set prev_hold_wns [get_hold_wns]

while {$iter < $max_iter} {
    incr iter
    set hold_wns [get_hold_wns]

    utl::report "Hold repair iter $iter — Hold WNS: $hold_wns"

    if {$hold_wns >= 0} {
        utl::report "  All hold violations closed. Done."
        break
    }

    repair_timing -hold -hold_margin 0.1 -verbose -repair_tns 100

    set new_hold_wns [get_hold_wns]
    utl::report "  After repair: Hold WNS: $new_hold_wns"

    if {$new_hold_wns >= $prev_hold_wns} {
        utl::report "  No improvement. Stopping hold repair loop."
        break
    }

    set prev_hold_wns $new_hold_wns
}

if {[get_hold_wns] < 0} {
    utl::report "WARNING: Hold violations remain — WNS=[get_hold_wns]"
}

# ---------------------------------------------------------------------------
# GRT incremental + detailed placement
# ---------------------------------------------------------------------------
utl::report "GRT incremental..."
global_route -start_incremental -allow_congestion
detailed_placement
global_route -end_incremental \
    -guide_file ${report_dir}/04_${proj_name}_route.guide \
    -congestion_report_file ${report_dir}/04_${proj_name}_route_congestion.rpt \
    -allow_congestion \
    -verbose

estimate_parasitics -global_routing
report_metrics "04-01_${proj_name}.grt_repaired"
save_checkpoint 04-01_${proj_name}.grt_repaired
report_image "04-01_${proj_name}.grt_repaired" true true false true

# ---------------------------------------------------------------------------
# Post-GRT setup repair loop
# ---------------------------------------------------------------------------
utl::report "###############################################################################"
utl::report "# Post-GRT iterative repair_timing -setup"
utl::report "###############################################################################"

set max_iter 40
set iter     0
set prev_wns [get_wns]
set prev_tns [get_tns]

while {$iter < $max_iter} {
    incr iter
    set wns [get_wns]
    set tns [get_tns]
    set drc_failed [has_drc_violations]


    utl::report "Post-GRT setup repair iter $iter — WNS: $wns  TNS: $tns | DRV Violations: $drc_failed"

    if {$wns >= 0 && !$drc_failed} {
        utl::report "  Design is clean (Timing and DRC). Done."
        break
    }

    repair_design -verbose
    repair_timing -setup -verbose -repair_tns 100
    detailed_placement
    estimate_parasitics -global_routing

    set new_wns [get_wns]
    set new_tns [get_tns]
    set drc_still_failed [has_drc_violations]

    utl::report "  After repair: WNS: $new_wns  TNS: $new_tns | DRC Violations: $drc_still_failed"

    if {$new_wns >= $prev_wns && $new_tns >= $prev_tns && !$drc_still_failed} {
        utl::report "  No further improvement in timing or DRC. Stopping."
        break
    }

    set prev_wns $new_wns
    set prev_tns $new_tns
}

# ---------------------------------------------------------------------------
# 04-02: Detailed Route
# ---------------------------------------------------------------------------
utl::report "###############################################################################"
utl::report "# 04-02: Detailed Route"
utl::report "###############################################################################"

repair_antennas -ratio_margin 30 -iterations 5

utl::report "Detailed route"
set_thread_count 8
detailed_route \
    -output_drc ${report_dir}/04_${proj_name}_route_drc.rpt \
    -drc_report_iter_step 5 \
    -save_guide_updates \
    -clean_patches \
    -droute_end_iter 30 \
    -verbose 1

# ---------------------------------------------------------------------------
# Post detailed-route repair loop
# CRITICAL: Must clear parasitics state after detailed_route
# before calling estimate_parasitics again — otherwise EST-0104
# ---------------------------------------------------------------------------
utl::report "###############################################################################"
utl::report "# Post detailed-route iterative repair"
utl::report "###############################################################################"

set max_iter 40
set iter     0

# estimate_parasitics -global_routing causes EST-0104 after detailed_route
# Use -placement instead which does not conflict with detailed route state
estimate_parasitics -placement

set prev_wns [get_wns]
set prev_tns [get_tns]
utl::report "Initial post-DRT — WNS: $prev_wns  TNS: $prev_tns"

while {$iter < $max_iter} {
    incr iter
    set wns [get_wns]
    set tns [get_tns]

    utl::report "Post-DRT repair iter $iter — WNS: $wns  TNS: $tns"

    if {$wns >= 0} {
        utl::report "  Setup clean after detailed route. Done."
        break
    }

    # Repair timing with placement parasitics
    repair_timing -setup -verbose -repair_tns 100
    detailed_placement

    # Route new nets inserted by repair_timing
    global_route -start_incremental -allow_congestion
    global_route -end_incremental \
        -guide_file ${report_dir}/04_${proj_name}_postdrt_${iter}.guide \
        -congestion_report_file \
            ${report_dir}/04_${proj_name}_postdrt_${iter}.rpt \
        -allow_congestion

    # Route only new nets from buffer insertion
    detailed_route \
        -output_drc ${report_dir}/04_${proj_name}_postdrt_${iter}_drc.rpt \
        -droute_end_iter 5 \
        -verbose 0

    # Re-read parasitics using placement — safe after detailed_route
    estimate_parasitics -placement

    set new_wns [get_wns]
    set new_tns [get_tns]
    utl::report "  After repair: WNS: $new_wns  TNS: $new_tns"

    if {$new_wns >= $prev_wns && $new_tns >= $prev_tns} {
        utl::report "  No improvement. Stopping post-DRT repair."
        break
    }

    set prev_wns $new_wns
    set prev_tns $new_tns
}

# ---------------------------------------------------------------------------
# Final timing summary
# ---------------------------------------------------------------------------
set final_wns      [get_wns]
set final_tns      [get_tns]
set final_hold_wns [get_hold_wns]

utl::report "###############################################################################"
utl::report "# Final Timing Summary"
utl::report "###############################################################################"
utl::report "  Setup WNS : $final_wns"
utl::report "  Setup TNS : $final_tns"
utl::report "  Hold  WNS : $final_hold_wns"

if {$final_wns < 0} {
    utl::report "WARNING: Remaining setup violations — WNS=$final_wns TNS=$final_tns"
    utl::report "WARNING: WNS of ~48ps — likely needs SDC multicycle path or clock relaxation"
    report_checks -path_delay max \
        -endpoint_count 10 \
        -fields {slew cap nets fanout} \
        -format full_clock_expanded
} else {
    utl::report "INFO: Setup timing clean."
}

if {$final_hold_wns < 0} {
    utl::report "WARNING: Remaining hold violations — WNS=$final_hold_wns"
} else {
    utl::report "INFO: Hold timing clean."
}

utl::report "Saving detailed route"
save_checkpoint 04_${proj_name}.routed
report_metrics "04_${proj_name}.routed"
report_image "04_${proj_name}.routed" true false false true

utl::report "###############################################################################"
utl::report "# Stage 04 complete: Checkpoint saved to ${save_dir}/04_${proj_name}.routed.zip"
utl::report "###############################################################################"
