# Fault Injection & Coverage Analysis Methodology

## 1. Overview of the Fault Simulation Flow

Fault simulation is the standard DFT verification step used to determine the test quality and defect detection capability of an on-chip test architecture. 

In this project, fault grading was performed via **direct simulation-based single stuck-at fault injection on the post-synthesis gate-level netlist** of the baseline MAC BIST core (`v1_normal_netlist.v`), synthesized with Cadence Genus 21.1 on the `slow_vdd1v0.lib` (1.0 V, slow corner) standard-cell library.

```
                    +------------------------------------+
                    | RTL Design (mac_bist_top_v1.v)     |
                    +-----------------+------------------+
                                      |
                                      | Cadence Genus 21.1
                                      v
                    +------------------------------------+
                    | Gate-Level Netlist (v1_normal)     |
                    +-----------------+------------------+
                                      |
                   Net Enumeration    | Excluding clk, rst_n
                   (980 net sites)    | 2 polarities / net (SA0, SA1)
                                      v
                    +------------------------------------+
                    | 1960 Single Stuck-At Faults List   |
                    +-----------------+------------------+
                                      |
           +--------------------------+--------------------------+
           | Parallel Execution in 8 Chunks (Cadence Incisive)   |
           | For each fault:                                     |
           |   1. Apply Reset (10 ns)                            |
           |   2. Force Net to Stuck-At Value (SA0 or SA1)       |
           |   3. Run BIST Sequence (4096 Patterns)              |
           |   4. Sample MISR Signature at Checkpoints           |
           |   5. Compare with Golden Reference (0x1F5FAF38)     |
           |   6. Release Forced Net                             |
           +--------------------------+--------------------------+
                                      |
                                      v
                    +------------------------------------+
                    | Fault Coverage Summary & Reports   |
                    | Final Coverage: 99.8980% (1958/1960|
                    +------------------------------------+
```

---

## 2. Fault Site Enumeration and Universe

Fault sites were identified by parsing all internal wire, input, and output declarations within the `mac16` instance (the Circuit Under Test) in the gate-level netlist:

* **Eligible Net Sites**: 980 distinct nets.
* **Fault Model**: Single Stuck-At (SSA).
* **Fault Polarities**: Both Stuck-At-0 (SA0) and Stuck-At-1 (SA1) applied to every net.
* **Total Fault Universe**:
  $$\text{Total Faults} = 980 \times 2 = 1960\text{ stuck-at faults}$$
* **Exclusions**: The clock net (`clk`) and asynchronous reset (`rst_n`) were excluded from the fault list to avoid trivial simulation hangs.

---

## 3. Test Execution and Detection Criterion

For each fault:
1. The design is initialized with an asynchronous reset pulse.
2. The targeted net is forced to the corresponding stuck-at logic level (`1'b0` for SA0, `1'b1` for SA1).
3. The BIST controller is triggered via `bist_start`, executing $N = 4096$ test cycles.
4. During test execution, the MISR signature is sampled at predetermined checkpoints ($N = 32, 64, 128, 256, 512, 1024, 2048, 4096$).
5. **Detection Rule**:
   $$\text{Fault Detected} \iff \text{MISR\_Signature}(N) \neq \text{GOLDEN\_SIGNATURE} \ (0\text{x1F5FAF38})$$
6. The force on the net is released, and the harness proceeds to the next fault case.

The entire 1960-fault campaign was partitioned into 8 chunks of $\le 245$ faults and executed in parallel on a dedicated CAD server (`cad312vitcc.vit.ac.in`).

---

## 4. Measured Fault Coverage Progression

The table below records the cumulative fault detection across pattern checkpoints for the full 1960-fault campaign:

| Pattern Count ($N$) | Detected Faults | Total Modeled Faults | Fault Coverage (%) | Incremental Detections |
|---|---|---|---|---|
| **32** | 1952 | 1960 | **99.5918%** | 1952 |
| **64** | 1957 | 1960 | **99.8469%** | +5 |
| **128** | 1958 | 1960 | **99.8980%** | +1 |
| **256** | 1958 | 1960 | **99.8980%** | 0 |
| **512** | 1958 | 1960 | **99.8980%** | 0 |
| **1024** | 1958 | 1960 | **99.8980%** | 0 |
| **2048** | 1958 | 1960 | **99.8980%** | 0 |
| **4096 (FINAL)** | **1958** | **1960** | **99.8980%** | **0 (Plateaued)** |

### Analysis of the Plateau:
* Within the first **32 patterns**, over **99.59%** of all faults are excited and propagated into the MISR.
* By **128 patterns**, coverage reaches its asymptotic limit of **99.8980%**.
* Extending the test length from 128 to 4096 cycles (a 32-fold increase) detects **zero additional faults**. This proves conclusively that the remaining undetected faults are not "random-pattern resistant" datapath faults, but structural control-signal masking.

---

## 5. Root-Cause Analysis of Undetected Faults

The campaign identified exactly **2 undetected faults** out of 1960:

```
fault_id=1  SA1  en
fault_id=2  SA0  clr
```

### Detailed Circuit Analysis:

1. **`fault_id = 1`: Stuck-At-1 on MAC Accumulate Enable (`en`)**
   * **Why it escapes detection**: During the entire `TEST_RUN` phase ($N$ cycles), the BIST controller deliberately holds `mac_en` continuously asserted at `1'b1`. Therefore, a net stuck at `1'b1` produces the exact same behavior as the fault-free controller during pattern processing. During `INIT`, synchronous `clr` takes precedence over `en`. During `FLUSH`, the final signature is captured prior to any extra clock edge. Hence, the faulty machine produces the golden signature `0x1F5FAF38`.

2. **`fault_id = 2`: Stuck-At-0 on MAC Synchronous Clear (`clr`)**
   * **Why it escapes detection**: The BIST harness applies an asynchronous reset (`rst_n`) prior to each test run, which unconditionally initializes the accumulator registers to `0x00000000`. In the subsequent `INIT` state, the controller asserts `clr`, but since the registers already hold zeros, the synchronous clear does not alter register state. Throughout the subsequent `TEST_RUN`, `clr` is held low at `1'b0`. A stuck-at-0 fault on `clr` therefore has zero effect on the output response.

### DFT Recommendations for 100% Coverage:
* Add an explicit **controller self-test phase** where `mac_en` is deasserted for 1 cycle mid-test while operands toggle, verifying that accumulation halts.
* Initialize the accumulator to non-zero values before pulsing `clr` during `INIT`, ensuring observability of the synchronous clear path.
