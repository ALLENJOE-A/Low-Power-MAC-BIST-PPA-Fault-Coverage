//=============================================================================
// Module  : mac_bist_top_v6  (Variant 6 - Combined Operand Isolation + Clock Gating)
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/low_power/combined_oi_cg/mac_bist_top_v6.v
//
// Purpose : Top-level synthesizable wrapper integrating Operand Isolation and
//           Clock Gating together (without bus inversion).
//
//           As reported in the research paper (Table IV), this combination achieves
//           the highest total power reduction among all evaluated variants:
//           - Total Power : 794.993 uW (-10.1% vs baseline)
//           - Cell Count  : 1127 cells (-4.9% vs baseline)
//           - Area        : 9660.32 um^2 (-2.7% vs baseline)
//
// Mechanism:
//   1. Clock Gating (ICG cells) gates LFSR, MAC, and MISR clocks during IDLE/non-test states.
//   2. Operand Isolation (AND-mask cells) forces MAC inputs to zero outside TEST_RUN,
//      preventing unnecessary combinational switching in the 16x16 multiplier array.
//
// Language: Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module mac_bist_top_v6 #(
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
    wire        iso_en;

    // Gated clocks
    wire        clk_lfsr, clk_mac, clk_misr;

    // Datapath
    wire [15:0] op_a, op_b;      // Raw LFSR outputs
    wire [15:0] iso_a, iso_b;    // Isolated operands -> MAC
    wire [31:0] mac_out;
    wire [39:0] accum;
    wire [31:0] misr_sig_int;
    reg  [31:0] captured_sig;
    wire [31:0] golden_sig_wire;

    //=========================================================================
    // BIST Controller (uses free-running system clock)
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
    // Low-Power Technique 1: Clock Gate Controller
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
    // LFSR TPG (driven by gated clock clk_lfsr)
    //=========================================================================
    lfsr_tpg #(
        .WIDTH (16),
        .POLY_A(POLY_A),
        .POLY_B(POLY_B),
        .SEED_A(SEED_A),
        .SEED_B(SEED_B)
    ) u_tpg (
        .clk      (clk_lfsr),
        .rst      (rst),
        .en       (lfsr_en),
        .seed_load(seed_load),
        .seed_a   (seed_a_in),
        .seed_b   (seed_b_in),
        .op_a     (op_a),
        .op_b     (op_b)
    );

    //=========================================================================
    // Low-Power Technique 2: Operand Isolation
    //=========================================================================
    isolation_enable_ctrl u_iso_ctrl (
        .mac_en(mac_en),
        .iso_en(iso_en)
    );

    operand_isolation_cell #(.WIDTH(16)) u_iso_a (
        .data_in (op_a),
        .iso_en  (iso_en),
        .data_out(iso_a)
    );

    operand_isolation_cell #(.WIDTH(16)) u_iso_b (
        .data_in (op_b),
        .iso_en  (iso_en),
        .data_out(iso_b)
    );

    //=========================================================================
    // MAC Core - CUT (driven by gated clock clk_mac, receives isolated operands)
    //=========================================================================
    mac_16bit #(
        .IN_WIDTH (16),
        .OUT_WIDTH(32),
        .ACC_WIDTH(40)
    ) u_mac (
        .clk    (clk_mac),
        .rst    (rst),
        .en     (mac_en),
        .op_a   (iso_a),
        .op_b   (iso_b),
        .mac_out(mac_out),
        .accum  (accum)
    );

    //=========================================================================
    // MISR ORA (driven by gated clock clk_misr)
    //=========================================================================
    misr_ora #(
        .WIDTH   (32),
        .TAP_MASK(32'h80200003)
    ) u_misr (
        .clk      (clk_misr),
        .rst      (rst),
        .en       (misr_en),
        .data_in  (mac_out),
        .signature(misr_sig_int)
    );

    //=========================================================================
    // Signature capture register (free-running clk)
    //=========================================================================
    always @(posedge clk) begin
        if (rst)
            captured_sig <= 32'd0;
        else if (capture)
            captured_sig <= misr_sig_int;
    end

    assign misr_sig = misr_sig_int;

    //=========================================================================
    // Golden Signature Register (free-running clk)
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
    // Signature Comparator (free-running clk)
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
