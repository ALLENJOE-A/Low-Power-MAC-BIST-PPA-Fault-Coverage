//=============================================================================
// Testbench : tb_mac_bist_v5
// Project   : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File      : tb/tb_mac_bist_v5.v
//
// Purpose   : Dedicated testbench for Variant 5 (Combined Low-Power).
//             Verifies:
//               1. Reset behavior
//               2. Combined low-power techniques (clock gating + isolation + bus inversion)
//               3. Golden signature equivalence (0x036ce3d3)
//               4. Fault-free BIST PASS
//               5. RTL fault injection detection
//               6. Regression check
//
// Language  : Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module tb_mac_bist_v5;

    parameter CLK_PERIOD  = 10;    // 10 ns = 100 MHz
    parameter TEST_CYCLES = 256;
    parameter [15:0] SEED_A = 16'hACE1;
    parameter [15:0] SEED_B = 16'h1234;
    parameter TIMEOUT_CYC = 10000;

    reg         clk;
    reg         rst;
    reg         bist_start;
    reg         test_en_scan;
    reg  [15:0] seed_a_in;
    reg  [15:0] seed_b_in;
    reg         golden_load;
    reg  [31:0] golden_val;
    wire        bist_done;
    wire        bist_pass;
    wire        bist_fail;
    wire [31:0] misr_sig;
    wire [2:0]  state_dbg;

    integer tests_passed;
    integer tests_failed;
    reg [31:0] captured_golden;
    reg [31:0] sig_temp;

    // DUT Instantiation - Variant 5 Combined
    mac_bist_top_v5 #(
        .GOLDEN_SIG (32'h036ce3d3),
        .TEST_CYCLES(TEST_CYCLES),
        .SEED_A     (SEED_A),
        .SEED_B     (SEED_B),
        .POLY_A     (16'hD008),
        .POLY_B     (16'hB400)
    ) u_dut (
        .clk         (clk),
        .rst         (rst),
        .bist_start  (bist_start),
        .test_en_scan(test_en_scan),
        .seed_a_in   (seed_a_in),
        .seed_b_in   (seed_b_in),
        .golden_load (golden_load),
        .golden_val  (golden_val),
        .bist_done   (bist_done),
        .bist_pass   (bist_pass),
        .bist_fail   (bist_fail),
        .misr_sig    (misr_sig),
        .state_dbg   (state_dbg)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        repeat (TIMEOUT_CYC) @(posedge clk);
        $display("[TB_V5] WATCHDOG TIMEOUT!");
        $finish;
    end

    task apply_reset;
        input integer n_cycles;
        integer i;
        begin
            rst          = 1'b1;
            bist_start   = 1'b0;
            test_en_scan = 1'b1;
            golden_load  = 1'b0;
            seed_a_in    = SEED_A;
            seed_b_in    = SEED_B;
            golden_val   = 32'd0;
            for (i = 0; i < n_cycles; i = i + 1) begin
                @(posedge clk);
            end
            rst = 1'b0;
            test_en_scan = 1'b0;
            @(posedge clk);
        end
    endtask

    task run_bist_and_wait;
        output [31:0] sig_out;
        begin
            @(posedge clk);
            bist_start = 1'b1;
            @(posedge clk);
            bist_start = 1'b0;

            while (bist_done !== 1'b1) begin
                @(posedge clk);
            end

            @(posedge clk);
            sig_out = misr_sig;
        end
    endtask

    initial begin
        tests_passed = 0;
        tests_failed = 0;

        $display("=============================================================");
        $display("[TB_V5] Starting Variant 5 (Combined Low-Power) Verification");
        $display("=============================================================");

        // Test 1: Reset
        $display("\n--- TEST 1: Reset Behavior ---");
        apply_reset(10);
        if (bist_done === 1'b0 && bist_pass === 1'b0 && bist_fail === 1'b0 && state_dbg === 3'd0) begin
            $display("[TB_V5] PASS: Reset behavior verified.");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[TB_V5] FAIL: Reset output mismatch.");
            tests_failed = tests_failed + 1;
        end

        // Test 2: Combined Low-Power Verification in IDLE
        $display("\n--- TEST 2: Combined Low-Power Checks in IDLE ---");
        #1;
        if (u_dut.clk_mac === 1'b0 && u_dut.iso_en === 1'b1 && u_dut.iso_a === 16'd0 && u_dut.iso_b === 16'd0) begin
            $display("[TB_V5] PASS: Clock gating and operand isolation active in IDLE.");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[TB_V5] FAIL: Low power checks failed in IDLE (clk_mac=%0b, iso_en=%0b, iso_a=0x%04h).",
                     u_dut.clk_mac, u_dut.iso_en, u_dut.iso_a);
            tests_failed = tests_failed + 1;
        end

        // Test 3: Golden Signature and BIST PASS
        $display("\n--- TEST 3: Golden Signature & Fault-Free BIST ---");
        run_bist_and_wait(sig_temp);
        captured_golden = u_dut.captured_sig;
        $display("[TB_V5] Captured MISR Signature = 0x%08h", captured_golden);

        if (captured_golden === 32'h036ce3d3) begin
            $display("[TB_V5] PASS: Golden signature matches 0x036ce3d3!");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[TB_V5] FAIL: Signature mismatch (got 0x%08h, expected 0x036ce3d3)", captured_golden);
            tests_failed = tests_failed + 1;
        end

        if (bist_pass === 1'b1 && bist_fail === 1'b0) begin
            $display("[TB_V5] PASS: BIST PASS asserted.");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[TB_V5] FAIL: BIST did not pass.");
            tests_failed = tests_failed + 1;
        end
        apply_reset(5);

        // Test 4: Fault Injection
        $display("\n--- TEST 4: Fault Injection (mac_out[4] SA0) ---");
        @(posedge clk);
        bist_start = 1'b1;
        @(posedge clk);
        bist_start = 1'b0;

        wait (state_dbg === 3'd2);
        force u_dut.u_mac.mac_out[4] = 1'b0;

        wait (bist_done === 1'b1);
        sig_temp = u_dut.captured_sig;
        release u_dut.u_mac.mac_out[4];

        if (sig_temp !== 32'h036ce3d3 && bist_fail === 1'b1 && bist_pass === 1'b0) begin
            $display("[TB_V5] PASS: Fault detected! (sig=0x%08h, bist_fail=1)", sig_temp);
            tests_passed = tests_passed + 1;
        end else begin
            $display("[TB_V5] FAIL: Fault not detected (sig=0x%08h, fail=%0b)", sig_temp, bist_fail);
            tests_failed = tests_failed + 1;
        end
        apply_reset(5);

        // Test 5: Post-Fault Regression
        $display("\n--- TEST 5: Post-Fault Regression ---");
        run_bist_and_wait(sig_temp);
        if (bist_pass === 1'b1 && bist_fail === 1'b0) begin
            $display("[TB_V5] PASS: Post-fault regression passed cleanly.");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[TB_V5] FAIL: Post-fault regression failed.");
            tests_failed = tests_failed + 1;
        end

        // Summary
        $display("\n=============================================================");
        $display("[TB_V5] SUMMARY: %0d PASSED, %0d FAILED", tests_passed, tests_failed);
        $display("=============================================================");
        if (tests_failed == 0)
            $display("[TB_V5] ALL TESTS PASSED!");
        else
            $display("[TB_V5] SOME TESTS FAILED!");

        $finish;
    end

endmodule
