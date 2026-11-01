# Low-Power Optimization Techniques and PPA Evaluation

## 1. Motivation for Low-Power BIST

In high-reliability ASIC design, test power is a major design consideration:
* **Elevated Toggle Rates**: During functional operation, consecutive datapath vectors typically exhibit temporal correlation. In contrast, pseudo-random LFSR patterns exhibit approximately 50% transition probability across all input bits on every clock cycle.
* **Excessive Dynamic Dissipation**: The heightened switching rate induces severe $L \cdot \frac{di}{dt}$ voltage droop on the power grid and substantial thermal dissipation.
* **Risks of Unconstrained Test Power**:
  1. Excessive IR drop causing spurious timing violations and false test failures (yield loss).
  2. Thermal hotspots exceeding maximum junction temperature, resulting in permanent silicon degradation.

To mitigate this, four low-power architectural strategies were designed, synthesized, and rigorously compared under identical constraints.

---

## 2. Low-Power Implementations

### 2.1 Integrated Clock Gating (ICG) — Variant 2
* **RTL Modules**: `icg_cell.v`, `clock_gate_ctrl.v`, `mac_bist_top_v2.v`
* **Mechanism**: Integrated Clock Gating replaces per-flip-flop multiplexer feedback with a centralized gated clock tree. A negative-level sensitive transparent latch samples the enable signal during the clock's low phase (`clk = 0`), which feeds an AND gate with the clock:
  $$\text{gated\_clk} = \text{clk} \ \&\ \text{latched\_enable}$$
  This structure prevents glitches or runt pulses on `gated_clk`.
* **Gating Policy**:
  * `clk_lfsr`: Enabled during `SEED_LOAD` and `TEST_RUN`; disabled otherwise.
  * `clk_mac`: Enabled exclusively during `TEST_RUN`; disabled during `IDLE`, `SEED_LOAD`, `SIGNATURE_CAPTURE`, and `COMPARE`.
  * `clk_misr`: Enabled during `TEST_RUN` and `SIGNATURE_CAPTURE`.
* **Result**: Reduces total power by **4.7%** and decreases total area by **4.2%** due to the elimination of feedback multiplexers in standard flip-flops.

---

### 2.2 Operand Isolation — Variant 3
* **RTL Modules**: `operand_isolation_cell.v`, `isolation_enable_ctrl.v`, `mac_bist_top_v3.v`
* **Mechanism**: Multiplier arrays are deep combinational structures. Any transition on input operands propagates through multiple levels of partial-product generators, Carry-Save Adder (CSA) trees, and vector merge adders.
* **Implementation**: A bank of 32 AND gates clamps both 16-bit operand buses (`op_a` and `op_b`) to `16'h0000` whenever the MAC is inactive (`mac_en = 0`):
  $$\text{iso\_data}[15:0] = \text{lfsr\_data}[15:0] \ \&\ \{16\{\sim\text{iso\_en}\}\}$$
* **Result**: Provides a **9.6% reduction in dynamic switching power** and a **5.7% total power reduction** at a minimal area penalty of **+1.5%** (1217 vs 1185 cells).

---

### 2.3 Bus Inversion Coding — Variant 4 (Negative Result Analysis)
* **RTL Modules**: `bus_invert_encoder.v`, `bus_invert_decoder.v`, `mac_bist_top_v4.v`
* **Mechanism**: Dynamically computes the Hamming distance between consecutive operand vectors. If more than 8 bits toggle ($> \frac{W}{2}$), the bus is inverted and an auxiliary `inv_flag` bit is asserted.
* **Measured Result**:
  * Total Power: **+48.1% increase** ($1310.060\ \mu\text{W}$ vs $884.357\ \mu\text{W}$).
  * Area: **+24.5% increase** ($12354.88\ \mu\text{m}^2$ vs $9926.74\ \mu\text{m}^2$).
  * Cell Count: **+27.9% increase** (1516 vs 1185 cells).
