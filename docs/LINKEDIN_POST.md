# LinkedIn Presentation & Portfolio Assets

---

## 1. Primary LinkedIn Technical Announcement

**Hook & Technical Problem:**
During production wafer and package test, pseudo-random stimuli applied to digital datapaths typically exhibit near-50% toggle rates across every cycle—often generating 2× to 4× the switching power of normal functional operation. For deeply embedded arithmetic blocks like Multiply-Accumulate (MAC) units, this test-mode power surge can trigger excessive IR drop, resulting in false test failures or severe thermal degradation.

**The Project:**
To analyze the trade-offs between test coverage, area overhead, and power dissipation, I implemented and evaluated a complete **Built-In Self-Test (BIST) architecture for a 16-bit unsigned MAC unit** using standard synthesizable Verilog (IEEE 1364-2001), Cadence Genus 21.1, and Cadence Incisive.

**Key Architecture & Implementation:**
- **Circuit Under Test (CUT)**: 16×16 unsigned multiplier with a 40-bit accumulator (32-bit product + 8 guard bits). The per-cycle product is directly tapped for compaction to prevent early-cycle arithmetic fault masking.
- **Test Pattern Generator (TPG)**: Dual 16-bit Fibonacci LFSRs with independent primitive polynomials (`0xD008` and `0xB400`), generating maximal-length pseudo-random vectors ($2^{16} - 1 = 65,535$ states).
- **Output Response Analyzer (ORA)**: 32-bit Galois MISR (`x³² + x²² + x² + x + 1`), providing an aliasing probability of $P_{\text{alias}} \approx 2^{-32} \approx 2.33 \times 10^{-10}$.
- **BIST Controller**: 5/7-state one-hot FSM orchestrating seed loading, test execution, signature capture, and pass/fail evaluation.

**Measured Fault Coverage & PPA Results:**
- **99.8980% Stuck-At Fault Coverage**: Evaluated via gate-level fault injection across 980 net sites (1960 single stuck-at faults) on the post-synthesis netlist. Coverage converged to 99.898% at 128 patterns and remained stable through 4096 cycles.
- **Root Cause of Undetected Faults**: Exactly 2 control-input faults (`SA1 en` and `SA0 clr`) were undetected due to controller signal scheduling, which I analyzed and documented in the repository.
- **Low-Power Architectural Comparisons** (synthesized under 100 MHz, 1.0 V slow corner in Cadence Genus 21.1):
  - **Clock Gating (ICG)**: -4.7% total power, -4.2% area, -7.6% cells.
  - **Operand Isolation (OI)**: -5.7% total power (-9.6% switching power), +1.5% area.
  - **Combined OI + CG (V6)**: **-10.1% total power**, **-2.7% area**, **-4.9% cells** (the best-performing configuration).
  - **Bus Inversion Coding**: Increased power (+48.1%) due to encoder/decoder overhead on short on-chip buses—a valuable negative result confirming theoretical expectations!

Check out the full open-source RTL codebase, testbenches, synthesis constraints, gate netlist reports, and the complete research paper on GitHub:
👉 https://github.com/ALLENJOE-A/Low-Power-MAC-BIST-PPA-Fault-Coverage

#VLSI #ASICDesign #DFT #DigitalDesign #Verilog #BIST #EDA #CadenceGenus #Semiconductor #HardwareEngineering

---

## 2. Short LinkedIn Project Description (for Profile "Featured" or "Projects" Section)

**Low-Power MAC BIST: Architecture, PPA & Fault Coverage Analysis**
* Implemented a synthesizable 16-bit MAC Built-In Self-Test (BIST) architecture in Verilog-2001 featuring dual Fibonacci LFSRs, a 32-bit Galois MISR ($P_{\text{alias}} \approx 2.33 \times 10^{-10}$), and a one-hot FSM controller.
* Synthesized 6 architectural variants in Cadence Genus 21.1 (100 MHz, 1.0 V slow corner), demonstrating that combining latch-based clock gating with operand isolation achieved a 10.1% total power reduction, 13.3% switching power reduction, and 2.7% area savings.
* Conducted gate-level stuck-at fault injection on 980 net sites (1960 faults) in Cadence Incisive, achieving 99.8980% fault coverage with comprehensive root-cause analysis of undetected control faults.

---

## 3. One-Line Resume Bullet Points

- **Option A (DFT / Verification focus)**:
  > Designed a synthesizable 16-bit MAC BIST in Verilog-2001; verified 99.8980% stuck-at fault coverage across 1960 net sites via gate-level fault simulation in Cadence Incisive and analyzed control-masking mechanisms.

- **Option B (ASIC / Low-Power PPA focus)**:
  > Evaluated 6 architectural variants of a BIST-enabled 16-bit MAC in Cadence Genus 21.1 (100 MHz), achieving a 10.1% power and 2.7% area reduction by integrating operand isolation with integrated clock gating.

- **Option C (Comprehensive)**:
  > Architected a low-power 16-bit MAC BIST (dual LFSRs, 32-bit MISR, FSM); achieved 99.8980% fault coverage and cut test power by 10.1% via operand isolation and clock gating in Cadence Genus 21.1.

---

## 4. Suggested Order for LinkedIn Carousel Images

1. **Slide 1 (Cover / Hero)**: Architecture Diagram (`figures/architecture/mac_bist_architecture.svg` or `.png`).
2. **Slide 2 (Synthesis Schematic)**: Cadence Genus 21.1 gate-level synthesized schematic (`figures/schematics/mac_16_genus_schematic.jpeg`).
3. **Slide 3 (PPA Benchmark Table)**: Post-synthesis power, area, and cell count comparison (`figures/results/ppa_comparison_table.png`).
4. **Slide 4 (Fault Coverage Evidence)**: Cumulative fault coverage progression table reaching 99.8980% (`figures/results/fault_coverage_summary.png`).
5. **Slide 5 (Cadence Terminal Execution)**: Live terminal screenshot of the fault simulation campaign across 1960 stuck-at faults (`figures/results/fault_sim_final_summary.png`).
6. **Slide 6 (RTL Block Level Schematics)**: SimVision architectural block diagram showing LFSR, MAC, MISR, and Comparator interconnects (`figures/schematics/full_bist_schematic.png`).
7. **Slide 7 (Undetected Faults & Engineering Recommendations)**: Screenshot of undetected faults log (`figures/results/undetected_faults_log.png`) with annotations explaining test-schedule masking.

---

## 5. Curated Technical Evidence Screenshots

| Asset Name | Relative Path | Key Metric / Value Shown |
|:---|:---|:---|
| **Architecture Diagram** | `figures/architecture/mac_bist_architecture.svg` | Full BIST block interconnect, polynomials, state flow |
| **Genus 21.1 Schematic** | `figures/schematics/mac_16_genus_schematic.jpeg` | Gate-level mapped netlist (819 leaf cells, 977 nets) |
| **SimVision RTL Schematic**| `figures/schematics/full_bist_schematic.png` | Complete RTL connectivity (TPG -> MAC -> MISR -> Comparator) |
| **PPA Comparison Table** | `figures/results/ppa_comparison_table.png` | Verifiable metrics: V1 to V5 area, leakage, switching, and total power |
| **Fault Coverage Curve** | `figures/results/fault_coverage_summary.png` | 99.5918% (32 patterns) -> 99.8980% (4096 patterns) |
| **Terminal Execution** | `figures/results/fault_sim_final_summary.png` | Exact command run on `cad312vitcc.vit.ac.in` server |
| **Undetected Fault Log** | `figures/results/undetected_faults_log.png` | Identification of `SA1 en` and `SA0 clr` |
