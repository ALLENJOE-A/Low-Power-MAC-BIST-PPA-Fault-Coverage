# Low-Power Aware BIST Architecture for 16-bit MAC
## Implementation Plan — Phase 1: Architecture Analysis & Parameter Decisions

---

## 1. Project Summary

Build, verify, synthesize, and compare **5 RTL variants** of a 16-bit MAC BIST architecture, each isolating one low-power technique. Measure actual PPA and fault-coverage trade-offs — no fabricated results.

---

## 2. Parameter Analysis

The table below classifies every architectural parameter as:
- **[SPEC]** — Explicitly stated in the project specification
- **[IMPL]** — Selected implementation parameter (justified below)
- **[TOOL]** — Depends on synthesis tool / technology library availability

### 2.1 MAC Core Parameters

| Parameter | Value | Source | Justification |
|---|---|---|---|
| Multiplier input width | 16 bits | [SPEC] | "16×16 multiplier" |
| Multiplier output width | 32 bits | [IMPL] | 16×16 product is 32 bits max |
| Accumulator width | 40 bits | [IMPL] | 32-bit product + up to 256 accumulations (8 guard bits); prevents overflow during BIST |
| Pipeline stages | 0 (combinational mult) | [IMPL] | Simplifies BIST control FSM; avoids pipeline flush complexity |
| Reset strategy | Synchronous active-high | [IMPL] | Avoids asynchronous reset metastability; compatible with all standard-cell libraries |

### 2.2 LFSR (TPG) Parameters

