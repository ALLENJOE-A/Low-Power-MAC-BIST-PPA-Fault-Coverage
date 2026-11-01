#==============================================================================
# Script   : extract_reports.tcl
# Project  : Low-Power Aware BIST Architecture for 16-bit MAC (Standard Verilog)
# Directory: synthesis/scripts/
# Tool     : Tcl shell / Genus post-processing
# Purpose  : Parse area, power, timing reports from synthesis and generate PPA table.
#==============================================================================

set SCRIPT_DIR [file dirname [info script]]
set AREA_DIR   [file normalize "${SCRIPT_DIR}/../reports/area"]
set POWER_DIR  [file normalize "${SCRIPT_DIR}/../reports/power"]
set TIMING_DIR [file normalize "${SCRIPT_DIR}/../reports/timing"]

puts "====================================================================================="
puts "                 PPA COMPARISON TABLE — MAC BIST (Standard Verilog)                  "
puts "====================================================================================="
puts [format "%-8s | %-12s | %-12s | %-12s | %-12s | %-10s" \
      "Variant" "Cell Area" "Total Area" "Dyn Power" "Leak Power" "Slack (ns)"]
puts "-------------------------------------------------------------------------------------"

for {set v 1} {$v <= 6} {incr v} {
    set area_file   "${AREA_DIR}/area_v${v}.rpt"
    set power_file  "${POWER_DIR}/power_v${v}.rpt"
    set timing_file "${TIMING_DIR}/timing_v${v}.rpt"

    set cell_area "N/A"
    set tot_area  "N/A"
    set dyn_pwr   "N/A"
    set leak_pwr  "N/A"
    set slack     "N/A"

    if {[file exists $area_file]} {
        set fh [open $area_file r]
        while {[gets $fh line] >= 0} {
            if {[regexp -nocase {total area\s*:\s*([0-9\.]+)} $line m val]} { set tot_area $val }
            if {[regexp -nocase {cell area\s*:\s*([0-9\.]+)} $line m val]}  { set cell_area $val }
        }
        close $fh
    }

    if {[file exists $power_file]} {
        set fh [open $power_file r]
        while {[gets $fh line] >= 0} {
            if {[regexp -nocase {dynamic power\s*:\s*([0-9\.]+)} $line m val]} { set dyn_pwr $val }
            if {[regexp -nocase {leakage power\s*:\s*([0-9\.]+)} $line m val]} { set leak_pwr $val }
        }
        close $fh
    }

    if {[file exists $timing_file]} {
        set fh [open $timing_file r]
        while {[gets $fh line] >= 0} {
            if {[regexp -nocase {slack\s*:\s*([-\+0-9\.]+)} $line m val]} { set slack $val }
        }
        close $fh
    }

    puts [format "V%-7d | %-12s | %-12s | %-12s | %-12s | %-10s" \
          $v $cell_area $tot_area $dyn_pwr $leak_pwr $slack]
}
puts "====================================================================================="
