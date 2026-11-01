//=============================================================================
// Module  : clock_gate_ctrl
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/variant2_clock_gating/clock_gate_ctrl.v
//
// Purpose : Derives per-block clock gating enables from BIST controller
//           outputs. Each BIST block receives its clock only when required
//           by the current FSM state.
//
// Gating Policy:
//  Block  | SEED_LOAD | TEST_RUN | All other states
//  -------|-----------|----------|------------------
//  LFSR   |    ON     |    ON    |      OFF
//  MAC    |    OFF    |    ON    |      OFF
//  MISR   |    OFF    |    ON    |      OFF
//
// Language: Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module clock_gate_ctrl (
    // Ungated system clock
    input  wire clk,

    // Enables from bist_controller
    input  wire lfsr_en,
    input  wire mac_en,
    input  wire misr_en,
    input  wire seed_load,    // LFSR needs clock during seed load too
    input  wire test_en_scan, // Scan test bypass (tie to 0 in normal mode)

    // Gated clock outputs
    output wire clk_lfsr,
    output wire clk_mac,
    output wire clk_misr
);

    wire lfsr_cg_en;
    assign lfsr_cg_en = lfsr_en | seed_load;

    icg_cell u_icg_lfsr (
        .clk      (clk),
        .enable   (lfsr_cg_en),
        .test_en  (test_en_scan),
        .gated_clk(clk_lfsr)
    );

    icg_cell u_icg_mac (
        .clk      (clk),
        .enable   (mac_en),
        .test_en  (test_en_scan),
        .gated_clk(clk_mac)
    );

    icg_cell u_icg_misr (
        .clk      (clk),
        .enable   (misr_en),
        .test_en  (test_en_scan),
        .gated_clk(clk_misr)
    );

endmodule
