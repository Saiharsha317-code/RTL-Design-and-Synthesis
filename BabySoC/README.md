# VSDIAT Co-Training – Baby SoC Design and Verification

Documentation of a two-day **VSDIAT co-training program** conducted at **Anurag University** for EC/EEE third-year students, covering the design and verification flow of the **VSDBabySoC** architecture — from specification through RTL, functional simulation, synthesis, and gate-level simulation (GLS).

This repository documents what was actually performed during the training: the tools used, the commands run, the waveforms observed, the problems encountered during GLS, and how they were debugged and resolved.

> **Status:** Physical design, verification, and fabrication stages were **not** part of this training and are planned for future sessions (see [Current Status](#current-status)).

---

## Table of Contents

1. [Overview](#overview)
2. [Design Flow](#design-flow)
3. [Tools and Technologies](#tools-and-technologies)
4. [Stage 1 – Git and Required Libraries](#stage-1--git-and-required-libraries)
5. [Stage 2 – Specification Analysis](#stage-2--specification-analysis)
6. [Stage 3 – RTL Design](#stage-3--rtl-design)
7. [Stage 4 – Functional Simulation](#stage-4--functional-simulation)
8. [Stage 5 – Synthesis](#stage-5--synthesis)
9. [Stage 6 – Gate-Level Simulation (GLS)](#stage-6--gate-level-simulation-gls)
10. [Stage 7 – GLS Problem and Debugging](#stage-7--gls-problem-and-debugging)
11. [Stage 8 – RTL vs GLS Comparison](#stage-8--rtl-vs-gls-comparison)
12. [Scripts](#scripts)
13. [Current Status](#current-status)
14. [Repository Structure](#repository-structure)
15. [Conclusion](#conclusion)

---

## Overview

VSDBabySoC is a small RISC-V-based SoC built around the **rvmyth** processor core, along with an analog PLL (`avsdpll`) and DAC (`avsddac`), connected through defined 1.8V and 3.3V voltage domains. The training was carried out in a VSDIAT-provided Linux environment (`vsduser@vsdsquadron`) with Yosys, Icarus Verilog, GTKWave, and Git available.

During the co-training, we cloned the required simulation repository and libraries, reviewed the BabySoC specification, worked with the provided RTL and testbench, ran functional (RTL-level) simulation, synthesized the design using Yosys with the Sky130 standard cell library, ran gate-level simulation on the synthesized netlist, debugged a waveform mismatch we hit during GLS, and finally verified that the synthesized design's behavior matched the RTL-level functional simulation.

## Design Flow

Per the training's own stage plan:

```
Stage 1: Specification
    ↓
Stage 2: RTL Design + Functional Simulation
    ↓
Stage 3: Synthesis + Gate-Level Simulation
    ↓
Stage 4: Physical Design            (future)
    ↓
Stage 5: Verification               (future)
    ↓
Stage 6: Fabrication                (future)
```

This repository documents Stages 1–3 in detail (broken out further below into 8 documented stages). Stages 4–6 are pending future work — see [Current Status](#current-status).

## Tools and Technologies

Based on the commands actually used during the training:

| Tool | Purpose |
|---|---|
| **Yosys** | RTL synthesis (`read_verilog`, `read_liberty`, `synth`, `abc`, `write_verilog`) |
| **Icarus Verilog (`iverilog`)** | Compiling RTL/gate-level testbenches for simulation |
| **VVP** | Executing the compiled simulation output (`vvp`) |
| **GTKWave** | Viewing and comparing `.vcd` waveform dumps |
| **Sky130 PDK** | Standard cell liberty/Verilog models (`sky130_fd_sc_hd__tt_025C_1v80.lib`, `sky130_fd_sc_hd.v`) used for synthesis and GLS |
| **Git / GitHub** | Cloning the BabySoC simulation repository |

*(Tool version numbers were not captured in the available terminal screenshots and are therefore not claimed here.)*

---

## Stage 1 – Git and Required Libraries

A dedicated project folder was created and the BabySoC simulation repository was cloned into it:

```bash
mkdir baby_soc
cd baby_soc/
git clone https://github.com/Subhasis-Sahu/BabySoC_Simulation
cd BabySoC_Simulation
```

![Git clone setup](01-git-and-libraries/git-clone-setup.png)

This repository contains the BabySoC RTL sources (`src/module/`), include files (`src/include/`), and the Sky130/analog IP liberty and Verilog models (`src/lib/`) used in later synthesis and GLS stages.

## Stage 2 – Specification Analysis

Before RTL work began, we reviewed the VSDBabySoC architecture diagram to understand the design's structure:

![VSDBabySoC architecture](02-specifications/vsdbabysoc-architecture.png)

Key points identified from the specification:

- The design integrates a digital core (**rvmyth**, a RISC-V based processor), an analog **PLL** (`avsdpll_1v8`) and an analog **DAC** (`avsddac_3v3`).
- Two voltage domains are defined: **1.8V** (digital core, PLL/DAC control signals) and **3.3V** (SPI, crystal oscillator pad, DAC output side), connected through level shifters (`LS`).
- The **rvmyth** core outputs a 10-bit value (`D[9:0]`) which drives the DAC (`avsddac_3v3`) to produce an analog output (`OUT`), with `VREFL`/`VREFH` as DAC reference voltages.
- This structure guided how the RTL modules and testbench were connected in the following stages.

## Stage 3 – RTL Design

The RTL/testbench source (`testbench.v`) defines the `rvmyth` module interface and conditionally includes either the pre-synthesis or post-synthesis sources depending on which simulation is being run:

![Testbench and rvmyth includes](03-rtl-design/testbench-and-rvmyth-includes.png)

- **`PRE_SYNTH_SIM`** path includes: `vsdbabysoc.v`, `avsddac.v`, `avsdpll.v`, `rvmyth.v`, `clk_gate.v`
- **`POST_SYNTH_SIM`** path includes: `baby_soc_netlist2.v` (the final synthesized netlist), `avsddac.v`, `avsdpll.v`, `primitives.v`, `sky130_fd_sc_hd.v`

The `rvmyth` module (generated via TL-Verilog, `rvmyth_gen.v`) exposes `OUT[9:0]`, `CLK`, and `reset`, and represents the processor core whose output feeds the DAC. The testbench (`vsdbabysoc_tb`) drives `reset`, `VCO_IN`, `ENb_CP`, `ENb_VCO`, `REF`, `VREFL`, `VREFH`, and observes `OUT`.

## Stage 4 – Functional Simulation

Functional (RTL-level, pre-synthesis) simulation was run using Icarus Verilog and viewed in GTKWave:

```bash
iverilog -o ./pre_synth_sim.out -DPRE_SYNTH_SIM src/module/testbench.v -I src/include -I src/module/
./pre_synth_sim.out
gtkwave pre_synth_sim.vcd
```

![Pre-synthesis simulation terminal](04-functional-simulation/pre-synth-sim-terminal.png)

This simulation completed successfully (`$finish called at 84999000 (1ps)`), producing `pre_synth_sim.vcd`. This waveform — showing the `RV_TO_DAC[9:0]` bus toggling over time — established the **reference/expected behavior** that the gate-level simulation was later compared against.

Runnable script: [`scripts/run_functional_sim.sh`](scripts/run_functional_sim.sh)

## Stage 5 – Synthesis

RTL synthesis was performed in Yosys, targeting the Sky130 standard cell library:

```tcl
read_verilog src/module/vsdbabysoc.v
read_verilog -I src/include/ src/module/rvmyth.v
read_verilog -I src/include/ src/module/clk_gate.v
read_liberty -lib src/lib/avsddac.lib
read_liberty -lib src/lib/avsdpll.lib
read_liberty -lib src/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
synth -top vsdbabysoc
dfflibmap -liberty src/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
opt
abc -liberty src/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
write_verilog -noattr baby_soc_netlist.v
show vsdbabysoc
flatten
write_verilog -noattr baby_soc_netlist1.v
setundef -zero
clean -purge
rename -enumerate
write_verilog -noattr baby_soc_netlist2.v
stat
```

![Yosys synthesis and post-synth-sim commands](05-synthesis/yosys-synthesis-and-post-synth-sim-commands.png)

Three netlists are written out at different points in the flow: `baby_soc_netlist.v` (right after technology mapping via `abc`), `baby_soc_netlist1.v` (after `flatten`), and the final `baby_soc_netlist2.v` (after `setundef`/`clean`/`rename`) — which is the netlist actually referenced by the `POST_SYNTH_SIM` branch of `testbench.v` (Stage 3) and used for Gate-Level Simulation.

ABC mapped the design onto Sky130 `sky130_fd_sc_hd` standard cells (AND/OR/NAND/NOR/MUX/XOR/flip-flop cells, etc.):

![ABC mapping results 1](05-synthesis/abc-mapping-results-1.png)
![ABC mapping results 2](05-synthesis/abc-mapping-results-2.png)

`stat` on the synthesized `vsdbabysoc` top module and the `rvmyth`/`clk_gate` sub-hierarchy confirmed the gate-level cell counts (thousands of `sky130_fd_sc_hd_*` cells, plus `avsdpll` and `avsddac` black-box instances):

![Hierarchy pass stat](05-synthesis/hierarchy-pass-stat.png)
![Post-synth stat 1](05-synthesis/post-synth-stat-1.png)
![Post-synth stat 2](05-synthesis/post-synth-stat-2.png)

A full schematic view of the synthesized design was also generated via `show`:

![Full chip schematic](05-synthesis/full-chip-schematic-dot-viewer.png)

Runnable script: [`scripts/synth.ys`](scripts/synth.ys)

## Stage 6 – Gate-Level Simulation (GLS)

With the final synthesized netlist (`baby_soc_netlist2.v`) in hand, GLS was run to check whether the synthesized gate-level design preserved the RTL-level functional behavior:

```bash
iverilog -o ./post_synth_sim.out -DPOST_SYNTH_SIM -DFUNCTIONAL -I src/include -I src/module -I src/gls_model src/module/testbench.v
vvp post_synth_sim.out
ls -la post_synth_sim.vcd
gtkwave post_synth_sim.vcd
```

This used the `sky130_fd_sc_hd.v` behavioral/functional Verilog models under `src/gls_model` (bundled with the BabySoC repo, **not** an external library) together with the `primitives.v` cell primitives, as set up in the `POST_SYNTH_SIM` branch of `testbench.v` (Stage 3).

`stat` output on the design confirmed the cell counts carried through from synthesis:

![Stat vsdbabysoc cells](06-gate-level-simulation/stat-vsdbabysoc-cells.png)

Yosys's `check` pass on the final netlist reported **0 problems**, confirming a structurally clean synthesized design:

![Check pass 0 problems](06-gate-level-simulation/stat-check-pass-0-problems.png)

Runnable script: [`scripts/run_post_synth_sim.sh`](scripts/run_post_synth_sim.sh)

## Stage 7 – GLS Problem and Debugging

**What was expected:** the `RV_TO_DAC[9:0]` waveform in GLS should match the pattern already established in the functional (pre-synth) simulation.

**What was observed:** in an early GLS run, several signals (`ENb_CP`, `VREFH`, and portions of the `RV_TO_DAC` bus) came up flat/constant instead of toggling as expected:

![GLS waveform issue](07-gls-debugging/gls-waveform-issue.png)

This was treated as a real problem, not a cosmetic difference — it meant the gate-level simulation was not yet reproducing the reference behavior seen at RTL. Two approaches were investigated.

### Approach 1 – Sky130 Library Path Issue

While debugging, an `iverilog` invocation was tried using the Sky130 library file from a **different, earlier workshop's** library path (`.../sky130RTLDesignAndSynthesisWorkshop/my_lib/verilog_model/sky130_fd_sc_hd.v`) instead of the BabySoC repo's own bundled library:

```bash
sudo iverilog -DPOST_SYNTH_SIM -DFUNCTIONAL -I src/include/ \
  -I /home/vsduser/VSDSquadron_FM/sky130RTLDesignAndSynthesisWorkshop/my_lib/verilog_model/ \
  -I src/module/ src/module/testbench.v
```

This produced a chain of `macro UNIT_DELAY undefined (and assumed null)` warnings, then a hard failure:

```
.../my_lib/verilog_model/sky130_fd_sc_hd.v:74452: syntax error
I give up.
```

Line 74452 of that file is an `` `endif `` preprocessor directive followed by a trailing macro name (`` `endif SKY130_FD_SC_HD__LPFLOW_BLEEDER_FUNCTIONAL_V ``), inside the `sky130_fd_sc_hd__lpflow_bleeder` cell model:

![Sky130 line 74452](07-gls-debugging/sky130-library-approach/sky130_fd_sc_hd-line-74452.png)

Subsequent attempts to run `vvp` directly on the wrong file also failed:

```
$ vvp post_synth_sim.vcd
post_synth_sim.vcd:2: syntax error
$ vvp post_synth_sim.out
post_synth_sim.out: Unable to open input file.
```

**Conclusion of this approach:** the failure traced back to compiling against the standard-cell library file from the *other* (Sky130 RTL Design and Synthesis) workshop's directory — a library that was **not** the one intended for the BabySoC GLS flow.

### Approach 2 – Compiling and Running via the Project's Own Sources (VVP method)

Once the correct, project-local include paths were used (`src/include`, `src/module`, `src/gls_model` — see Stage 6), the flow was re-run cleanly:

```bash
iverilog -o ./post_synth_sim.out -DPOST_SYNTH_SIM -DFUNCTIONAL -I src/include -I src/module -I src/gls_model src/module/testbench.v
vvp post_synth_sim.out
ls -la post_synth_sim.vcd
gtkwave post_synth_sim.vcd
```

![VVP approach terminal sequence](07-gls-debugging/vvp-approach/terminal-debug-sequence.png)

This produced a clean run (`$finish called at 84999000 (1ps)`) and a valid `post_synth_sim.vcd`, which was then opened in GTKWave for comparison against the functional simulation (Stage 8).

## Stage 8 – RTL vs GLS Comparison

With a valid post-synthesis waveform in hand, the pre-synthesis (`pre_synth_sim.vcd`) and post-synthesis (`post_synth_sim.vcd`) waveforms were opened side by side in GTKWave for direct comparison of the `RV_TO_DAC[9:0]` bus:

![Pre vs post synth waveform comparison](08-rtl-vs-gls-comparison/pre-vs-post-synth-waveform-comparison.png)

**Result:** both simulations produced the same output — the GLS waveform matched the functional simulation waveform over the full run (0–~85 μs). This confirms the synthesized gate-level implementation is functionally correct.

---

## Scripts

Runnable versions of the commands documented above are in [`scripts/`](scripts/):

- [`scripts/synth.ys`](scripts/synth.ys) — Yosys synthesis script (Stage 5)
- [`scripts/run_functional_sim.sh`](scripts/run_functional_sim.sh) — pre-synthesis functional simulation (Stage 4)
- [`scripts/run_post_synth_sim.sh`](scripts/run_post_synth_sim.sh) — gate-level simulation, using the corrected project-local library paths (Stage 6)

---

## Current Status

### Completed during this training

1. Git/GitHub and BabySoC repository setup
2. Specification analysis (VSDBabySoC architecture)
3. RTL review (`rvmyth`, `vsdbabysoc`, `clk_gate`, testbench)
4. Functional (RTL-level) simulation
5. RTL synthesis with Yosys + Sky130 (`sky130_fd_sc_hd__tt_025C_1v80.lib`)
6. Gate-Level Simulation (GLS)
7. Debugging and resolution of the GLS waveform issue (library path)
8. RTL vs GLS comparison — confirmed both produce the same output

### Pending — Future Stages

The following stages were **not** covered in this two-day training and are planned for future sessions:

1. Physical Design
2. Verification (physical, e.g. DRC/LVS)
3. Fabrication

---

## Repository Structure

```
baby-soc-vsdiat-cotraining/
│
├── README.md
│
├── 01-git-and-libraries/
├── 02-specifications/
├── 03-rtl-design/
├── 04-functional-simulation/
├── 05-synthesis/
├── 06-gate-level-simulation/
├── 07-gls-debugging/
│   ├── sky130-library-approach/
│   └── vvp-approach/
├── 08-rtl-vs-gls-comparison/
│
├── screenshots/     # flat mirror of all screenshots used above
└── scripts/         # runnable synth.ys / run_functional_sim.sh / run_post_synth_sim.sh
```

---

## Conclusion

Over the two-day VSDIAT co-training at Anurag University, we carried the VSDBabySoC design through the full digital front-end verification flow: reviewing the specification, working with the provided RTL and testbench, running functional simulation to establish reference behavior, synthesizing the design in Yosys against the Sky130 standard cell library, and running gate-level simulation on the synthesized netlist.

Along the way, we hit and resolved a real GLS waveform mismatch — tracing it to an incorrect external library path being used during compilation — and confirmed, through a direct RTL-vs-GLS waveform comparison, that both simulations produced the same output.

Physical design, verification, and fabrication stages remain for future training sessions.