| Parameter | Value | Source | Justification |
|---|---|---|---|
| LFSR width | 16 bits each (×2 LFSRs) | [SPEC] | "two independent LFSRs for the two MAC operands" |
| LFSR A polynomial | x¹⁶ + x¹⁵ + x¹³ + x⁴ + 1 (tap mask = 16'hD008) | [IMPL] | Maximal-length primitive polynomial for 16-bit; period = 65535 |
| LFSR B polynomial | x¹⁶ + x¹⁴ + x¹³ + x¹¹ + 1 (tap mask = 16'hB400) | [IMPL] | Second distinct maximal-length polynomial; ensures statistical independence |
| LFSR A seed | 16'hACE1 | [IMPL] | Non-zero, non-trivial seed |
| LFSR B seed | 16'h1234 | [IMPL] | Non-zero, distinct from A |
| LFSR type | Fibonacci (XOR feedback from taps) | [IMPL] | Standard; easily synthesizable |
| Enable | Single-bit, from bist_controller | [SPEC] | Controller generates clean enables |

### 2.3 MISR (ORA) Parameters

| Parameter | Value | Source | Justification |
|---|---|---|---|
| MISR width | 32 bits | [IMPL] | Matches MAC output width; wider MISR reduces aliasing probability |
| MISR polynomial | x³² + x²⁸ + x²⁷ + x + 1 (primitive, CRC-32 derivative) | [IMPL] | Well-known maximal-length 32-bit polynomial; aliasing ≈ 2⁻³² ≈ 2.3×10⁻¹⁰ |
| Input to MISR | 32-bit MAC product output | [IMPL] | Accumulator output would mask individual-cycle faults; product captures per-cycle behavior |
| Golden signature width | 32 bits | [IMPL] | Matches MISR width |
| Aliasing probability | 2⁻³² ≈ 2.33×10⁻¹⁰ | [IMPL] | Theoretically much better than 16-bit MISR (2⁻¹⁶ ≈ 1.5×10⁻⁵) |

### 2.4 BIST Controller Parameters

| Parameter | Value | Source | Justification |
|---|---|---|---|
| FSM encoding | One-hot | [IMPL] | Reduces combinational logic depth; avoids glitches; easier to debug |
| Test cycle count | 256 cycles | [IMPL] | Balances coverage vs. simulation time; exercises all LFSR short sequences |
| Counter width | 9 bits (counts 0–511) | [IMPL] | Covers 256 cycles with headroom |
| SEED_LOAD cycles | 1 cycle | [IMPL] | Single-cycle load of LFSR seeds |
| SIGNATURE_CAPTURE cycles | 1 cycle | [IMPL] | Latch final MISR value |
| COMPARE cycles | 1 cycle | [IMPL] | Combinational comparison, registered result |

### 2.5 Low-Power Variant Parameters

| Parameter | Value | Source | Justification |
|---|---|---|---|
| Clock gating style | ICG cell (latch-based) | [SPEC] | "synthesizable integrated-clock-gating style" |
| Gated clocks | LFSR clock, MAC clock, MISR clock | [IMPL] | Each block gated independently |
| Operand isolation value | Hold last valid value (register) | [IMPL] | Prevents spurious MAC switching; preserves accumulator |
| Bus inversion threshold | Hamming distance > WIDTH/2 | [SPEC] | Standard bi-directional bus inversion criterion |
| Bus width for BI | 16 bits (LFSR output bus) | [IMPL] | Most active data bus in BIST; highest switching activity |

### 2.6 Synthesis / Tool Parameters

| Parameter | Value | Source |
|---|---|---|
| Target clock frequency | 100 MHz (10 ns period) | [TOOL] |
| Setup slack target | ≥ 0 ns | [TOOL] |
| Technology library | Generic 45nm (OSU45 or NanGate45 open-cell library) | [TOOL] |
| Genus version | 21.1+ assumed | [TOOL] |
| SDC version | SDC 1.9 | [TOOL] |
| Power analysis method | SAIF back-annotation | [TOOL] |

> [!IMPORTANT]
> **Technology Library**: The project requires a `.lib` file for Genus synthesis. The plan uses **NanGate 45nm Open Cell Library** (free/open). If a different library is available, update `scripts/genus/synthesis.tcl` with the correct `.lib` path. All synthesis scripts are templated; no PPA numbers are fabricated.

---

## 3. Architecture & Data Flow

### 3.1 Block Diagram (All Variants share this spine)

```
                    ┌─────────────────────────────────────────────────────┐
                    │                  mac_bist_top                        │
                    │                                                       │
  clk ─────────────┼──► bist_controller ──────────────────────────────►  │
  rst_n ───────────┼──►   (FSM)          │ lfsr_en                        │
  bist_start ──────┼──►                  │ mac_en                         │
                    │                    │ misr_en                         │
                    │                    │ seed_load                       │
                    │                    │ capture                         │
                    │                    │ compare_en                      │
                    │                    ▼                                  │
                    │   ┌──────────────────────────────┐                   │
                    │   │        lfsr_tpg               │                   │
                    │   │  LFSR_A (poly_A, seed_A)      │                   │
                    │   │  LFSR_B (poly_B, seed_B)      │                   │
                    │   └────────┬─────────┬────────────┘                   │
                    │          op_a[15:0] op_b[15:0]                        │
                    │            │         │                                │
                    │            ▼         ▼                                │
                    │   ┌──────────────────────────────┐                   │
                    │   │        mac_16bit (DUT)         │                   │
                    │   │  product = op_a × op_b        │                   │
                    │   │  accum += product             │                   │
                    │   │  out[31:0] = product          │                   │
                    │   └──────────────┬────────────────┘                   │
                    │                 mac_out[31:0]                         │
                    │                  │                                    │
                    │                  ▼                                    │
                    │   ┌──────────────────────────────┐                   │
                    │   │        misr_ora               │                   │
                    │   │  Shift+XOR compaction         │                   │
                    │   │  32-bit signature             │                   │
                    │   └──────────────┬────────────────┘                   │
                    │                misr_sig[31:0]                         │
                    │                  │                                    │
                    │   ┌─────────────▼──────────────────┐                │
                    │   │   golden_signature_reg          │                │
                    │   │   (stores fault-free reference) │                │
                    │   └─────────────┬──────────────────┘                │
                    │               golden[31:0]                           │
                    │                  │                                    │
                    │   ┌─────────────▼──────────────────┐                │
                    │   │   signature_comparator          │                │
                    │   │   (misr_sig == golden ?)        │                │
                    │   └─────────────┬──────────────────┘                │
                    │               bist_pass / bist_fail                  │
                    └─────────────────────────────────────────────────────┘
```

### 3.2 BIST Controller FSM

```
        ┌──────┐  bist_start   ┌───────────┐  1 cycle   ┌──────────┐
        │ IDLE │──────────────►│ SEED_LOAD │───────────►│ TEST_RUN │
        └──────┘               └───────────┘            └────┬─────┘
                                                             │ count==TEST_CYCLES
                                                             ▼
                                                    ┌──────────────────┐
                                                    │ SIGNATURE_CAPTURE│
                                                    └────────┬─────────┘
                                                             │ 1 cycle
                                                             ▼
                                                    ┌──────────────────┐
                                                    │     COMPARE      │
                                                    └────────┬─────────┘
                                                             │ 1 cycle
                                                    ┌────────┴─────────┐
                                                    ▼                   ▼
                                                 ┌─────┐           ┌──────┐
                                                 │PASS │           │ FAIL │
                                                 └─────┘           └──────┘
                                                    │                   │
                                                    └────────┬──────────┘
                                                             │ (stay until rst)
                                                             ▼
                                                          ┌──────┐
                                                          │ IDLE │
                                                          └──────┘
```

### 3.3 Enable Signal Schedule

| Controller State | lfsr_en | mac_en | misr_en | seed_load | capture | compare_en |
|---|---|---|---|---|---|---|
| IDLE | 0 | 0 | 0 | 0 | 0 | 0 |
| SEED_LOAD | 0 | 0 | 0 | 1 | 0 | 0 |
| TEST_RUN | 1 | 1 | 1 | 0 | 0 | 0 |
| SIGNATURE_CAPTURE | 0 | 0 | 0 | 0 | 1 | 0 |
| COMPARE | 0 | 0 | 0 | 0 | 0 | 1 |
| PASS/FAIL | 0 | 0 | 0 | 0 | 0 | 0 |

### 3.4 Variant-Specific Additions

**Variant 2 — Clock Gating:**
- `icg_cell`: Latch-based ICG; enable sampled on low phase of clock to eliminate glitches
- `clock_gate_ctrl`: Decodes controller state into per-block gating enables
- Gated clocks: `clk_lfsr`, `clk_mac`, `clk_misr`
- When gated: IDLE, SEED_LOAD (MAC+MISR off), SIGNATURE_CAPTURE (LFSR+MAC off), COMPARE (all off)

**Variant 3 — Operand Isolation:**
- `operand_isolation_cell`: Registered hold of last valid operand; gates when `mac_en=0`
- `isolation_enable_ctrl`: Generates `iso_en` from controller state
- Isolated signals: `op_a`, `op_b` into MAC
- Active only during: TEST_RUN state

**Variant 4 — Bus Inversion:**
- `bus_invert_encoder`: Computes Hamming distance vs. previous bus; inverts if HW > WIDTH/2; sends {INVERT_FLAG, data}
- `bus_invert_decoder`: Reconstructs original data from {INVERT_FLAG, data}
- Applied to: LFSR → MAC operand buses (op_a, op_b)

**Variant 5 — Combined:**
- All three techniques stacked on top of baseline
- Enable signals orchestrated so no technique conflicts with another

---

## 4. Golden Signature Generation Flow

```
STEP 1: Synthesize baseline RTL → gate-level netlist
STEP 2: Simulate fault-free netlist with fixed seeds and TEST_CYCLES=256
STEP 3: At SIGNATURE_CAPTURE state, read misr_sig[31:0]
STEP 4: Write value into golden_signature_reg parameter
STEP 5: Recompile with fixed golden value for subsequent fault runs
```

> [!IMPORTANT]
> The golden signature MUST be derived from fault-free simulation, not calculated analytically. The `generate_golden_sig.tcl` script automates steps 2–4.

---

## 5. Fault Coverage Flow

```
RTL → Genus → gate-level netlist (variant1_baseline_netlist.v)
          ↓
   Parse netlist → extract all nets → generate fault list
          ↓
   For each fault (net, sa0 / sa1):
      1. force <net> <value>
      2. run simulation (256 cycles)
      3. capture misr_sig
      4. compare vs golden
      5. log DETECTED / UNDETECTED
      6. noforce
          ↓
   Fault Coverage = detected / total × 100%
```

Fault injection script: `scripts/fault_coverage/run_fault_sim.tcl`

---

## 6. MISR Aliasing Analysis

| MISR Width | Aliasing Probability | Comment |
|---|---|---|
| 16-bit | 2⁻¹⁶ ≈ 1.53 × 10⁻⁵ | Not recommended for production |
| **32-bit (selected)** | **2⁻³² ≈ 2.33 × 10⁻¹⁰** | **Acceptable for academic analysis** |
| 64-bit | 2⁻⁶⁴ ≈ 5.4 × 10⁻²⁰ | Overkill for this scope |

A 32-bit MISR means that on average, 1 in ~4.3 billion faults could produce the golden signature despite the fault being present (aliasing). This will be documented explicitly in the final report.

---

## 7. Directory Structure

```
MAC_BIST/
├── rtl/
│   ├── common/
│   │   ├── lfsr_tpg.sv
│   │   ├── mac_16bit.sv
│   │   ├── misr_ora.sv
│   │   ├── bist_controller.sv
│   │   ├── signature_comparator.sv
│   │   └── golden_signature_reg.sv
│   ├── variant1_baseline/
│   │   └── mac_bist_top.sv
│   ├── variant2_clock_gating/
│   │   ├── icg_cell.sv
│   │   ├── clock_gate_ctrl.sv
│   │   └── mac_bist_top_v2.sv
│   ├── variant3_operand_isolation/
│   │   ├── operand_isolation_cell.sv
│   │   ├── isolation_enable_ctrl.sv
│   │   └── mac_bist_top_v3.sv
│   ├── variant4_bus_inversion/
│   │   ├── bus_invert_encoder.sv
│   │   ├── bus_invert_decoder.sv
│   │   └── mac_bist_top_v4.sv
│   └── variant5_combined/
│       └── mac_bist_top_v5.sv
├── tb/
│   ├── tb_mac_bist.sv          ← Main testbench
│   ├── tests/
│   │   ├── test_reset.sv
│   │   ├── test_mac_func.sv
│   │   ├── test_lfsr_seq.sv
│   │   ├── test_misr_op.sv
│   │   ├── test_bist_fsm.sv
│   │   ├── test_golden_sig.sv
│   │   └── test_fault_free.sv
│   └── fault_injection/
│       ├── fault_list_gen.tcl
│       └── fault_inject_template.sv
├── scripts/
│   ├── simulation/
│   │   ├── compile_all.tcl
│   │   └── run_sim.tcl
│   ├── fault_coverage/
│   │   ├── run_fault_sim.tcl
│   │   └── fault_report.tcl
│   └── genus/
│       ├── synthesis.tcl
│       ├── extract_reports.tcl
│       └── power_analysis.tcl
├── constraints/
│   └── mac_bist.sdc
├── reports/
│   ├── fault_coverage/
│   ├── area/
│   ├── power/
│   └── timing/
└── README.md
```

---

## 8. Implementation Phases

| Phase | Deliverable | Status |
|---|---|---|
| **Phase 1** | Architecture analysis, parameters, plan (this document) | ✅ Pending approval |
| **Phase 2** | Common RTL modules (lfsr, mac, misr, controller, comparator) | 🔲 |
| **Phase 3** | Variant 1 — Baseline top-level + testbench + functional sim | 🔲 |
| **Phase 4** | Variant 2 — Clock gating | 🔲 |
| **Phase 5** | Variant 3 — Operand isolation | 🔲 |
| **Phase 6** | Variant 4 — Bus inversion | 🔲 |
| **Phase 7** | Variant 5 — Combined | 🔲 |
| **Phase 8** | Fault injection scripts + coverage calculation | 🔲 |
| **Phase 9** | Synthesis scripts (Genus) + SDC | 🔲 |
| **Phase 10** | Final comparison table + README | 🔲 |

---

## 9. Open Questions / Decisions Requiring Confirmation

> [!IMPORTANT]
> **Q1 — MAC output to MISR**: Should the MISR compact the 32-bit *multiplier product* (per-cycle output) or the 40-bit *accumulator* value? 
> 
> **Proposed default**: Use the 32-bit product per cycle (mac_out = op_a × op_b). The accumulator is a running sum — feeding it into MISR would reduce fault observability because accumulator errors from early cycles get masked by later additions.

> [!IMPORTANT]
> **Q2 — Test cycle count**: 256 cycles proposed. Is this acceptable, or does the specification require a longer sequence (e.g., full LFSR period of 65535 cycles)? 
>
> **Trade-off**: 256 cycles → fast simulation + lower fault coverage. 65535 cycles → maximal coverage + very long fault injection runtime (65535 × N_faults simulations).
>
> **Proposed default**: 256 for functional verification; option to set 1024 for coverage measurement runs via parameter.

> [!IMPORTANT]
> **Q3 — Technology library**: The synthesis scripts will be written for NanGate 45nm Open Cell Library. If you have access to a specific library (TSMC, GlobalFoundries, OSU, etc.), specify the `.lib` path and the scripts will be updated accordingly.

> [!NOTE]
> **Q4 — Simulator**: Scripts are written for **Questa/ModelSim**. If using Synopsys VCS or Cadence Xcelium, the compile/simulate commands differ but the Tcl fault injection approach is compatible with all three.

> [!NOTE]
> **Q5 — Gray coding in Variant 4**: The specification states Gray coding "may provide little benefit for pseudo-random LFSR sequences." The plan implements **bus inversion as primary** and includes Gray encoder/decoder as a **measurement-only comparison block** (not in the critical path). Confirm this approach is acceptable.

---

## 10. Key Constraints Summary

| Constraint | Value |
|---|---|
| Data width | 16-bit operands, 32-bit product, 40-bit accumulator |
| MISR width | 32 bits |
| Test cycles (default) | 256 |
| Clock period (SDC) | 10 ns (100 MHz) |
| Reset | Synchronous, active-high |
| FSM encoding | One-hot |
| LFSR type | Fibonacci, maximal-length |
| Language | SystemVerilog (synthesizable subset) |
| No fabricated results | Strictly enforced |