* **Engineering Root Cause**: Bus-invert coding is designed for long off-chip PCB traces or global buses with high physical interconnect capacitance ($C_{\text{wire}} \gg C_{\text{gate}}$). On short on-chip buses within a localized BIST module, the physical wire capacitance is negligible compared to the active switching power of the 16-bit XOR tree, transition counter, and decoding logic. The added hardware drastically increased power consumption. This negative result is reported transparently as a key engineering finding.

---

### 2.4 Combined Optimizations (Variants 5 & 6)
* **Variant 5 (Combined All)**: Combines Clock Gating + Operand Isolation + Bus Inversion. Power increased by **+37.9%** due to the bus-inversion overhead.
* **Variant 6 (Operand Isolation + Clock Gating)**: Combines sequential clock gating (ICG) with combinational operand isolation (AND-masking), omitting bus inversion.
  * Targets both dynamic clock network power and combinational logic switching.
  * Achieved the **best overall PPA metrics across the entire study**.

---

## 3. Comprehensive Post-Synthesis PPA Benchmark

All six variants were synthesized using **Cadence Genus 21.1** targeting the **`slow_vdd1v0.lib`** standard-cell library (slow corner, 1.0 V supply) under a 100 MHz clock constraint (10.0 ns period, 0.10 ns uncertainty).

| Variant | Architecture Description | Cell Count | $\Delta$ Cells | Area ($\mu\text{m}^2$) | $\Delta$ Area | Leakage ($\mu\text{W}$) | Internal ($\mu\text{W}$) | Switching ($\mu\text{W}$) | Total Power ($\mu\text{W}$) | $\Delta$ Total Power | Status |
|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **V1** | Baseline BIST (Reference) | 1185 | 0.0% | 9926.74 | 0.0% | 42.732 | 612.542 | 229.083 | 884.357 | 0.0% | Reference |
| **V2** | Clock Gating (ICG) | 1095 | -7.6% | 9508.18 | -4.2% | 41.658 | 581.265 | 219.826 | 842.749 | **-4.7%** | Optimized |
| **V3** | Operand Isolation (OI) | 1217 | +2.7% | 10078.88 | +1.5% | 43.681 | 583.573 | 206.999 | 834.253 | **-5.7%** | Optimized |
| **V4** | Bus Inversion (BI)* | 1516 | +27.9% | 12354.88 | +24.5% | 56.118 | 872.138 | 381.808 | 1310.060 | +48.1% | Excluded* |
| **V5** | Combined All (CG+OI+BI)* | 1466 | +23.7% | 11979.46 | +20.7% | 55.524 | 813.638 | 349.995 | 1219.160 | +37.9% | Excluded* |
| **V6** | **Combined OI + CG (Best)** | **1127** | **-4.9%** | **9660.32** | **-2.7%** | **42.583** | **553.775** | **198.634** | **794.993** | **-10.1%** | **Optimal** |

*\*Note: Variants 4 and 5 are reported for academic completeness to document the limits of bus-invert coding on localized on-chip interconnects.*

### Key Engineering Takeaways:
1. **Linear Superposition of Benefits**: The individual power reductions of V2 ($41.61\ \mu\text{W}$) and V3 ($50.10\ \mu\text{W}$) sum to $91.71\ \mu\text{W}$. When implemented together in V6, the measured power reduction was $89.36\ \mu\text{W}$ (-10.1%), demonstrating near-perfect orthogonal action between clock gating (sequential clock tree) and operand isolation (combinational multiplier tree).
2. **Switching Power Dominance**: V6 achieved a **-13.3% reduction in dynamic switching power** ($198.634\ \mu\text{W}$ vs $229.083\ \mu\text{W}$), proving the efficacy of operand isolation in suppressing unobserved transitions.
3. **Area Efficiency**: Although operand isolation adds gating logic (+32 AND gates), combining it with clock gating yields an overall **2.7% area reduction** and **4.9% cell count reduction** because Genus optimizes away redundant enable logic across the gated registers.
