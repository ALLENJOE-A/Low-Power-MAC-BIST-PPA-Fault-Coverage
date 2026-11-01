//=============================================================================
// Module  : misr_ora
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/common/misr_ora.v
//
// Purpose : Multiple-Input Signature Register / Output Response Analyzer.
//           Compacts 32-bit MAC output responses into a final 32-bit signature
//           for comparison against the golden signature.
//
// MISR Type     : Fibonacci (Type-1), parallel data XOR
// Width         : 32 bits (configurable via parameter)
//
// Polynomial    : x^32 + x^22 + x^2 + x + 1
//   Primitive polynomial over GF(2).
//   Fibonacci tap positions (0-indexed from LSB):
//     Taps at bits [31, 21, 1, 0]
//     TAP_MASK = 32'h80200003
//
// MISR operation each clock:
//   feedback = ^(misr_reg & TAP_MASK)    // XOR of tapped bits
//   misr_reg = {misr_reg[30:0], feedback} ^ data_in  // shift + inject data
//
// Aliasing probability: 2^(-WIDTH) = 2^-32 ~= 2.33 x 10^-10
//
// Reset   : Synchronous active-high, clears MISR to all-zeros.
// Enable  : en=1 from BIST controller during TEST_RUN only.
//
// Language: Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module misr_ora #(
    parameter WIDTH    = 32,
    parameter [31:0] TAP_MASK = 32'h80200003
) (
    input  wire             clk,       // System clock
    input  wire             rst,       // Synchronous active-high reset
    input  wire             en,        // Shift enable (TEST_RUN state only)
    input  wire [WIDTH-1:0] data_in,   // MAC product output -> compacted here
    output wire [WIDTH-1:0] signature  // Current MISR signature
);

    reg  [WIDTH-1:0] misr_reg;
    wire             feedback;

    // Combinational feedback: XOR of all bits selected by TAP_MASK
    assign feedback = ^(misr_reg & TAP_MASK[WIDTH-1:0]);

    // MISR register: Fibonacci shift with parallel data injection
    always @(posedge clk) begin
        if (rst)
            misr_reg <= {WIDTH{1'b0}};
        else if (en)
            misr_reg <= {misr_reg[WIDTH-2:0], feedback} ^ data_in;
    end

    assign signature = misr_reg;

    // synthesis translate_off
    initial begin
        $display("[misr_ora] INFO: MISR width = %0d bits", WIDTH);
        $display("[misr_ora] INFO: TAP_MASK = 0x%08h", TAP_MASK);
    end
    // synthesis translate_on

endmodule
