//=============================================================================
// Module  : bist_controller
// Project : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File    : rtl/common/bist_controller.v
//
// Purpose : FSM controller for the BIST engine. Sequences all BIST operations
//           from idle through test execution to pass/fail reporting.
//
// FSM States (One-Hot encoded):
//   IDLE              -> Waiting for bist_start pulse
//   SEED_LOAD         -> Load seeds into LFSRs (1 cycle)
//   TEST_RUN          -> Run LFSR -> MAC -> MISR for TEST_CYCLES clocks
//   SIGNATURE_CAPTURE -> Latch final MISR value (1 cycle)
//   COMPARE           -> Compare MISR vs golden (1 cycle)
//   PASS              -> BIST passed; hold until reset
//   FAIL              -> BIST failed; hold until reset
//
// State Transitions:
//   IDLE      -> SEED_LOAD  : bist_start = 1
//   SEED_LOAD -> TEST_RUN   : always (next cycle)
//   TEST_RUN  -> SIG_CAPTURE: cycle_cnt == TEST_CYCLES-1
//   SIG_CAP   -> COMPARE    : always (next cycle)
//   COMPARE   -> PASS       : signature_match = 1
//   COMPARE   -> FAIL       : signature_match = 0
//   PASS/FAIL -> IDLE       : rst = 1 (reset clears FSM)
//
// Enable Signal Schedule:
//   State             | lfsr_en mac_en misr_en seed_load capture compare_en
//   IDLE              |   0       0      0        0        0       0
//   SEED_LOAD         |   0       0      0        1        0       0
//   TEST_RUN          |   1       1      1        0        0       0
//   SIGNATURE_CAPTURE |   0       0      0        0        1       0
//   COMPARE           |   0       0      0        0        0       1
//   PASS/FAIL         |   0       0      0        0        0       0
//
// Parameters:
//   TEST_CYCLES : Number of test vectors applied (default 256)
//   CNT_WIDTH   : Width of cycle counter (default 9)
//
// Language: Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module bist_controller #(
    parameter TEST_CYCLES = 256,
    parameter CNT_WIDTH   = 9    // Enough for 256 cycles
) (
    input  wire clk,
    input  wire rst,             // Synchronous active-high reset

    // Control inputs
    input  wire bist_start,      // Pulse to begin BIST
    input  wire signature_match, // From signature_comparator (comb_match)

    // Enable outputs (to LFSR, MAC, MISR)
    output reg  lfsr_en,
    output reg  mac_en,
    output reg  misr_en,
    output reg  seed_load,       // LFSR seed load enable
    output reg  capture,         // MISR signature capture
    output reg  compare_en,      // Comparator enable

    // Status outputs
    output reg  bist_done,
    output reg  bist_pass,
    output reg  bist_fail,

    // Debug / TB visibility
    output reg  [2:0] state_dbg  // Encoded state for waveform inspection
);

    // One-hot state encoding
    localparam [6:0] IDLE              = 7'b000_0001;
    localparam [6:0] SEED_LOAD         = 7'b000_0010;
    localparam [6:0] TEST_RUN          = 7'b000_0100;
    localparam [6:0] SIGNATURE_CAPTURE = 7'b000_1000;
    localparam [6:0] COMPARE           = 7'b001_0000;
    localparam [6:0] PASS              = 7'b010_0000;
    localparam [6:0] FAIL              = 7'b100_0000;

    reg [6:0] current_state;
    reg [6:0] next_state;

    // Cycle counter for TEST_RUN phase
    reg  [CNT_WIDTH-1:0] cycle_cnt;
    wire                 cnt_done;

    // Cycle counter
    always @(posedge clk) begin
        if (rst)
            cycle_cnt <= {CNT_WIDTH{1'b0}};
        else if (current_state == TEST_RUN)
            cycle_cnt <= cycle_cnt + 1'b1;
        else
            cycle_cnt <= {CNT_WIDTH{1'b0}};
    end

    assign cnt_done = (cycle_cnt == (TEST_CYCLES - 1));

    // State register (synchronous reset)
    always @(posedge clk) begin
        if (rst)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next-state logic (combinational)
    always @(*) begin
        next_state = current_state; // Default: hold

        case (current_state)
            IDLE: begin
                if (bist_start)
                    next_state = SEED_LOAD;
            end

            SEED_LOAD: begin
                next_state = TEST_RUN;
            end

            TEST_RUN: begin
                if (cnt_done)
                    next_state = SIGNATURE_CAPTURE;
            end

            SIGNATURE_CAPTURE: begin
                next_state = COMPARE;
            end

            COMPARE: begin
                next_state = signature_match ? PASS : FAIL;
            end

            PASS: begin
                next_state = PASS; // Hold until reset
            end

            FAIL: begin
                next_state = FAIL; // Hold until reset
            end

            default: next_state = IDLE;
        endcase
    end

    // Output decode (combinational)
    always @(*) begin
        // Defaults: all deasserted
        lfsr_en    = 1'b0;
        mac_en     = 1'b0;
        misr_en    = 1'b0;
        seed_load  = 1'b0;
        capture    = 1'b0;
        compare_en = 1'b0;
        bist_done  = 1'b0;
        bist_pass  = 1'b0;
        bist_fail  = 1'b0;

        case (current_state)
            IDLE: begin
            end

            SEED_LOAD: begin
                seed_load = 1'b1;
            end

            TEST_RUN: begin
                lfsr_en = 1'b1;
                mac_en  = 1'b1;
                misr_en = 1'b1;
            end

            SIGNATURE_CAPTURE: begin
                capture = 1'b1;
            end

            COMPARE: begin
                compare_en = 1'b1;
            end

            PASS: begin
                bist_done = 1'b1;
                bist_pass = 1'b1;
            end

            FAIL: begin
                bist_done = 1'b1;
                bist_fail = 1'b1;
            end

            default: begin
            end
        endcase
    end

    // Debug: binary-encoded state for waveform views
    always @(*) begin
        case (current_state)
            IDLE              : state_dbg = 3'd0;
            SEED_LOAD         : state_dbg = 3'd1;
            TEST_RUN          : state_dbg = 3'd2;
            SIGNATURE_CAPTURE : state_dbg = 3'd3;
            COMPARE           : state_dbg = 3'd4;
            PASS              : state_dbg = 3'd5;
            FAIL              : state_dbg = 3'd6;
            default           : state_dbg = 3'd7;
        endcase
    end

endmodule
