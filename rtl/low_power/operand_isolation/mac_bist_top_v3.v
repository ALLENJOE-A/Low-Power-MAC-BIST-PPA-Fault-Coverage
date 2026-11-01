//=============================================================================
// Module  : mac_bist_top_v3  (Variant 3 - Operand Isolation)
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/variant3_operand_isolation/mac_bist_top_v3.v
//
// Purpose : Operand-isolated BIST top-level. Identical to Variant 1 except
//           that MAC operand inputs are gated to zero when the MAC is not
//           active (outside TEST_RUN state).
//
// Isolation insertion point:
//   LFSR outputs (op_a, op_b) -> [isolation cells] -> (iso_a, iso_b) -> MAC
//
// Isolation is OFF (transparent) during TEST_RUN.
// Isolation is ON (outputs = 0) during all other states.
//
// Language: Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module mac_bist_top_v3 #(
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

    //=========================================================================
    // Internal signals
    //=========================================================================
    wire        lfsr_en, mac_en, misr_en;
    wire        seed_load, capture, compare_en;
    wire        sig_match;
    wire        sig_comb_match;
    wire        sig_mismatch;
    wire [15:0] op_a, op_b;            // Raw LFSR outputs
    wire [15:0] iso_a, iso_b;          // Isolated operands -> MAC
    wire        iso_en;                // Isolation enable signal
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
    // LFSR TPG
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
    // Isolation Enable Controller
    //=========================================================================
    isolation_enable_ctrl u_iso_ctrl (
        .mac_en(mac_en),
        .iso_en(iso_en)
    );

    //=========================================================================
    // Operand Isolation Cells (one per operand bus)
    //=========================================================================
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
    // MAC DUT - receives isolated operands
    //=========================================================================
    mac_16bit #(
        .IN_WIDTH (16),
        .OUT_WIDTH(32),
        .ACC_WIDTH(40)
    ) u_mac (
        .clk    (clk),
        .rst    (rst),
        .en     (mac_en),
        .op_a   (iso_a),
        .op_b   (iso_b),
        .mac_out(mac_out),
        .accum  (accum)
    );

    //=========================================================================
    // MISR ORA
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
    // Signature capture register
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
