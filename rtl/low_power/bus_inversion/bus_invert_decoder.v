//=============================================================================
// Module  : bus_invert_decoder
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/variant4_bus_inversion/bus_invert_decoder.v
//
// Purpose : Decodes the bus-inverted data back to the original value.
//           Must be placed at the MAC side of the bus (receiver).
//
// Operation:
//   If inv_flag = 1: original data = ~bus_in  (re-invert to recover)
//   If inv_flag = 0: original data = bus_in   (pass through unchanged)
//
// Correctness guarantee:
//   The decoder output is ALWAYS identical to the original data_in at the
//   encoder.
//
// Language: Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module bus_invert_decoder #(
    parameter WIDTH = 16
) (
    input  wire [WIDTH-1:0] bus_in,   // Received bus data (possibly inverted)
    input  wire             inv_flag, // 1 = bus_in is inverted; 0 = not inverted
    output wire [WIDTH-1:0] data_out  // Reconstructed original data -> MAC
);

    assign data_out = inv_flag ? ~bus_in : bus_in;

endmodule
