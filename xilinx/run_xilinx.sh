#!/bin/bash
# Copyright (c) 2026 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Authors:
# - Thomas Benz     <tbenz@iis.ee.ethz.ch>
# - Enrico Zelioli  <ezelioli@iis.ee.ethz.ch>

set -e # Exit on error
set -u # Error on undefined vars

################
# Setup
################
# Source environment
source "../env.sh"

VIVADO=${VIVADO:-"vitis-2022.1 vivado"}

mkdir -p build
mkdir -p out
mkdir -p build/genesys2.clkwiz
mkdir -p build/genesys2.vio
mkdir -p build/genesys2.croc

################
# Helpers
################

show_help() {
  cat <<EOF
Xilinx Coordinator

Usage:
    ./run_xilinx.sh [OPTIONS]

Options:
    --help, -h          Show this help message
    --dry-run, -n       Only print commands instead of executing
    --verbose, -v       Print commands while executing
    --flist             Regenerate compile script reading sources (add_sources.genesys2.tcl)
    --clkwiz            Implement build/genesys2.clkwiz
    --vio               Implement build/genesys2.vio
    --croc              Implement Croc SoC only
    --all               Implement clkwiz, vio, and Croc SoC
    --deploy            Deploy bitstream to hardware (auto-discovers FPGA via JTAG)
    --bitstream FILE    Bitstream file for deploy (default: out/croc.genesys2.bit)
    --ltx FILE          Debug probes file for deploy (optional)

Example:
    ./run_xilinx.sh --all
    ./run_xilinx.sh --deploy
    ./run_xilinx.sh --deploy --bitstream out_50/croc.genesys2.bit

EOF
  exit 0
}

run_cmd() {
  if [ "$DRYRUN" = 1 ]; then
    echo $1
  else
    eval $1
  fi
}

generate_flist() {
  run_cmd "echo [INFO][Bender] Generate add_sources.genesys2.tcl"
  run_cmd "bender \
        script vivado \
        -t genesys2 \
        -t synthesis \
        -D COMMON_CELLS_ASSERTS_OFF=1 \
        > scripts/add_sources.genesys2.tcl"

  run_cmd "echo [INFO][Bender] Remove absolute paths"
  run_cmd "sed -i 's|${CROC_ROOT}|../../..|g' scripts/add_sources.genesys2.tcl"

  run_cmd "echo [INFO][Bender] File list generated: add_sources.genesys2.tcl"
}

impl_clockwiz() {
  run_cmd "echo [INFO][VIVADO] Implement clock wizard IP"
  run_cmd "cd build/genesys2.clkwiz"
  run_cmd "${VIVADO} -mode batch -source ../../scripts/impl_ip.tcl \
        -tclargs genesys2 clkwiz > ../../clkwiz.log"
  run_cmd "cd ../.."
}

impl_vio() {
  run_cmd "echo [INFO][VIVADO] Implement VirtualIO IP"
  run_cmd "cd build/genesys2.vio"
  run_cmd "${VIVADO} -mode batch -source ../../scripts/impl_ip.tcl \
        -tclargs genesys2 vio > ../../vio.log"
  run_cmd "cd ../.."
}

impl_croc() {
  run_cmd "echo [INFO][VIVADO] Implement Croc"
  run_cmd "cd build/genesys2.croc"
  run_cmd "${VIVADO} -mode batch -source ../../scripts/impl_sys.tcl \
        -tclargs genesys2 croc ../genesys2.clkwiz/out.xci ../genesys2.vio/out.xci  > ../../croc.log"
  run_cmd "cd ../.."
}

deploy_bitstream() {
  local bitstream="${DEPLOY_BITSTREAM:-out/croc.genesys2.bit}"
  local ltx="${DEPLOY_LTX:-}"

  if [ ! -f "$bitstream" ]; then
    echo "[ERROR] Bitstream file not found: $bitstream" >&2
    exit 1
  fi

  local tcl_args="$bitstream"
  if [ -n "$ltx" ]; then
    if [ ! -f "$ltx" ]; then
      echo "[ERROR] LTX file not found: $ltx" >&2
      exit 1
    fi
    tcl_args="$tcl_args $ltx"
  fi

  run_cmd "echo [INFO][VIVADO] Deploying bitstream: $bitstream"
  run_cmd "${VIVADO} -mode batch -source scripts/deploy.tcl -tclargs ${tcl_args}"
}

####################
# Parse Arguments
####################

DRYRUN=0
DEPLOY_ACTION=0

# default action if no argument is given
if [ $# -eq 0 ]; then
  show_help
  return 0
fi

# check for global arguments
for arg in "$@"; do
  [[ "$arg" == -v || "$arg" == --verbose ]] && set -x
  [[ "$arg" == -n || "$arg" == --dry-run ]] && DRYRUN=1
done

# parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
  --help | -h)
    show_help
    ;;
  --verbose | -v)
    shift
    ;;
  --dry-run | -n)
    shift
    ;;
  # script-specific commands
  --flist)
    generate_flist
    shift
    ;;
  --clkwiz)
    impl_clockwiz
    shift
    ;;
  --vio)
    impl_vio
    shift
    ;;
  --croc)
    impl_croc
    shift
    ;;
  --all)
    impl_clockwiz
    impl_vio
    impl_croc
    shift
    ;;
  # deploy commands
  --deploy)
    DEPLOY_ACTION=1
    shift
    ;;
  --bitstream)
    DEPLOY_BITSTREAM="$2"
    shift 2
    ;;
  --ltx)
    DEPLOY_LTX="$2"
    shift 2
    ;;
  # Error handling
  *)
    echo "[ERROR] Unknown option: $1 (use --help for usage)" >&2
    exit 1
    ;;
  esac
done

# Execute deploy if requested
if [ "$DEPLOY_ACTION" = 1 ]; then
  deploy_bitstream
fi
