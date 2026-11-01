//=============================================================================
// Module  : bus_invert_encoder
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/variant4_bus_inversion/bus_invert_encoder.v
//
// Purpose : Bi-directional bus inversion encoder. Reduces switching activity
//           on the operand bus between LFSR and MAC by inverting the data
//           when doing so requires fewer bit transitions.
//
// Algorithm:
//   1. Compare current data_in with prev_data (last transmitted value).
//   2. Compute Hamming distance = popcount(data_in XOR prev_data).
//   3. If Hamming_distance > WIDTH/2:
//        Transmit ~data_in, set inv_flag = 1
//      Else:
//        Transmit data_in, set inv_flag = 0
//   4. Update prev_data register to the ACTUAL transmitted value.
//
// Language: Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module bus_invert_encoder #(
    parameter WIDTH = 16
) (
    input  wire             clk,
    input  wire             rst,        // Synchronous active-high reset
    input  wire             en,         // Enable (from lfsr_en)
    input  wire [WIDTH-1:0] data_in,    // Current data from LFSR
    output wire [WIDTH-1:0] bus_out,    // Data on bus (possibly inverted)
    output wire             inv_flag    // 1 = bus_out is inverted
);

    // Previous transmitted bus value
    reg [WIDTH-1:0] prev_data;

    // Transition count
    reg [4:0] trans_count;
    reg       do_invert;
    wire [WIDTH-1:0] xor_bits;
    integer i;

    assign xor_bits = data_in ^ prev_data;

    // Combinational: compute Hamming distance between data_in and prev_data
    always @(*) begin
        trans_count = 5'd0;
        for (i = 0; i < WIDTH; i = i + 1) begin
            trans_count = trans_count + xor_bits[i];
        end
        do_invert = (trans_count > (WIDTH / 2));
    end

    // Registered prev_data: tracks last TRANSMITTED value
    always @(posedge clk) begin
        if (rst)
            prev_data <= {WIDTH{1'b0}};
        else if (en)
            prev_data <= do_invert ? ~data_in : data_in;
    end

    // Output assignments
    assign bus_out  = do_invert ? ~data_in : data_in;
    assign inv_flag = do_invert;

endmodule
