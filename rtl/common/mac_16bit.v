//=============================================================================
// Module  : mac_16bit
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/common/mac_16bit.v
//
// Purpose : 16-bit Multiply-Accumulate unit - the Design Under Test (DUT).
//
//   product = op_a * op_b           (unsigned 16x16 = 32-bit result)
//   accum  += product               (40-bit accumulator, synchronous)
//   mac_out = product               (per-cycle product fed to MISR)
//
// Rationale for output choice:
//   The per-cycle PRODUCT is exposed to the MISR (not the accumulator).
//   Feeding the accumulator would mask single-cycle faults because errors
//   from cycle N get summed with correct values from cycles N+1..256,
//   potentially producing correct-looking partial sums.
//   The product provides maximum per-cycle fault observability.
//
// Accumulator width:
//   40 bits = 32-bit product + 8 guard bits.
//   Max product = 0xFFFF * 0xFFFF = 0xFFFE_0001 ~= 2^32.
//   After 256 accumulations: max accum ~= 256 * 2^32 = 2^40.
//   Guard bits prevent overflow for up to 256 test cycles.
//
// Reset   : Synchronous active-high, clears accumulator only.
// Enable  : en=1 -> latch new accumulation; en=0 -> hold accum.
//
// Language: Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module mac_16bit #(
    parameter IN_WIDTH  = 16,   // Operand width
    parameter OUT_WIDTH = 32,   // Product/output width (IN_WIDTH*2)
    parameter ACC_WIDTH = 40    // Accumulator (OUT_WIDTH + 8 guard)
) (
    input  wire                  clk,      // System clock
    input  wire                  rst,      // Synchronous active-high reset
    input  wire                  en,       // MAC enable (from BIST controller)
    input  wire [IN_WIDTH-1:0]   op_a,     // Operand A (16-bit unsigned)
    input  wire [IN_WIDTH-1:0]   op_b,     // Operand B (16-bit unsigned)
    output wire [OUT_WIDTH-1:0]  mac_out,  // Per-cycle product -> MISR ORA
    output reg  [ACC_WIDTH-1:0]  accum     // Running accumulator (optional use)
);

    // Internal product wire (unsigned multiplication)
    wire [OUT_WIDTH-1:0] product;

    // Combinational unsigned multiplier: 16 x 16 -> 32 bits
    assign product = op_a * op_b;

    // Synchronous accumulator
    always @(posedge clk) begin
        if (rst)
            accum <= {ACC_WIDTH{1'b0}};
        else if (en)
            accum <= accum + {{(ACC_WIDTH-OUT_WIDTH){1'b0}}, product};
    end

    // Per-cycle product drives MISR for maximum fault observability
    assign mac_out = product;

endmodule
