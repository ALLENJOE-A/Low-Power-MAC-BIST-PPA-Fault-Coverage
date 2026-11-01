//=============================================================================
// Module  : lfsr_tpg
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/common/lfsr_tpg.v
//
// Purpose : Test Pattern Generator using two independent 16-bit Fibonacci
//           LFSRs. LFSR_A drives MAC operand_a; LFSR_B drives operand_b.
//           Independent polynomials ensure statistically uncorrelated patterns.
//
// LFSR Type     : Fibonacci (external XOR feedback)
// Shift Dir     : Left (new bit enters at bit[0], MSB shifts out)
// Reset         : Synchronous, active-high; loads default seed on reset
//
// Polynomial A  : x^16 + x^15 + x^13 + x^4 + 1  (known primitive)
//   Tap mask    : 16'hD008
//   Period      : 2^16 - 1 = 65535
//
// Polynomial B  : x^16 + x^14 + x^13 + x^11 + 1 (known primitive)
//   Tap mask    : 16'hB400
//   Period      : 2^16 - 1 = 65535
//
// Feedback eqn  : fb = XOR-reduction of (reg & POLY_MASK)
// Next state    : {reg[WIDTH-2:0], fb}
//
// Language      : Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module lfsr_tpg #(
    parameter WIDTH  = 16,
    parameter [15:0] POLY_A = 16'hD008,  // Polynomial A tap mask
    parameter [15:0] POLY_B = 16'hB400,  // Polynomial B tap mask
    parameter [15:0] SEED_A = 16'hACE1,  // Default seed for LFSR_A
    parameter [15:0] SEED_B = 16'h1234   // Default seed for LFSR_B
) (
    input  wire             clk,        // System clock
    input  wire             rst,        // Synchronous active-high reset
    input  wire             en,         // Shift enable (from BIST controller)
    input  wire             seed_load,  // Load seed (SEED_LOAD state)
    input  wire [WIDTH-1:0] seed_a,     // Programmable seed for LFSR_A
    input  wire [WIDTH-1:0] seed_b,     // Programmable seed for LFSR_B
    output wire [WIDTH-1:0] op_a,       // Test operand A -> MAC input
    output wire [WIDTH-1:0] op_b        // Test operand B -> MAC input
);

    // Internal LFSR state registers
    reg [WIDTH-1:0] reg_a;
    reg [WIDTH-1:0] reg_b;

    // Feedback bits (combinational)
    wire fb_a;
    wire fb_b;

    //-------------------------------------------------------------------------
    // Combinational feedback: XOR of bits at tap positions
    // feedback = ^(register & tap_mask)
    //-------------------------------------------------------------------------
    assign fb_a = ^(reg_a & POLY_A[WIDTH-1:0]);
    assign fb_b = ^(reg_b & POLY_B[WIDTH-1:0]);

    //-------------------------------------------------------------------------
    // LFSR_A sequential register
    // Priority: rst > seed_load > en
    //-------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            reg_a <= SEED_A[WIDTH-1:0];
        else if (seed_load)
            reg_a <= seed_a;
        else if (en)
            reg_a <= {reg_a[WIDTH-2:0], fb_a};
    end

    //-------------------------------------------------------------------------
    // LFSR_B sequential register
    // Priority: rst > seed_load > en
    //-------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            reg_b <= SEED_B[WIDTH-1:0];
        else if (seed_load)
            reg_b <= seed_b;
        else if (en)
            reg_b <= {reg_b[WIDTH-2:0], fb_b};
    end

    // Output assignments
    assign op_a = reg_a;
    assign op_b = reg_b;

    //-------------------------------------------------------------------------
    // Simulation checks (can be disabled for synthesis)
    //-------------------------------------------------------------------------
    // synthesis translate_off
    always @(posedge clk) begin
        if (!rst && en) begin
            if (reg_a == {WIDTH{1'b0}})
                $display("[lfsr_tpg] WARNING: LFSR_A entered all-zero lock-up state at t=%0t", $time);
            if (reg_b == {WIDTH{1'b0}})
                $display("[lfsr_tpg] WARNING: LFSR_B entered all-zero lock-up state at t=%0t", $time);
        end
    end
    // synthesis translate_on

endmodule
