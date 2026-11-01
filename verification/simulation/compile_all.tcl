#==============================================================================
# Script   : compile_all.tcl
# Project  : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
# Directory: verification/simulation/
# Tool     : Questa/ModelSim (vlog/vsim)
# Usage    : Run from verification/simulation:
#            vsim -c -do "do compile_all.tcl; quit -f"
#
# Compiles all standard Verilog-2001 (.v) RTL sources for all 6 variants
# and all 6 variant testbenches.
#==============================================================================

set RTL_DIR "../../rtl"
set TB_DIR  "../testbench"

# Create fresh work library
if {[file exists work]} {
    vdel -all -lib work
}
vlib work
vmap work work

puts "================================================================"
puts " Compiling Common Verilog Modules (Verilog-2001)"
puts "================================================================"

set common_files {
    lfsr_tpg.v
    mac_16bit.v
    misr_ora.v
    bist_controller.v
    signature_comparator.v
    golden_signature_reg.v
}

foreach f $common_files {
    set fpath "${RTL_DIR}/common/${f}"
    puts "  Compiling: $fpath"
    if {[catch {vlog -vlog01compat -work work $fpath} msg]} {
        puts "ERROR: Failed to compile $fpath"
        puts $msg
        quit -f
    }
}

puts "\n================================================================"
puts " Compiling Variant 1 — Baseline"
puts "================================================================"
vlog -vlog01compat -work work "${RTL_DIR}/baseline/mac_bist_top_v1.v"

puts "\n================================================================"
puts " Compiling Variant 2 — Clock Gating"
puts "================================================================"
vlog -vlog01compat -work work "${RTL_DIR}/low_power/clock_gating/icg_cell.v"
vlog -vlog01compat -work work "${RTL_DIR}/low_power/clock_gating/clock_gate_ctrl.v"
vlog -vlog01compat -work work "${RTL_DIR}/low_power/clock_gating/mac_bist_top_v2.v"

puts "\n================================================================"
puts " Compiling Variant 3 — Operand Isolation"
puts "================================================================"
vlog -vlog01compat -work work "${RTL_DIR}/low_power/operand_isolation/operand_isolation_cell.v"
vlog -vlog01compat -work work "${RTL_DIR}/low_power/operand_isolation/isolation_enable_ctrl.v"
vlog -vlog01compat -work work "${RTL_DIR}/low_power/operand_isolation/mac_bist_top_v3.v"

puts "\n================================================================"
puts " Compiling Variant 4 — Bus Inversion"
puts "================================================================"
vlog -vlog01compat -work work "${RTL_DIR}/low_power/bus_inversion/bus_invert_encoder.v"
vlog -vlog01compat -work work "${RTL_DIR}/low_power/bus_inversion/bus_invert_decoder.v"
vlog -vlog01compat -work work "${RTL_DIR}/low_power/bus_inversion/mac_bist_top_v4.v"

puts "\n================================================================"
puts " Compiling Variant 5 — Combined (All)"
puts "================================================================"
vlog -vlog01compat -work work "${RTL_DIR}/low_power/combined_all/mac_bist_top_v5.v"

puts "\n================================================================"
puts " Compiling Variant 6 — Combined (Operand Isolation + Clock Gating)"
puts "================================================================"
vlog -vlog01compat -work work "${RTL_DIR}/low_power/combined_oi_cg/mac_bist_top_v6.v"

puts "\n================================================================"
puts " Compiling Testbenches"
puts "================================================================"
vlog -vlog01compat -work work "${TB_DIR}/tb_mac_bist_v1.v"
vlog -vlog01compat -work work "${TB_DIR}/tb_mac_bist_v2.v"
vlog -vlog01compat -work work "${TB_DIR}/tb_mac_bist_v3.v"
vlog -vlog01compat -work work "${TB_DIR}/tb_mac_bist_v4.v"
vlog -vlog01compat -work work "${TB_DIR}/tb_mac_bist_v5.v"
vlog -vlog01compat -work work "${TB_DIR}/tb_mac_bist_v6.v"

puts "\n================================================================"
puts " Verilog Compilation Complete — All 6 Variants Ready"
puts "================================================================"
