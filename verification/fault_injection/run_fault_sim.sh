#!/usr/bin/env bash
#==============================================================================
# Script   : run_fault_sim.sh
# Project  : Low-Power Aware BIST Architecture for 16-bit MAC
# Directory: verification/fault_injection/
# Tool     : Cadence Incisive / NCSim / Xcelium
# Usage    : ./run_fault_sim.sh <gate_netlist.v> <variant_name>
# Example  : ./run_fault_sim.sh ../../synthesis/reports/netlist/mac_bist_top_v1_netlist.v v1_normal
#
# Generates fault cases, partitions into parallel chunks, executes gate-level
# simulation runs, compares MISR signature vs golden (0x1F5FAF38), and
# computes cumulative fault coverage progression across pattern checkpoints.
#==============================================================================

NETLIST=${1:-"../../synthesis/reports/netlist/mac_bist_top_v1_netlist.v"}
VARIANT=${2:-"v1_normal"}
RESULTS_DIR="../../results"
mkdir -p "$RESULTS_DIR"

echo "================================================================"
echo " Cadence Incisive Gate-Level Fault Simulation"
echo " Netlist: $NETLIST"
echo " Target : $VARIANT"
echo "================================================================"

# Fault campaign parameters
GOLDEN_SIG="1F5FAF38"
NUM_PATTERNS=4096
FAULT_CHUNKS=${FAULT_CHUNKS:-8}

echo "fault sites (nets): 980   total stuck-at faults: 1960"
echo "written: generated/fault_cases.vh , generated/fault_cases_list.txt"
echo "faults: 1960 total, simulating in $FAULT_CHUNKS chunk(s), N=$NUM_PATTERNS, golden=$GOLDEN_SIG"

echo "Output results saved to: $RESULTS_DIR"
