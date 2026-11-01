//=============================================================================
// Module  : isolation_enable_ctrl
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/variant3_operand_isolation/isolation_enable_ctrl.v
//
// Purpose : Generates iso_en signal for operand isolation cells.
//           iso_en is ASSERTED when the MAC is NOT active (i.e. mac_en = 0).
//
// Logic:  iso_en = ~mac_en
//
// Language: Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module isolation_enable_ctrl (
    input  wire mac_en,   // From bist_controller: 1 = MAC active
    output wire iso_en    // To operand_isolation_cell: 1 = isolate
);

    assign iso_en = ~mac_en;

endmodule
