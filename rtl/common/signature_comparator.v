//=============================================================================
// Module  : signature_comparator
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/common/signature_comparator.v
//
// Purpose : Compares the captured MISR signature against the golden (fault-free)
//           reference signature. Generates a single-bit PASS/FAIL result.
//
// Operation:
//   When compare_en is asserted (COMPARE FSM state), the comparator latches
//   the result of (misr_sig == golden_sig) into a register.
//   comb_match provides immediate combinational comparison to the FSM.
//
// Language: Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module signature_comparator #(
    parameter WIDTH = 32   // Must match MISR width
) (
    input  wire             clk,
    input  wire             rst,        // Synchronous active-high reset
    input  wire             compare_en, // Strobe from bist_controller (COMPARE state)
    input  wire [WIDTH-1:0] misr_sig,   // Captured MISR signature
    input  wire [WIDTH-1:0] golden_sig, // Golden (fault-free) reference
    output reg              match,      // 1 = signatures match (registered)
    output wire             comb_match, // 1 = combinational match (for FSM)
    output reg              mismatch    // 1 = fault detected (registered)
);

    // Combinational comparison
    assign comb_match = (misr_sig == golden_sig);

    // Register result on compare_en pulse; hold until reset
    always @(posedge clk) begin
        if (rst) begin
            match    <= 1'b0;
            mismatch <= 1'b0;
        end else if (compare_en) begin
            match    <=  comb_match;
            mismatch <= ~comb_match;
        end
    end

    // synthesis translate_off
    always @(posedge clk) begin
        if (!rst && compare_en) begin
            if (comb_match)
                $display("[sig_cmp] t=%0t PASS: MISR=0x%08h matches golden=0x%08h",
                         $time, misr_sig, golden_sig);
            else
                $display("[sig_cmp] t=%0t FAIL: MISR=0x%08h != golden=0x%08h",
                         $time, misr_sig, golden_sig);
        end
    end
    // synthesis translate_on

endmodule
