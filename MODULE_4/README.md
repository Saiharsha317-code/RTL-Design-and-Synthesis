# RTL Design, Synthesis & Gate Level Simulation (GLS) — Learning Notes

These are my day-wise notes from the VSD (VLSI System Design) workshop, covering RTL-to-GLS flow: writing Verilog, understanding blocking vs non-blocking assignments, invoking Gate Level Simulation using Yosys + Icarus Verilog, and debugging synthesis-simulation mismatches using GTKWave.

---
## Overview

This repository walks through the concept of **Gate Level Simulation (GLS)** — why it's needed, how it's different from RTL simulation, and how it's actually run using the Yosys + Icarus Verilog + GTKWave toolchain on the Sky130 standard cell library. Along the way, it covers the **blocking vs non-blocking** assignment rules in Verilog, since misusing them is one of the most common causes of a **synthesis-simulation mismatch**. Two worked examples are included:

- A **blocking-caveat design**, showing how a careless blocking assignment creates a mismatch between RTL and gate-level behavior.
- A **counter design** (`counter_opt` → `good_counter`), showing the synthesized gate-level structure before and after the fix, along with the waveforms that confirm correct behavior.

All schematics are Yosys `show` outputs, and all waveforms are captured in GTKWave, targeting the `sky130_fd_sc_hd` standard cell library.

## Table of Contents

