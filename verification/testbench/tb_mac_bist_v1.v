//=============================================================================
// Testbench : tb_mac_bist_v1
// Project   : Low-Power Aware BIST Architecture for 16-bit MAC (Verilog-2001)
// File      : tb/tb_mac_bist_v1.v
//
// Purpose   : Complete testbench for Variant 1 (Baseline BIST).
//             Verifies:
//               1. Reset behavior
//               2. MAC known-answer test (KAT)
//               3. LFSR sequence and non-repeating property
//               4. MISR operation and signature accumulation
//               5. BIST controller FSM transitions
//               6. Golden signature generation (0x036ce3d3)
//               7. Fault-free BIST PASS
//               8. RTL fault injection (SA0 on mac_out[0])
//               9. Post-fault regression
//
// Language  : Standard Verilog (IEEE 1364-2001)
//=============================================================================

`timescale 1ns/1ps

module tb_mac_bist_v1;

    // Parameters
    parameter CLK_PERIOD  = 10;    // 10 ns = 100 MHz
    parameter TEST_CYCLES = 256;
    parameter [15:0] SEED_A = 16'hACE1;
    parameter [15:0] SEED_B = 16'h1234;
    parameter TIMEOUT_CYC = 10000; // Watchdog timeout

    // DUT signals
    reg         clk;
    reg         rst;
    reg         bist_start;
    reg  [15:0] seed_a_in;
    reg  [15:0] seed_b_in;
    reg         golden_load;
    reg  [31:0] golden_val;
    wire        bist_done;
    wire        bist_pass;
    wire        bist_fail;
    wire [31:0] misr_sig;
    wire [2:0]  state_dbg;

    // Test counters
    integer tests_passed;
    integer tests_failed;
    reg [31:0] captured_golden;

    // DUT Instantiation - Variant 1 Baseline
    mac_bist_top_v1 #(
        .GOLDEN_SIG (32'h036ce3d3),
        .TEST_CYCLES(TEST_CYCLES),
        .SEED_A     (SEED_A),
        .SEED_B     (SEED_B),
        .POLY_A     (16'hD008),
        .POLY_B     (16'hB400)
    ) u_dut (
        .clk        (clk),
        .rst        (rst),
        .bist_start (bist_start),
        .seed_a_in  (seed_a_in),
        .seed_b_in  (seed_b_in),
        .golden_load(golden_load),
        .golden_val (golden_val),
        .bist_done  (bist_done),
        .bist_pass  (bist_pass),
        .bist_fail  (bist_fail),
        .misr_sig   (misr_sig),
        .state_dbg  (state_dbg)
    );

    // Clock generation: 100 MHz
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Watchdog timer
    initial begin
        repeat (TIMEOUT_CYC) @(posedge clk);
        $display("[TB_V1] WATCHDOG TIMEOUT after %0d cycles - simulation hung!", TIMEOUT_CYC);
        $finish;
    end

    // Task: apply_reset
    task apply_reset;
        input integer n_cycles;
        integer i;
        begin
            rst         = 1'b1;
            bist_start  = 1'b0;
            golden_load = 1'b0;
            seed_a_in   = SEED_A;
            seed_b_in   = SEED_B;
            golden_val  = 32'd0;
            for (i = 0; i < n_cycles; i = i + 1) begin
                @(posedge clk);
            end
            rst = 1'b0;
            @(posedge clk);
        end
    endtask

    // Task: run_bist_and_wait
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

    // Task: load_golden_runtime
    task load_golden_runtime;
        input [31:0] golden;
        begin
            @(posedge clk);
            golden_load = 1'b1;
            golden_val  = golden;
            @(posedge clk);
            golden_load = 1'b0;
            golden_val  = 32'd0;
        end
    endtask

    // Main Test Routine
    reg [31:0] sig_temp;
    reg [15:0] prev_lfsr_a;
    reg        seen_repeat;
    integer    n_unique;
    integer    k;
    reg [31:0] sig_before, sig_after;

    initial begin
        tests_passed = 0;
        tests_failed = 0;

        $display("=============================================================");
        $display("[TB_V1] Starting Variant 1 (Baseline) Verification");
        $display("=============================================================");

        // Test 1: Reset
        $display("\n--- TEST 1: Reset Behavior ---");
        apply_reset(10);
        if (bist_done === 1'b0 && bist_pass === 1'b0 && bist_fail === 1'b0 && state_dbg === 3'd0) begin
            $display("[TB_V1] PASS: Reset behavior verified.");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[TB_V1] FAIL: Reset output mismatch.");
            tests_failed = tests_failed + 1;
        end

        // Test 2: MAC Functional Check
        $display("\n--- TEST 2: MAC Known-Answer Test ---");
        force u_dut.u_mac.op_a = 16'hFFFF;
        force u_dut.u_mac.op_b = 16'hFFFF;
        #1;
        if (u_dut.u_mac.mac_out === 32'hFFFE_0001) begin
            $display("[TB_V1] PASS: MAC 0xFFFF * 0xFFFF = 0x%08h", u_dut.u_mac.mac_out);
            tests_passed = tests_passed + 1;
        end else begin
            $display("[TB_V1] FAIL: MAC 0xFFFF * 0xFFFF = 0x%08h (expected 0xFFFE0001)", u_dut.u_mac.mac_out);
            tests_failed = tests_failed + 1;
        end
        release u_dut.u_mac.op_a;
        release u_dut.u_mac.op_b;
        apply_reset(5);

        // Test 3: LFSR Sequence Check
        $display("\n--- TEST 3: LFSR Sequence Check ---");
        @(posedge clk);
        bist_start = 1'b1;
        @(posedge clk);
        bist_start = 1'b0;
        @(posedge clk);
        @(posedge clk);

        prev_lfsr_a = u_dut.u_tpg.reg_a;
        seen_repeat = 1'b0;
        n_unique    = 0;

        for (k = 0; k < 63; k = k + 1) begin
            @(posedge clk);
            if (u_dut.u_tpg.reg_a !== 16'h0000) n_unique = n_unique + 1;
            if (u_dut.u_tpg.reg_a === prev_lfsr_a) seen_repeat = 1'b1;
            prev_lfsr_a = u_dut.u_tpg.reg_a;
        end

        while (bist_done !== 1'b1) @(posedge clk);

        if (!seen_repeat && n_unique > 60) begin
            $display("[TB_V1] PASS: LFSR sequence valid (%0d/63 non-zero, no repeats)", n_unique);
            tests_passed = tests_passed + 1;
        end else begin
            $display("[TB_V1] FAIL: LFSR issue.");
            tests_failed = tests_failed + 1;
        end
        apply_reset(5);

        // Test 4: MISR Operation Check
        $display("\n--- TEST 4: MISR Operation ---");
        @(posedge clk);
        bist_start = 1'b1;
        @(posedge clk);
        bist_start = 1'b0;
        repeat (10) @(posedge clk);
        sig_before = misr_sig;
        repeat (10) @(posedge clk);
        sig_after = misr_sig;
        while (bist_done !== 1'b1) @(posedge clk);

        if (sig_before !== sig_after && misr_sig !== 32'd0) begin
            $display("[TB_V1] PASS: MISR actively updates (0x%08h -> 0x%08h)", sig_before, sig_after);
            tests_passed = tests_passed + 1;
        end else begin
            $display("[TB_V1] FAIL: MISR inactive.");
            tests_failed = tests_failed + 1;
        end
        apply_reset(5);

        // Test 5: Golden Signature & Fault-Free BIST
        $display("\n--- TEST 5: Golden Signature & Fault-Free BIST ---");
        run_bist_and_wait(sig_temp);
        captured_golden = u_dut.captured_sig;
        $display("[TB_V1] Captured MISR Signature = 0x%08h", captured_golden);

        if (captured_golden === 32'h036ce3d3) begin
            $display("[TB_V1] PASS: Golden signature matches expected 0x036ce3d3 exactly!");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[TB_V1] FAIL: Golden signature 0x%08h != expected 0x036ce3d3", captured_golden);
            tests_failed = tests_failed + 1;
        end

        if (bist_pass === 1'b1 && bist_fail === 1'b0) begin
            $display("[TB_V1] PASS: Fault-free BIST PASS asserted.");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[TB_V1] FAIL: Fault-free BIST did not pass (pass=%0b, fail=%0b).", bist_pass, bist_fail);
            tests_failed = tests_failed + 1;
        end
        apply_reset(5);

        // Test 6: RTL Fault Injection (SA0 on mac_out[0])
        $display("\n--- TEST 6: Fault Injection (mac_out[0] SA0) ---");
        load_golden_runtime(32'h036ce3d3);
        @(posedge clk);
        bist_start = 1'b1;
        @(posedge clk);
        bist_start = 1'b0;

        wait (state_dbg === 3'd2); // TEST_RUN
        force u_dut.u_mac.mac_out[0] = 1'b0;

        wait (bist_done === 1'b1);
        sig_temp = u_dut.captured_sig;
        release u_dut.u_mac.mac_out[0];

        if (sig_temp !== 32'h036ce3d3 && bist_fail === 1'b1 && bist_pass === 1'b0) begin
            $display("[TB_V1] PASS: Fault detected! Faulty signature=0x%08h, bist_fail=1", sig_temp);
            tests_passed = tests_passed + 1;
        end else begin
            $display("[TB_V1] FAIL: Fault not detected properly (sig=0x%08h, fail=%0b)", sig_temp, bist_fail);
            tests_failed = tests_failed + 1;
        end
        apply_reset(5);

        // Test 7: Post-Fault Regression
        $display("\n--- TEST 7: Regression After Fault Removal ---");
        load_golden_runtime(32'h036ce3d3);
        run_bist_and_wait(sig_temp);
        if (bist_pass === 1'b1 && bist_fail === 1'b0) begin
            $display("[TB_V1] PASS: Regression passed cleanly.");
            tests_passed = tests_passed + 1;
        end else begin
            $display("[TB_V1] FAIL: Regression failed.");
            tests_failed = tests_failed + 1;
        end

        // Summary
        $display("\n=============================================================");
        $display("[TB_V1] SUMMARY: %0d PASSED, %0d FAILED", tests_passed, tests_failed);
        $display("=============================================================");
        if (tests_failed == 0)
            $display("[TB_V1] ALL TESTS PASSED!");
        else
            $display("[TB_V1] SOME TESTS FAILED!");

        $finish;
    end

endmodule
