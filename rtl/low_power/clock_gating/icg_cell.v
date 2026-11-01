//=============================================================================
// Module  : icg_cell
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/variant2_clock_gating/icg_cell.v
//
// Purpose : Synthesizable Integrated Clock Gating (ICG) cell.
//           Prevents glitches on the gated clock by using a negative-level
//           transparent latch to sample the enable, then ANDing with the clock.
//
// ICG Timing Safety:
//   - Latch is TRANSPARENT when CLK = 0 (low phase).
//   - Enable transitions are only sampled during CLK = 0.
//   - The AND gate activates only when CLK = 1 (high phase).
//   - Therefore, latch output cannot change during CLK = 1.
//   - This guarantees no spurious rising edges on gated_clk.
//
// Language: Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module icg_cell (
    input  wire clk,       // Clock input (ungated)
    input  wire enable,    // Gating enable (active-high: 1 = clock passes)
    input  wire test_en,   // Scan test override (bypass gating during scan)
    output wire gated_clk  // Gated clock output
);

    reg latch_enable;

    // Negative-level sensitive transparent latch (transparent when clk is low)
    always @(clk or enable or test_en) begin
        if (~clk)
            latch_enable <= enable | test_en;
    end

    // Glitch-free gated clock
    assign gated_clk = clk & latch_enable;

endmodule
