//=============================================================================
// Module  : golden_signature_reg
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/common/golden_signature_reg.v
//
// Purpose : Stores the fault-free (golden) MISR signature for use by the
//           signature comparator during BIST verification.
//
// Usage:
//   - GOLDEN_SIG parameter is set at elaboration time.
//   - golden_out is wired directly to signature_comparator.golden_sig.
//   - The register also supports a runtime load (load_en + load_val) for
//     testbench flexibility during fault injection regression.
//
// Language: Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module golden_signature_reg #(
    parameter WIDTH      = 32,
    parameter [31:0] GOLDEN_SIG = 32'h036ce3d3
) (
    input  wire             clk,
    input  wire             rst,        // Synchronous active-high reset
    input  wire             load_en,    // 1 = load load_val into register
    input  wire [WIDTH-1:0] load_val,   // Value to load (from sim/script)
    output wire [WIDTH-1:0] golden_out  // Golden signature -> comparator
);

    reg [WIDTH-1:0] golden_reg;

    always @(posedge clk) begin
        if (rst)
            golden_reg <= GOLDEN_SIG[WIDTH-1:0];
        else if (load_en)
            golden_reg <= load_val;
    end

    assign golden_out = golden_reg;

    // synthesis translate_off
    initial begin
        if (GOLDEN_SIG === 32'hDEAD_BEEF) begin
            $display("[golden_sig_reg] WARNING: GOLDEN_SIG is still placeholder DEAD_BEEF");
        end else begin
            $display("[golden_sig_reg] INFO: Golden signature = 0x%08h", GOLDEN_SIG);
        end
    end
    // synthesis translate_on

endmodule
