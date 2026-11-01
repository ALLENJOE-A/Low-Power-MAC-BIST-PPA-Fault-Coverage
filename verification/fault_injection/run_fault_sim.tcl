#==============================================================================
# Script   : run_fault_sim.tcl
# Project  : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
# Directory: verification/fault_injection/
# Tool     : Questa/ModelSim
# Purpose  : Automated stuck-at fault injection and coverage measurement.
#
# Model    : Single Stuck-At (SA0 and SA1) on DUT signals
# Detection: Faulty MISR signature != golden MISR signature (0x036ce3d3)
#
# Usage    : vsim -c -do run_fault_sim.tcl
#==============================================================================

set SCRIPT_DIR [file dirname [info script]]
set OUTDIR     [file normalize "${SCRIPT_DIR}/../../results"]
file mkdir $OUTDIR
set REPORT     "${OUTDIR}/fault_coverage_report.txt"

set GOLDEN_SIG "0x036ce3d3"
set DUT_PATH   "/tb_mac_bist_v1/u_dut"

puts "================================================================"
puts " Starting RTL Fault Simulation (Verilog-2001)"
puts " Golden Reference: $GOLDEN_SIG"
puts "================================================================"

# List of target nets for fault injection
set fault_nets {
    "/tb_mac_bist_v1/u_dut/u_mac/mac_out[0]"
    "/tb_mac_bist_v1/u_dut/u_mac/mac_out[1]"
    "/tb_mac_bist_v1/u_dut/u_mac/mac_out[2]"
    "/tb_mac_bist_v1/u_dut/u_mac/mac_out[3]"
    "/tb_mac_bist_v1/u_dut/u_mac/mac_out[4]"
    "/tb_mac_bist_v1/u_dut/u_mac/mac_out[7]"
    "/tb_mac_bist_v1/u_dut/u_mac/mac_out[15]"
    "/tb_mac_bist_v1/u_dut/u_mac/mac_out[31]"
    "/tb_mac_bist_v1/u_dut/u_mac/op_a[0]"
    "/tb_mac_bist_v1/u_dut/u_mac/op_a[7]"
    "/tb_mac_bist_v1/u_dut/u_mac/op_a[15]"
    "/tb_mac_bist_v1/u_dut/u_mac/op_b[0]"
    "/tb_mac_bist_v1/u_dut/u_mac/op_b[7]"
    "/tb_mac_bist_v1/u_dut/u_mac/op_b[15]"
}

set total_faults 0
set detected_faults 0

set rpt_fh [open $REPORT w]
puts $rpt_fh "================================================================"
puts $rpt_fh " FAULT SIMULATION REPORT — MAC BIST (Verilog-2001)"
puts $rpt_fh " Golden Signature: $GOLDEN_SIG"
puts $rpt_fh "================================================================"

foreach net $fault_nets {
    foreach sa {0 1} {
        incr total_faults
        vsim -c -voptargs=+acc tb_mac_bist_v1
        
        # Reset DUT
        force /tb_mac_bist_v1/rst 1
        run 50 ns
        force /tb_mac_bist_v1/rst 0
        run 10 ns

        # Start BIST
        force /tb_mac_bist_v1/bist_start 1
        run 10 ns
        force /tb_mac_bist_v1/bist_start 0
        run 10 ns

        # Inject stuck-at fault during test execution
        force $net $sa

        # Run until completion
        run 3000 ns

        set final_sig [examine -radix hex /tb_mac_bist_v1/u_dut/captured_sig]
        release $net

        if {$final_sig ne "036ce3d3"} {
            incr detected_faults
            set status "DETECTED"
        } else {
            set status "UNDETECTED"
        }

        puts "Fault #$total_faults: $net SA$sa -> MISR: 0x$final_sig \[$status\]"
        puts $rpt_fh "Fault #$total_faults: $net SA$sa -> MISR: 0x$final_sig \[$status\]"
    }
}

set fc_pct [expr {($detected_faults * 100.0) / $total_faults}]
puts "\n================================================================"
puts " Total Faults Injected : $total_faults"
puts " Detected Faults       : $detected_faults"
puts " Fault Coverage        : [format "%.2f" $fc_pct]%"
puts "================================================================"

puts $rpt_fh "\n================================================================"
puts $rpt_fh " Total Faults Injected : $total_faults"
puts $rpt_fh " Detected Faults       : $detected_faults"
puts $rpt_fh " Fault Coverage        : [format "%.2f" $fc_pct]%"
puts $rpt_fh "================================================================"
close $rpt_fh

puts "Report written to: $REPORT"
quit -f
