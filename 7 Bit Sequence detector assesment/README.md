# Sequence Detector – RTL to Gate-Level Simulation

## Overview

This repository documents the complete RTL-to-Gate-Level Simulation flow of a Verilog sequence detector for the target sequence **0000110**.

The same testbench and input sequence are used for both RTL simulation and Gate-Level Simulation (GLS). The comparison shows that the synthesized implementation preserves the functional behavior of the RTL design, with **6 detections** in both simulations and the first detection occurring at **357 ns**.

## Design Flow

```text
RTL
 ↓
RTL Simulation (Icarus Verilog)
 ↓
GTKWave
 ↓
Yosys Synthesis (SKY130 std-cell library)
 ↓
sequence_detector_net.v / Synthesized Netlist
 ↓
Post-synthesis Gate-Level Simulation (GLS)
 ↓
GTKWave
 ↓
Same Functional Behavior
```

---

## 1. RTL Design

The sequence detector is implemented as a finite state machine using a 3-bit state register.

- **Target sequence:** `0000110`
- **Number of states:** 7 (S0–S6)
- **State width:** 3 bits
- **Input:** `din`
- **Output:** `detected`
- **Reset:** synchronous, active high
- **Detection:** `detected` is registered — computed combinationally from the current state and `din`, then latched on the next posedge, so it lags the completing bit by one clock cycle
- **Overlap handling:** on a successful match (state 6, `din=0`), the FSM returns to state 1 rather than state 0, since the trailing `0` is itself a valid 1-bit prefix of the next possible match. State 4 also self-loops on repeated `0`s so runs of leading zeros longer than the pattern don't break the match.

---

## 2. Testbench

The testbench generates the clock, applies reset, drives the 180-bit input sequence bit-by-bit via a `drive_bit` task, records detection pulses in `detection_count`, and prints the final count.

### Important Testbench Parameters

| Parameter | Value |
|---|---|
| Clock | `#7 clk = ~clk` (period = 14 ns, ~71.4 MHz) |
| Target sequence | `0000110` |
| Reset | Active high, held 2 clock cycles, released at t = 28 ns |
| Testbench style | Same input sequence for RTL and GLS |
| Assessment instance | `24eg104c46` |
| Detection count observed | `6` |

> The complete, un-truncated testbench (all 180 `drive_bit` calls) is checked in at [`tb.v`]

---

## 3. Pre-Synthesis / RTL Simulation

The RTL testbench was compiled and simulated with Icarus Verilog, and the generated VCD waveform was viewed in GTKWave.

```bash
iverilog sequence_detector.v tb.v
./a.out
gtkwave dump.vcd
```

The waveform shows:

- `clk` running continuously at a 14 ns period.
- `reset` asserted initially for 2 cycles, released at 28 ns, and asserted again at the end.
- `din` changing according to the testbench sequence.
- `state[2:0]` and `next_state[2:0]` stepping through the FSM (S0→S1→S2→S3→S4→S5→S6).
- `detected` pulsing when the target sequence `0000110` is recognized.
- `detection_count` reaching **6**.

### RTL GTKWave Evidence

![RTL Simulation]<img width="1920" height="983" alt="simulational" src="https://github.com/user-attachments/assets/393952ca-685a-484c-be7e-e54d56a90730" />
<img width="1920" height="983" alt="functional_simulation" src="https://github.com/user-attachments/assets/3825094e-74ea-488e-95d7-920fe4567040" />


The waveform shows `clk`, `NUM_STATES`, `STATE_W`, `state[2:0]`, `din`, and `detected` cycling through the FSM repeatedly across the full 180-bit stream, with `detected` pulsing high briefly at each of the 6 matches.

---

## 4. Yosys Synthesis

Yosys was used to read and synthesize the RTL into a gate-level representation, mapped onto the SKY130 `sky130_fd_sc_hd` standard-cell library.