1. [Introduction to Gate Level Simulation (GLS) and Synthesis-Simulation Mismatches](#1-introduction-to-gate-level-simulation-gls-and-synthesis-simulation-mismatches)
2. [Blocking vs Non-Blocking Statements in Verilog](#2-blocking-vs-non-blocking-statements-in-verilog)
3. [Non-Blocking for Sequential Circuits & How to Invoke GLS](#3-non-blocking-for-sequential-circuits--how-to-invoke-gls)
4. [Running GLS with Icarus Verilog](#4-running-gls-with-icarus-verilog)
5. [Case Study 1 — The "Blocking Caveat" Design](#5-case-study-1--the-blocking-caveat-design)
6. [Case Study 2 — Counter Designs (`counter_opt` and `good_counter`)](#6-case-study-2--counter-designs-counter_opt-and-good_counter)
7. [Summary](#summary)

---


## 1. Introduction to Gate Level Simulation (GLS) and Synthesis-Simulation Mismatches

Gate Level Simulation means running the same testbench, but this time the **Design Under Test (DUT)** is not the RTL code — it is the synthesized **netlist**. Since the netlist is logically equivalent to the RTL code, the same testbench can be reused without any modification, and its outputs should ideally match the RTL simulation.

**Why do we need GLS?**
- To verify the logical correctness of the design *after* synthesis — making sure the tool's output still behaves the way the RTL intended.
- To ensure the timing of the design is met. For this, GLS has to be run with delay annotation (SDF back-annotation), which is a separate, more advanced topic and outside the scope of these notes.

So GLS broadly splits into two flavors:
- **GLS (Timing Aware)** → checks both functionality *and* timing.
- **GLS (Functional)** → checks only functionality, no timing information involved.

**Synthesis-Simulation mismatches** happen when the RTL simulation and the gate-level simulation disagree, even though both are supposed to represent the same design. The three common causes are:
1. **Missing sensitivity list** — an `always` block that doesn't list all the signals it depends on, so the RTL simulator doesn't re-evaluate the block when it should, while the synthesized hardware naturally reacts to every input change.
2. **Blocking vs Non-Blocking assignments** — using the wrong assignment type inside sequential logic can create simulation mismatches, discussed in detail below.
3. **Non-standard Verilog coding** — writing code in a style that synthesis tools interpret differently from how simulators execute it.

![Introduction to GLS and Synthesis-Simulation Mismatches]<img width="1201" height="1600" alt="WhatsApp Image 2026-08-22 at 21 12 31" src="https://github.com/user-attachments/assets/1fea5626-f94e-468f-9db1-94ac90ec2dd2" />


---

## 2. Blocking vs Non-Blocking Statements in Verilog

Both statement types are used **inside an `always` block**, but they behave very differently.

### Blocking (`=`)
- Executes statements strictly in the order they are written — the first statement is fully evaluated and completed before the second one starts.
- This is conceptually similar to how a C program executes line by line.

### Non-Blocking (`<=`)
- Evaluates **all the RHS expressions in parallel** the moment the `always` block is entered, and only *then* assigns them to their respective LHS variables.
- Because all right-hand sides are computed first (using the old values) and assigned together, this is well suited for describing sequential logic (flip-flops) that update simultaneously on a clock edge.

Example comparing the two:

```verilog
// Blocking - sequential order matters
always @(posedge clk) begin
  a = b'100;
  c = e_f;
end

// Non-blocking - parallel evaluation
always @(posedge clk) begin
  a <= b'100;
  c <= e_f;
end
```

### Caveats with Blocking Statements

**Case 1:**
```verilog
q  = q0;
q0 = d;
```
Here, `q` is assigned the *old* value of `q0` first, and only after that is `q0` updated with `d`. This ordering leads to only one effective flip-flop's worth of behavior, even though the intent might have been two separate flip-flops.

**Case 2:**
```verilog
q0 = d;
q  = q0;
```
Here, `q0` is updated with `d` first. Then `q` is assigned `q0`'s new value in the same step — which collapses two flip-flops into what behaves like a single flip-flop (a race/ordering-dependent problem).

This is exactly the kind of ordering-dependence that can cause a **mismatch** between RTL simulation and gate-level simulation, since synthesis tools infer hardware structurally, not by "line order."

![Blocking vs Non-Blocking statements in Verilog]<img width="1201" height="1600" alt="4564" src="https://github.com/user-attachments/assets/1b8b2d13-4946-4718-b679-1261ed85bde1" />


---

## 3. Non-Blocking for Sequential Circuits & How to Invoke GLS

**Rule of thumb:** use non-blocking assignments (`<=`) when writing sequential circuits, so that all flip-flops update in parallel exactly as real hardware would.

```verilog
q0 <= 1'b0;
q  <= 1'b0;

q0 <= d;
q  <= q0;   // both RHS values are evaluated first,
            // then assigned to their respective variables
```

### Ternary Operator as a MUX

A 2:1 mux can be written compactly using Verilog's ternary operator:

```verilog
sel ? i1 : i0;
// <condition> ? <true-case> : <false-case>
```
with `i0`, `i1` as data inputs, `sel` as the select line, and `y` as the output.

### How to Invoke GLS (Yosys synthesis flow)

Once the RTL waveform is verified to be correct, the design is synthesized with **Yosys**, and *then* GLS is run on the resulting netlist. The Yosys flow:

1. `read_liberty -lib ../lib/sky130_fd_sc_hd__tt_025C_1v80.lib`
2. `read_verilog <filename>.v`
3. `synth -top <filename>`
4. `abc -liberty ../lib/sky130_fd_sc_hd__tt_025C_1v80.lib`
5. `write_verilog -noattr <filename>_net.v`
6. `show`

![Non-blocking for sequential circuits and How to invoke GLS]<img width="1201" height="1600" alt="4564654" src="https://github.com/user-attachments/assets/e2696103-1017-4711-97b7-fadc8c4bc212" />


---

## 4. Running GLS with Icarus Verilog

After the netlist (`*_net.v`) is generated by Yosys, GLS is run with `iverilog`, but this time the primitive/standard-cell models for the target library also need to be included, along with the gate-level netlist and the same testbench used for RTL simulation:

```bash
iverilog ../my-lib/verilog-model/primitives.v \
         ../my-lib/verilog-model/sky130_fd_sc_hd.v \
         ternary_operator_mux_net.v \
         tb_ternary_operator_mux.v

./a.out

gtkwave tb_ternary_operator_mux.vcd
```

**How do we know a simulation is a Gate Level Simulation and not an RTL simulation?**
In the RTL simulation, the design hierarchy under the `uut` (unit under test) doesn't contain any low-level instance names like `g6`, `g7`, etc. But in the Gate Level Simulation, the `uut` hierarchy is expanded into individual standard-cell instances (e.g. `g6`, `g7`) — because we are now simulating the actual synthesized gates instead of the behavioral RTL description.

**Key takeaway:** When GLS is run correctly, any synthesis-simulation mismatch that exists between the RTL and the gate-level netlist gets exposed and can be corrected — that's the whole point of doing GLS.

![iverilog commands to run GLS and how to identify a gate-level simulation]<img width="1201" height="1600" alt="45455" src="https://github.com/user-attachments/assets/be884a8c-9b39-43eb-9774-ca78d8092d7b" />


---

## 5. Case Study 1 — The "Blocking Caveat" Design

This example demonstrates how using blocking assignments carelessly inside sequential-looking logic causes a mismatch between RTL and gate-level behavior.

### Synthesized Schematic
The design synthesizes down to a single `sky130_fd_sc_hd__o21a_1` standard cell (an AND-OR-Invert style cell) with inputs `a`, `b`, `c` and output `d`.

![Synthesized schematic of the blocking_caveat design]<img width="612" height="394" alt="05_blocking_caveat_schematic" src="https://github.com/user-attachments/assets/65189d1f-9946-499c-a21a-9a62758163e9" />


### RTL Simulation Waveform
Running the testbench against the RTL code first, to establish the "expected" behavior of signals `a`, `b`, `c`, and `d`.

![RTL simulation waveform of blocking_caveat]<img width="948" height="629" alt="06_blocking_caveat_waveform_rtl" src="https://github.com/user-attachments/assets/fbd249cf-7c46-42ff-9d20-f0ddef331df0" />


### Gate Level Simulation Waveform
Running the *same* testbench against the synthesized netlist. Here the signals `a`, `b`, `c` (as wires) and `x`, `d` (as regs) are compared against the RTL run — this is where any blocking-assignment-induced mismatch would show up.

![Gate level simulation waveform of blocking_caveat]<img width="1147" height="634" alt="07_blocking_caveat_waveform_gls" src="https://github.com/user-attachments/assets/275392bf-572d-47f6-985c-a1f0bb2e5369" />


---

## 6. Case Study 2 — Counter Designs (`counter_opt` and `good_counter`)

### `counter_opt` — Ternary-based Counter (Optimized View)
A simpler synthesized view of the ternary-operator-based counter, mapped to `sky130_fd_sc_hd__dfrtp_1` (D flip-flop with reset) and `sky130_fd_sc_hd__clkinv_1` (clock inverter) cells.

![counter_opt schematic - simplified/optimized view]<img width="956" height="271" alt="08_counter_opt_schematic_simple" src="https://github.com/user-attachments/assets/42fbfc86-2da6-46a3-b114-9bc58d62a1f5" />


### `counter_opt` — Detailed Gate Mapping
A more detailed view of the same `counter_opt` design after synthesis, showing the additional combinational cells (`xor2`, `nand2`, `mux`, `clkinv`) that make up the counting and comparator logic.

![counter_opt schematic - detailed gate-level mapping]<img width="957" height="339" alt="09_counter_opt_schematic_detailed" src="https://github.com/user-attachments/assets/e7a2ba19-727b-40a7-a8c4-008948fc44e2" />


### `good_counter` — Corrected Counter Design
The `good_counter` design, written using non-blocking assignments correctly, synthesizes cleanly into two `_DFF_PP0_` flip-flops with `nor2`/`nor2b` combinational logic driving the next-state `cnt` value — a clean, mismatch-free structure.

![good_counter gate-level schematic]<img width="1151" height="610" alt="10_good_counter_schematic" src="https://github.com/user-attachments/assets/d5a612e3-01e1-4f73-938c-97ff76fcccdc" />


### `good_counter` Waveform
GTKWave output of `tb_good_counter`, showing `clk`, `cnt[1:0]`, `comp`, and `reset` toggling correctly across the count sequence (00 → 01 → 10 → 00 ...).

![good_counter waveform]<img width="1147" height="588" alt="11_good_counter_waveform" src="https://github.com/user-attachments/assets/ddff5398-e1eb-4c1f-bbf4-3e9776f0a865" />


### `good_counter` Waveform — Zoomed In
A zoomed-in view around the 1500–1600 ns window, confirming the counter increments correctly on every clock edge once `reset` is de-asserted.

![good_counter waveform zoomed]<img width="1150" height="452" alt="12_good_counter_waveform_zoomed" src="https://github.com/user-attachments/assets/c83edc2e-bb6f-4196-a781-8a0ff1bb0e70" />


---

## Summary

- GLS reuses the RTL testbench against the synthesized netlist to catch synthesis-simulation mismatches.
- Functional GLS checks logic only; timing-aware GLS (with delay annotation) additionally checks timing — not covered here.
- The three big causes of mismatches: missing sensitivity lists, blocking vs non-blocking misuse, and non-standard Verilog coding.
- Always prefer non-blocking (`<=`) assignments for sequential (clocked) logic to avoid ordering-dependent bugs.
- Yosys (`read_liberty` → `read_verilog` → `synth -top` → `abc -liberty` → `write_verilog -noattr` → `show`) is used to generate the gate-level netlist, and `iverilog` + the standard-cell primitive models are used to actually run GLS.
