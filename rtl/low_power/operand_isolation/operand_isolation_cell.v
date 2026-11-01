//=============================================================================
// Module  : operand_isolation_cell
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/variant3_operand_isolation/operand_isolation_cell.v
//
// Purpose : Isolates (freezes) MAC operand buses when the MAC is not actively
//           performing test computations. Prevents unwanted switching activity
//           on MAC inputs during non-TEST_RUN states.
//
// Isolation Strategy:
//   When iso_en = 1 (MAC NOT active): output driven to 0 (lowest toggle energy)
//   When iso_en = 0 (MAC IS active) : data passes through unchanged
//
// Language: Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module operand_isolation_cell #(
    parameter WIDTH = 16
) (
    input  wire [WIDTH-1:0] data_in,  // From LFSR
    input  wire             iso_en,   // 1 = isolate (MAC not active); 0 = pass
    output wire [WIDTH-1:0] data_out  // To MAC operand input
);

    // AND-based isolation
    assign data_out = data_in & {WIDTH{~iso_en}};

endmodule