```tcl
read_liberty -lib ../../lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog sequence_detector.v
synth -top sequence_detector
dfflibmap -liberty ../../lib/sky130_fd_sc_hd__tt_025C_1v80.lib
abc -liberty ../../lib/sky130_fd_sc_hd__tt_025C_1v80.lib
show
stat
write_verilog sequence_detector_net.v
```

### Pre-ABC (generic cells) — after `synth`

| Item | Count |
|---|---:|
| Wires | 24 |
| Wire bits | 30 |
| Ports | 4 |
| Port bits | 4 |
| Cells | 27 |

`$_ANDNOT_`×6, `$_AND_`×2, `$_DFF_P_`×7, `$_NOR_`×3, `$_NOT_`×1, `$_ORNOT_`×2, `$_OR_`×5, `$_SDFF_PP0_`×1

### Post-ABC (SKY130 mapped cells) — final synthesized design statistics

| Item | Count |
|---|---:|
| Wires | 45 |
| Wire bits | 51 |
| Public wires | 5 |
| Public wire bits | 11 |
| Ports | 4 |
| Port bits | 4 |
| Memories | 0 |
| Memory bits | 0 |
| Processes | 0 |
| Cells | 20 |

### Cell Breakdown

| Cell | Count |
|---|---:|
| `$_DFF_P_` | 7 |
| `$_SDFF_PP0_` | 1 |
| `sky130_fd_sc_hd__a21oi_1` | 1 |
| `sky130_fd_sc_hd__and2_0` | 2 |
| `sky130_fd_sc_hd__clkinv_1` | 1 |
| `sky130_fd_sc_hd__nand2b_1` | 1 |
| `sky130_fd_sc_hd__nor2_1` | 2 |
| `sky130_fd_sc_hd__nor3b_1` | 2 |
| `sky130_fd_sc_hd__nor4_1` | 1 |
| `sky130_fd_sc_hd__o21a_1` | 1 |
| `sky130_fd_sc_hd__o31a_1` | 1 |
| **Total** | **20** |

> The two stat snapshots above are not a discrepancy — they're the same flow at two points: generic technology-independent cells right after `synth`, and SKY130 standard cells after `abc -liberty` maps them. Cell *count* drops (27→20) because ABC folds generic boolean ops into fewer, denser standard cells; flop count (7× `$_DFF_P_` + 1× `$_SDFF_PP0_` = 8 total) is preserved across both.

### Yosys Statistics Evidence

![Yosys stat]<img width="1920" height="983" alt="stat" src="https://github.com/user-attachments/assets/58eddcbc-5242-4854-a8b6-d0a2652bfee7" />


The screenshot shows the synthesized `sequence_detector` module: **7 flip-flops** for the 3-bit state register plus **1 special reset-capable flop** (`$_SDFF_PP0_`) for the registered `detected` output, and **12 combinational SKY130 cells** implementing the next-state and detection logic.

---

## 5. Synthesized Netlist / Logic Representation

After synthesis, the RTL is represented using SKY130 flip-flops and combinational logic cells.

The generated logic diagram (via Yosys `show`) shows:

- `din`, `reset`, and `clk` fanning into a cluster of gate-level logic.
- `nor2_1`, `nor3b_1`, `nor4_1`, `and2_0`, `nand2b_1`, `a21oi_1`, `o21a_1`, and `o31a_1` cells implementing the combinational next-state and detection equations.
- A bank of `$_DFF_P_` flops for the state bits, plus the `$_SDFF_PP0_` flop driving `detected`.
- Clock and reset connectivity fanning across the whole register bank.

### Synthesized Logic Diagram

![Synthesized netlist]<img width="1920" height="983" alt="SYNTHESIS1" src="https://github.com/user-attachments/assets/34ec278a-d647-4467-9a8e-1928f8765d91" />


Note that the synthesized `state` register shows up as **7 bits wide** in the GLS waveform rather than the 3 bits declared in the RTL (`STATE_W = 3`) — Yosys chose a one-hot-style re-encoding during synthesis instead of keeping the binary encoding from the source. This does not change functional behavior; it's purely a different physical state encoding chosen at synthesis time, and it is **not** a valid point of comparison against the RTL sim's `state[2:0]` — only `din` in / `detected` out are.

