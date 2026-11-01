//=============================================================================
// Module  : mac_bist_top_v2  (Variant 2 - Clock Gating)
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/variant2_clock_gating/mac_bist_top_v2.v
//
// Purpose : Clock-gated BIST top-level. Identical to Variant 1 except that
//           separate gated clocks are generated for LFSR, MAC, and MISR.
//           Each block's clock is only enabled when that block is required.
//
// Gating Summary:
//   clk_lfsr : ON during SEED_LOAD + TEST_RUN
//   clk_mac  : ON during TEST_RUN only
//   clk_misr : ON during TEST_RUN only
//   All gated: OFF during IDLE, SIGNATURE_CAPTURE, COMPARE, PASS, FAIL
//
// Language: Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module mac_bist_top_v2 #(
    parameter [31:0] GOLDEN_SIG  = 32'h036ce3d3,
    parameter        TEST_CYCLES = 256,
    parameter [15:0] SEED_A      = 16'hACE1,
    parameter [15:0] SEED_B      = 16'h1234,
    parameter [15:0] POLY_A      = 16'hD008,
    parameter [15:0] POLY_B      = 16'hB400
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        bist_start,
    input  wire        test_en_scan,  // Scan bypass for ICG cells
    input  wire [15:0] seed_a_in,
    input  wire [15:0] seed_b_in,
    input  wire        golden_load,
    input  wire [31:0] golden_val,
    output wire        bist_done,
    output wire        bist_pass,
    output wire        bist_fail,
    output wire [31:0] misr_sig,
    output wire [2:0]  state_dbg
);

    //=========================================================================
    // Internal signals
    //=========================================================================
    wire        lfsr_en, mac_en, misr_en;
    wire        seed_load, capture, compare_en;
    wire        sig_match;
    wire        sig_comb_match;
    wire        sig_mismatch;
    wire [15:0] op_a, op_b;
    wire [31:0] mac_out;
    wire [39:0] accum;
    wire [31:0] misr_sig_int;
    reg  [31:0] captured_sig;
    wire [31:0] golden_sig_wire;

    // Gated clocks
    wire        clk_lfsr, clk_mac, clk_misr;

    //=========================================================================
    // BIST Controller (uses ungated system clock)
    //=========================================================================
    bist_controller #(
        .TEST_CYCLES(TEST_CYCLES),
        .CNT_WIDTH  (9)
    ) u_ctrl (
        .clk            (clk),
        .rst            (rst),
        .bist_start     (bist_start),
        .signature_match(sig_comb_match),
        .lfsr_en        (lfsr_en),
        .mac_en         (mac_en),
        .misr_en        (misr_en),
        .seed_load      (seed_load),
        .capture        (capture),
        .compare_en     (compare_en),
        .bist_done      (bist_done),
        .bist_pass      (bist_pass),
        .bist_fail      (bist_fail),
        .state_dbg      (state_dbg)
    );

    //=========================================================================
    // Clock Gate Controller - derives gated clocks from FSM enables
    //=========================================================================
    clock_gate_ctrl u_cg_ctrl (
        .clk         (clk),
        .lfsr_en     (lfsr_en),
        .mac_en      (mac_en),
        .misr_en     (misr_en),
        .seed_load   (seed_load),
        .test_en_scan(test_en_scan),
        .clk_lfsr    (clk_lfsr),
        .clk_mac     (clk_mac),
        .clk_misr    (clk_misr)
    );

    //=========================================================================
    // LFSR TPG - uses clk_lfsr (gated clock)
    //=========================================================================
    lfsr_tpg #(
        .WIDTH (16),
        .POLY_A(POLY_A),
        .POLY_B(POLY_B),
        .SEED_A(SEED_A),
        .SEED_B(SEED_B)
    ) u_tpg (
        .clk      (clk_lfsr),   // GATED CLOCK
        .rst      (rst),
        .en       (lfsr_en),
        .seed_load(seed_load),
        .seed_a   (seed_a_in),
        .seed_b   (seed_b_in),
        .op_a     (op_a),
        .op_b     (op_b)
    );

    //=========================================================================
    // MAC DUT - uses clk_mac (gated clock)
    //=========================================================================
    mac_16bit #(
        .IN_WIDTH (16),
        .OUT_WIDTH(32),
        .ACC_WIDTH(40)
    ) u_mac (
        .clk    (clk_mac),      // GATED CLOCK
        .rst    (rst),
        .en     (mac_en),
        .op_a   (op_a),
        .op_b   (op_b),
        .mac_out(mac_out),
        .accum  (accum)
    );

    //=========================================================================
    // MISR ORA - uses clk_misr (gated clock)
    //=========================================================================
    misr_ora #(
        .WIDTH   (32),
        .TAP_MASK(32'h80200003)
    ) u_misr (
        .clk     (clk_misr),    // GATED CLOCK
        .rst     (rst),
        .en      (misr_en),
        .data_in (mac_out),
        .signature(misr_sig_int)
    );

    //=========================================================================
    // Signature capture register (uses ungated clk - 1-cycle operation)
    //=========================================================================
    always @(posedge clk) begin
        if (rst)
            captured_sig <= 32'd0;
        else if (capture)
            captured_sig <= misr_sig_int;
    end

    assign misr_sig = misr_sig_int;

    //=========================================================================
    // Golden Signature Register (uses ungated clk)
    //=========================================================================
    golden_signature_reg #(
        .WIDTH     (32),
        .GOLDEN_SIG(GOLDEN_SIG)
    ) u_golden (
        .clk       (clk),
        .rst       (rst),
        .load_en   (golden_load),
        .load_val  (golden_val),
        .golden_out(golden_sig_wire)
    );

    //=========================================================================
    // Signature Comparator (uses ungated clk)
    //=========================================================================
    signature_comparator #(
        .WIDTH(32)
    ) u_cmp (
        .clk       (clk),
        .rst       (rst),
        .compare_en(compare_en),
        .misr_sig  (captured_sig),
        .golden_sig(golden_sig_wire),
        .match     (sig_match),
        .comb_match(sig_comb_match),
        .mismatch  (sig_mismatch)
    );

endmodule
