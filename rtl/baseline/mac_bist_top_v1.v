//=============================================================================
// Module  : mac_bist_top_v1  (Variant 1 - Baseline)
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/variant1_baseline/mac_bist_top_v1.v
//
// Purpose : Top-level synthesizable wrapper for the baseline BIST architecture.
//           Instantiates and connects all common modules without any low-power
//           optimizations. This is the reference for PPA comparison.
//
// Architecture:
//   bist_controller -> lfsr_tpg -> mac_16bit -> misr_ora
//                  |                              |
//              golden_sig_reg <---> signature_comparator
//
// Language: Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module mac_bist_top_v1 #(
    parameter [31:0] GOLDEN_SIG  = 32'h036ce3d3, // Fault-free golden signature
    parameter        TEST_CYCLES = 256,
    parameter [15:0] SEED_A      = 16'hACE1,
    parameter [15:0] SEED_B      = 16'h1234,
    parameter [15:0] POLY_A      = 16'hD008,
    parameter [15:0] POLY_B      = 16'hB400
) (
    input  wire        clk,
    input  wire        rst,

    // BIST control
    input  wire        bist_start,

    // Seed / golden override (for testbench; tie off in gate-level)
    input  wire [15:0] seed_a_in,
    input  wire [15:0] seed_b_in,
    input  wire        golden_load,
    input  wire [31:0] golden_val,

    // Status outputs
    output wire        bist_done,
    output wire        bist_pass,
    output wire        bist_fail,

    // Observation outputs (for waveform / testbench)
    output wire [31:0] misr_sig,
    output wire [2:0]  state_dbg
);

    //=========================================================================
    // Internal signal declarations
    //=========================================================================
    wire        lfsr_en;
    wire        mac_en;
    wire        misr_en;
    wire        seed_load;
    wire        capture;
    wire        compare_en;

    wire        sig_match;
    wire        sig_comb_match;
    wire        sig_mismatch;

    wire [15:0] op_a;
    wire [15:0] op_b;
    wire [31:0] mac_out;
    wire [39:0] accum;
    wire [31:0] misr_sig_int;
    reg  [31:0] captured_sig;
    wire [31:0] golden_sig_wire;

    //=========================================================================
    // BIST Controller
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
    // Test Pattern Generator (TPG) - Two independent LFSRs
    //=========================================================================
    lfsr_tpg #(
        .WIDTH (16),
        .POLY_A(POLY_A),
        .POLY_B(POLY_B),
        .SEED_A(SEED_A),
        .SEED_B(SEED_B)
    ) u_tpg (
        .clk      (clk),
        .rst      (rst),
        .en       (lfsr_en),
        .seed_load(seed_load),
        .seed_a   (seed_a_in),
        .seed_b   (seed_b_in),
        .op_a     (op_a),
        .op_b     (op_b)
    );

    //=========================================================================
    // MAC - Design Under Test
    //=========================================================================
    mac_16bit #(
        .IN_WIDTH (16),
        .OUT_WIDTH(32),
        .ACC_WIDTH(40)
    ) u_mac (
        .clk    (clk),
        .rst    (rst),
        .en     (mac_en),
        .op_a   (op_a),
        .op_b   (op_b),
        .mac_out(mac_out),
        .accum  (accum)
    );

    //=========================================================================
    // MISR - Output Response Analyzer
    //=========================================================================
    misr_ora #(
        .WIDTH   (32),
        .TAP_MASK(32'h80200003)
    ) u_misr (
        .clk     (clk),
        .rst     (rst),
        .en      (misr_en),
        .data_in (mac_out),
        .signature(misr_sig_int)
    );

    //=========================================================================
    // Signature capture register (SIGNATURE_CAPTURE state)
    //=========================================================================
    always @(posedge clk) begin
        if (rst)
            captured_sig <= 32'd0;
        else if (capture)
            captured_sig <= misr_sig_int;
    end

    assign misr_sig = misr_sig_int;

    //=========================================================================
    // Golden Signature Register
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
    // Signature Comparator
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

// Optional alias wrapper for backward compatibility with mac_bist_top
module mac_bist_top #(
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

    mac_bist_top_v1 #(
        .GOLDEN_SIG (GOLDEN_SIG),
        .TEST_CYCLES(TEST_CYCLES),
        .SEED_A     (SEED_A),
        .SEED_B     (SEED_B),
        .POLY_A     (POLY_A),
        .POLY_B     (POLY_B)
    ) u_v1 (
        .clk        (clk),
        .rst        (rst),
        .bist_start (bist_start),
        .seed_a_in  (seed_a_in),
        .seed_b_in  (seed_b_in),
        .golden_load(golden_load),
        .golden_val (golden_val),
        .bist_done  (bist_done),
        .bist_pass  (bist_pass),
        .bist_fail  (bist_fail),
        .misr_sig   (misr_sig),
        .state_dbg  (state_dbg)
    );

endmodule