---

## 6. Post-Synthesis Gate-Level Simulation (GLS)

The synthesized netlist was simulated with the same testbench and input sequence used for RTL simulation, using the SKY130 primitive and standard-cell Verilog models.

```bash
iverilog primitives.v sky130_fd_sc_hd.v sequence_detector_net.v tb.v
./a.out
gtkwave dump.vcd
```

### GLS Evidence

![GLS waveform]<img width="1920" height="983" alt="gls" src="https://github.com/user-attachments/assets/59f5c45a-0232-439d-954e-9d5092c40607" />

The GLS run produced the same `TIME=... DIN=... DETECTED=...` console trace as the RTL simulation, and the same `detected` pulse behavior on the waveform — the only visible difference is the internal `state` signal being one-hot (values like 64, 32, 16, 8, 4, 2, 1) instead of the RTL's 3-bit binary encoding.

---

## 7. RTL vs GLS Comparison

The comparison is based on the same testbench and the same input sequence.

| Parameter | RTL Simulation | GLS Simulation |
|---|---|---|
| Target sequence | `0000110` | `0000110` |
| Functional detection | correct | correct |
| Number of detections | 6 | 6 |
| Timing | Ideal functional timing | Includes gate delays |
| Overall behavior | same | same |
| First detection | 357 ns | 357 ns |

Both simulations detect the target sequence `0000110`, with the detection count reaching **6** in both cases and the first detection landing at the same timestamp. RTL timing is ideal/zero-delay functional timing; GLS reflects the same logical events but is offset by gate-level propagation delays through the standard-cell logic.

### Full Detection Timing Table (matches in both RTL and GLS)

| Detection # | `drive_bit` call # | Time (ns) |
|---|---|---|
| 1 | 23  | 357  |
| 2 | 49  | 721  |
| 3 | 80  | 1155 |
| 4 | 127 | 1813 |
| 5 | 145 | 2065 |
| 6 | 169 | 2401 |

---

## 8. Functional Verification

```text
Input sequence
      ↓
Sequence detector FSM
      ↓
Target = 0000110
      ↓
Detection pulses
      ↓
6 successful detections
      ↓
RTL result = GLS result
```

The GTKWave results show matching logical behavior between the RTL and gate-level simulations. The synthesized implementation therefore preserves the intended sequence-detection functionality for the given testbench.

---

## 9. Final Conclusion

The synthesized implementation preserves the functional behavior of the RTL for the given testbench. The RTL and GLS simulations detect the same target sequence, with the only difference being a small timing delay in GLS due to gate-level propagation delays.

So the synthesized design is functionally equivalent to the RTL for the given testbench. The GLS verifies the synthesis, confirming the required FSM operation and sequence-detection functionality is preserved, with only timing differences due to gate delays.

Internal state encoding differs (3-bit binary in RTL vs. one-hot post-synthesis) — this is an implementation detail introduced by synthesis, not a functional mismatch (see §5).

---

## 10. Result

```text
Target sequence        : 0000110
RTL detections         : 6
GLS detections         : 6
RTL first detection    : 357 ns
GLS first detection    : 357 ns
Functional match       : YES
```

## 11. What more could be done

- Run a formal equivalence check (e.g. Yosys `equiv_induct`/`equiv_make`) between the pre- and post-synthesis netlists instead of relying only on simulation vectors.
- Re-run GLS with SDF back-annotated timing (zero-delay GLS, as done here, doesn't catch setup/hold violations or synthesis-introduced timing hazards).
- Add self-checking assertions (SVA or a simple Verilog checker) comparing `detected` against an RTL golden model in the same testbench, instead of eyeballing waveforms.
- Extend the stimulus with directed edge cases: back-to-back overlapping matches, an all-zero run longer than the pattern, and toggling `reset` mid-sequence, to stress the state-4 self-loop and state-6→state-1 fallback transitions specifically.
