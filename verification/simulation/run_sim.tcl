#==============================================================================
# Script   : run_sim.tcl
# Project  : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
# Directory: verification/simulation/
# Tool     : Questa/ModelSim
# Usage    : vsim -c -do run_sim.tcl
#
# Runs simulation for all six variant testbenches sequentially.
#==============================================================================

set tbs {
    tb_mac_bist_v1
    tb_mac_bist_v2
    tb_mac_bist_v3
    tb_mac_bist_v4
    tb_mac_bist_v5
    tb_mac_bist_v6
}

foreach tb $tbs {
    puts "\n================================================================"
    puts " RUNNING TESTBENCH: $tb"
    puts "================================================================"
    vsim -c -voptargs=+acc $tb
    run -all
}

puts "\n================================================================"
puts " ALL VARIANT SIMULATIONS FINISHED"
puts "================================================================"
quit -f
