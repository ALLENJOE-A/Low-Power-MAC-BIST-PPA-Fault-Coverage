# Architecture Specification: Low-Power BIST for 16-bit MAC

## 1. Overview and Problem Statement

Arithmetic datapaths in modern System-on-Chip (SoC) devices, digital signal processors (DSPs), and machine learning accelerators are dominated by Multiply-Accumulate (MAC) units. Because these units are embedded deep within complex silicon hierarchies, direct pin access from external Automatic Test Equipment (ATE) is either physically impossible or prohibitively expensive in terms of test time and tester pin-count.

**Built-In Self-Test (BIST)** provides an on-chip, at-speed testing solution by integrating:
1. An on-chip **Test Pattern Generator (TPG)** to supply pseudo-random stimuli.
2. The **Circuit Under Test (CUT)** — here, a 16-bit unsigned MAC unit.
3. An on-chip **Output Response Analyzer (ORA)** to compact high-bandwidth response streams into a compact signature.
4. An autonomous **BIST Controller (FSM)** sequencing all test phases.
5. A **Golden Signature Register and Comparator** for local pass/fail decision making.

A critical challenge during logic BIST is that pseudo-random stimuli create significantly higher switching activity than normal functional operation. This elevated toggle rate causes severe dynamic power spikes and thermal stress, potentially damaging the die during wafer or package test. This project investigates and quantifies hardware-level low-power design techniques to mitigate test-mode power dissipation.

---

## 2. Block-by-Block Architectural Breakdown

```
+-----------------------------------------------------------------------------------------+
|                                  mac_bist_top_v[1..6]                                   |
|                                                                                         |
|  clk ----------> [ bist_controller ]                                                    |
|  rst ---------->   - 5/7-State One-Hot FSM                                              |
|  bist_start --->   - Enable Schedule: lfsr_en, mac_en, misr_en, capture, compare_en     |
|                           |                                                             |
|                           v                                                             |
|                    [ lfsr_tpg ]                                                         |
|                      - LFSR A: Poly x^16+x^15+x^13+x^4+1 (0xD008), Seed: 0xACE1         |
|                      - LFSR B: Poly x^16+x^14+x^13+x^11+1 (0xB400), Seed: 0x1234        |
|                           |                                                             |
|                           v [op_a, op_b: 16-bit]                                        |
|                   [ Optional Low-Power Blocks: ICG, Operand Isolation, Bus Inversion ]  |
|                           |                                                             |
|                           v                                                             |
|                    [ mac_16bit (CUT) ]                                                  |
|                      - 16x16 Unsigned Combinational Multiplier                          |
|                      - 40-bit Synchronous Accumulator (32-bit sum + 8 guard bits)       |
|                      - Direct product output mac_out[31:0] exposed to MISR              |
|                           |                                                             |
|                           v mac_out[31:0]                                               |
|                    [ misr_ora (32-bit) ]                                                |
|                      - Poly: x^32+x^22+x^2+x+1 (Tap: 0x80200003 / 0x00400007)          |
|                      - Aliasing Probability: P_alias ~= 2^-32 ~= 2.33 x 10^-10          |
|                           |                                                             |
|                           v misr_sig[31:0]                                              |
|                 [ signature_comparator ] <---> [ golden_signature_reg ]                 |
|                   - Compare captured vs. golden (0x036ce3d3 / 0x1F5FAF38)               |
|                           |                                                             |
|  bist_done <--------------+                                                             |
|  bist_pass <--------------+                                                             |
|  bist_fail <--------------+                                                             |
+-----------------------------------------------------------------------------------------+
```

---

### 2.1 Circuit Under Test: 16-bit MAC (`mac_16bit.v`)

The MAC is the core mathematical engine of DSP datapaths:

$$\text{product} = \text{op\_a}[15:0] \times \text{op\_b}[15:0] \quad (32\text{ bits})$$

$$\text{accum}[39:0] \leftarrow \text{accum}[39:0] + \text{product}[31:0] \quad (\text{synchronous})$$

#### Key Design Rationale:
* **Exposing Per-Cycle Product to MISR**: The MISR samples the 32-bit combinational multiplier product (`mac_out`), not the running accumulator. If the accumulator were sampled directly, single-cycle multiplier faults occurring early in the test could be masked by subsequent arithmetic additions over 256 or 4096 cycles, yielding false passes. Exposing `mac_out` maximizes per-cycle fault observability.
* **40-Bit Accumulator Width**: Consists of 32 bits for maximum single product ($0\text{xFFFF} \times 0\text{xFFFF} \approx 2^{32}$) plus 8 guard bits. This provides overflow protection for up to 256 consecutive maximum-magnitude additions ($256 \times 2^{32} = 2^{40}$).
* **Reset & Enable**: Synchronous active-high reset clears the accumulator to 0; enable pin controls accumulation latching.

---

### 2.2 Test Pattern Generator: Dual LFSR (`lfsr_tpg.v`)

Pseudo-random testing requires high pattern diversity and low cross-correlation between operands $A$ and $B$:
* **Dual Independent Fibonacci LFSRs**: Instead of feeding both operands from a single 32-bit shift register (which introduces spatial correlation), two independent 16-bit LFSRs are employed.
* **Primitive Characteristic Polynomials**:
  * **LFSR A**: $P_A(x) = x^{16} + x^{15} + x^{13} + x^4 + 1$ (Tap mask: `16'hD008`), Seed: `16'hACE1`
  * **LFSR B**: $P_B(x) = x^{16} + x^{14} + x^{13} + x^{11} + 1$ (Tap mask: `16'hB400`), Seed: `16'h1234` / `16'h1B3D`
* **Period**: Both polynomials are maximal-length primitive polynomials over $\text{GF}(2)$, generating repeat-free cycles of $2^{16} - 1 = 65,535$ states.
* **Hardware Implementation**: Feedback is computed combinationally via parity reduction:
  $$\text{fb} = \bigoplus (\text{reg} \ \&\ \text{POLY\_MASK})$$
  Next state: $\{\text{reg}[14:0], \text{fb}\}$.

---

### 2.3 Output Response Analyzer: 32-bit MISR (`misr_ora.v`)

Directly storing 4096 32-bit outputs on-chip requires $4096 \times 32 = 131,072$ bits of memory. A Multiple-Input Signature Register (MISR) compacts this entire temporal output stream into a single 32-bit word.

* **Polynomial**: Primitive 32-bit polynomial:
  $$P_M(x) = x^{32} + x^{22} + x^2 + x + 1$$
* **Tap Mask**: `32'h80200003` (Fibonacci) / `32'h00400007` (Galois).
* **Compaction Operation**:
  $$\text{misr\_reg}_{t+1} = \{\text{misr\_reg}_t[30:0], \text{feedback}\} \oplus \text{data\_in}[31:0]$$
* **Aliasing Probability**:
  The probability of an error sequence escaping detection (aliasing) for an $m$-bit MISR is:
  $$P_{\text{alias}} = \frac{2^{N-m} - 1}{2^N - 1} \approx 2^{-m} = 2^{-32} \approx 2.328 \times 10^{-10}$$
  This is approximately 1 in 4.3 billion, making aliasing practically negligible.

---

### 2.4 BIST Controller FSM (`bist_controller.v`)

Sequencing is governed by a robust, one-hot encoded finite state machine:

| State | Encoding | Duration | Active Signals | Function |
|---|---|---|---|---|
| **IDLE** | `7'b000_0001` | Indefinite | None | Awaiting `bist_start` trigger pulse |
| **SEED_LOAD / INIT** | `7'b000_0010` | 1 cycle | `seed_load=1` | Loads seed values into LFSR registers |
| **TEST_RUN** | `7'b000_0100` | $N$ cycles | `lfsr_en=1, mac_en=1, misr_en=1` | Simultaneous pattern generation, MAC computation, and MISR compaction |
| **SIGNATURE_CAPTURE** | `7'b000_1000` | 1 cycle | `capture=1` | Latches final compacted MISR signature |
| **COMPARE** | `7'b001_0000` | 1 cycle | `compare_en=1` | Compares captured signature with golden register |
| **PASS** | `7'b010_0000` | Latched | `bist_done=1, bist_pass=1` | Signatures matched; test passed |
| **FAIL** | `7'b100_0000` | Latched | `bist_done=1, bist_fail=1` | Signature mismatch; faulty net detected |

---

## 3. Low-Power Architectural Variants

### Variant 1: Baseline Architecture (`mac_bist_top_v1.v`)
Standard unoptimized BIST core. Serves as the reference for area, power, and timing comparisons.

### Variant 2: Clock Gating (`mac_bist_top_v2.v`)
* **Mechanism**: Latch-based Integrated Clock Gating (ICG) cells (`icg_cell.v`) are instantiated for the LFSR, MAC, and MISR clock trees.
* **Gating Schedule**: Enables are derived by `clock_gate_ctrl.v`. During `IDLE`, `SIGNATURE_CAPTURE`, and `COMPARE`, clocks to the arithmetic core and LFSRs are clamped low.
* **Measured Benefit**: Eliminates redundant clock tree distribution power and flip-flop internal clock buffer toggling during non-active cycles, saving **4.7% total power** and reducing cell count by **7.6%**.

### Variant 3: Operand Isolation (`mac_bist_top_v3.v`)
* **Mechanism**: Combinational AND-mask cells (`operand_isolation_cell.v`) are inserted directly on the 16-bit operand buses immediately before entering the MAC core.
* **Operation**: When `mac_en = 0`, both operand inputs to the multiplier are clamped to zero (`16'h0000`).
* **Measured Benefit**: Prevents upstream LFSR seed initialization or boundary transitions from propagating into the deep combinational multiplier array, achieving a **9.6% reduction in dynamic switching power** and **5.7% total power reduction**.

### Variant 4: Bus Inversion (`mac_bist_top_v4.v`)
* **Mechanism**: Computes the Hamming distance between consecutive operand vectors. If $\text{Hamming Distance} > \frac{W}{2} = 8$, the data is inverted and an inversion flag is transmitted; a decoder on the receiver side reconstructs the original word.
* **Measured Result (Negative Finding)**: Increased total power by **+48.1%** and area by **+24.5%**. On short on-chip buses with low physical wire capacitance, the hardware overhead of the 16-bit XOR comparator, priority encoder, and decoder exceeds any bus switching savings.

### Variant 5: Combined All (`mac_bist_top_v5.v`)
* **Mechanism**: Incorporates Clock Gating + Operand Isolation + Bus Inversion simultaneously.
* **Measured Result**: Power increased by **+37.9%** due to the dominant overhead of the bus-inversion encoders and decoders.

### Variant 6: Combined Operand Isolation + Clock Gating (`mac_bist_top_v6.v`)
* **Mechanism**: Combines the two beneficial techniques (ICG clock gating on sequential elements + AND-mask operand isolation on combinational datapath) while omitting bus inversion.
* **Measured Result (Best in Class)**:
  * **Total Power Reduction**: **-10.1%** ($794.993\ \mu\text{W}$ vs $884.357\ \mu\text{W}$)
  * **Area Reduction**: **-2.7%** ($9660.32\ \mu\text{m}^2$ vs $9926.74\ \mu\text{m}^2$)
  * **Cell Count Reduction**: **-4.9%** (1127 vs 1185 cells)
  * **Switching Power Reduction**: **-13.3%**
