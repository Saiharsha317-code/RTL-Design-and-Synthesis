# VSDIAT Co-Training – Baby SoC Design and Verification

Documentation  covering the design and verification flow of the **VSDBabySoC** architecture — from specification through RTL, functional simulation, synthesis, and gate-level simulation (GLS).

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
12. [Current Status](#current-status)
13. [Repository Structure](#repository-structure)
14. [Conclusion](#conclusion)

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

![Git clone setup]<img width="1260" height="197" alt="Screenshot 2026-08-30 220929" src="https://github.com/user-attachments/assets/f9049929-a856-44b9-8e33-1dd28d5b842c" />


This repository contains the BabySoC RTL sources (`src/module/`), include files (`src/include/`), and the Sky130/analog IP liberty and Verilog models (`src/lib/`) used in later synthesis and GLS stages.

## Stage 2 – Specification Analysis

Before RTL work began, we reviewed the VSDBabySoC architecture diagram to understand the design's structure:

![VSDBabySoC architecture]<img width="2270" height="1260" alt="babysoc_archi" src="https://github.com/user-attachments/assets/3953c278-8345-45d9-bd24-3275b0c72401" />


Key points identified from the specification:

- The design integrates a digital core (**rvmyth**, a RISC-V based processor), an analog **PLL** (`avsdpll_1v8`) and an analog **DAC** (`avsddac_3v3`).
- Two voltage domains are defined: **1.8V** (digital core, PLL/DAC control signals) and **3.3V** (SPI, crystal oscillator pad, DAC output side), connected through level shifters (`LS`).
- The **rvmyth** core outputs a 10-bit value (`D[9:0]`) which drives the DAC (`avsddac_3v3`) to produce an analog output (`OUT`), with `VREFL`/`VREFH` as DAC reference voltages.
- This structure guided how the RTL modules and testbench were connected in the following stages.

## Stage 3 – RTL Design

The RTL/testbench source (`testbench.v`) defines the `rvmyth` module interface and conditionally includes either the pre-synthesis or post-synthesis sources depending on which simulation is being run:

![Testbench and rvmyth includes]<img width="1920" height="983" alt="testbench-and-rvmyth-includes" src="https://github.com/user-attachments/assets/ee83b481-be73-415b-95eb-59d709c5e73f" />


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

![Pre-synthesis simulation terminal]<img width="1920" height="983" alt="pre-synth-sim-terminal" src="https://github.com/user-attachments/assets/478bd209-bbc2-4175-b953-bc60b69d88c8" />


This simulation completed successfully (`$finish called at 84999000 (1ps)`), producing `pre_synth_sim.vcd`. This waveform — showing the `RV_TO_DAC[9:0]` bus toggling over time — established the **reference/expected behavior** that the gate-level simulation was later compared against.

Waveform:<img width="1920" height="983" alt="day3_gls_simulation_withoutanychanges" src="https://github.com/user-attachments/assets/b0d6b2b8-a33e-4102-949f-35051fe1294a" />


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

![Yosys synthesis and post-synth-sim commands]<img width="1024" height="1536" alt="ChatGPT Image Aug 30, 2026, 10_32_16 PM" src="https://github.com/user-attachments/assets/155e031c-e219-4ed4-8cfb-838a5ba00d00" />


Three netlists are written out at different points in the flow: `baby_soc_netlist.v` (right after technology mapping via `abc`), `baby_soc_netlist1.v` (after `flatten`), and the final `baby_soc_netlist2.v` (after `setundef`/`clean`/`rename`) — which is the netlist actually referenced by the `POST_SYNTH_SIM` branch of `testbench.v` (Stage 3) and used for Gate-Level Simulation.

ABC mapped the design onto Sky130 `sky130_fd_sc_hd` standard cells (AND/OR/NAND/NOR/MUX/XOR/flip-flop cells, etc.):

![ABC mapping results 1]<img width="1920" height="983" alt="abc-mapping-results-1" src="https://github.com/user-attachments/assets/e325e3a6-a9dd-45cf-8e6f-90e69fe7b0e4" />

![ABC mapping results 2]<img width="1920" height="983" alt="abc-mapping-results-2" src="https://github.com/user-attachments/assets/8dfcd2b2-0fed-417d-b901-0f51c6addf80" />


`stat` on the synthesized `vsdbabysoc` top module and the `rvmyth`/`clk_gate` sub-hierarchy confirmed the gate-level cell counts (thousands of `sky130_fd_sc_hd_*` cells, plus `avsdpll` and `avsddac` black-box instances):

![Hierarchy pass stat]<img width="1920" height="983" alt="hierarchy-pass-stat" src="https://github.com/user-attachments/assets/882751fc-c43b-4e30-97ec-cd196b67d2bc" />

![Post-synth stat 1]<img width="1920" height="983" alt="post-synth-stat-1" src="https://github.com/user-attachments/assets/cbd69a0a-cdc9-4037-a93d-7709b80286f0" />

![Post-synth stat 2]<img width="1920" height="983" alt="post-synth-stat-2" src="https://github.com/user-attachments/assets/aa29ce12-dc80-4484-b92b-a1af6a920119" />


A full schematic view of the synthesized design was also generated via `show`:

![Full chip schematic]<img width="1920" height="983" alt="full-chip-schematic-dot-viewer" src="https://github.com/user-attachments/assets/24325f32-02ab-4de3-ad2d-6b372d728a9c" />




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

![Stat vsdbabysoc cells]<img width="1920" height="983" alt="stat-vsdbabysoc-cells" src="https://github.com/user-attachments/assets/ca6bf643-6aad-4d0b-a8f6-df582e5658cc" />


Yosys's `check` pass on the final netlist reported **0 problems**, confirming a structurally clean synthesized design:

![Check pass 0 problems]<img width="1920" height="983" alt="stat-check-pass-0-problems" src="https://github.com/user-attachments/assets/281306d4-45b4-4e99-a3c9-cb8a2701cba3" />

Waveform: <img width="1920" height="983" alt="VirtualBox_vsdworkshop1_30_08_2026_23_04_47" src="https://github.com/user-attachments/assets/1a6514d0-1011-4548-b1d9-d75b2963449a" />



## Stage 7 – GLS Problem and Debugging

**What was expected:** the `RV_TO_DAC[9:0]` waveform in GLS should match the pattern already established in the functional (pre-synth) simulation.

**What was observed:** in an early GLS run, several signals (`ENb_CP`, `VREFH`, and portions of the `RV_TO_DAC` bus) came up flat/constant instead of toggling as expected:

![GLS waveform issue]<img width="1362" height="362" alt="Screenshot 2026-08-30 224308" src="https://github.com/user-attachments/assets/f68f0385-6446-4c12-b57d-c31699b85a5f" />


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

![Sky130 line 74452]<img width="1920" height="983" alt="sky130_fd_sc_hd-line-74452" src="https://github.com/user-attachments/assets/af0d18b6-e035-4238-812a-1b1636bc0a43" />


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

![VVP approach terminal sequence]<img width="1920" height="983" alt="VirtualBox_vsdworkshop1_30_08_2026_22_52_03" src="https://github.com/user-attachments/assets/3b931ce6-145c-46ac-8e29-3f23d4cd3166" />


This produced a clean run (`$finish called at 84999000 (1ps)`) and a valid `post_synth_sim.vcd`, which was then opened in GTKWave for comparison against the functional simulation (Stage 8).

## Stage 8 – RTL vs GLS Comparison

With a valid post-synthesis waveform in hand, the pre-synthesis (`pre_synth_sim.vcd`) and post-synthesis (`post_synth_sim.vcd`) waveforms were opened side by side in GTKWave for direct comparison of the `RV_TO_DAC[9:0]` bus:

![Pre vs post synth waveform comparison]<img width="1920" height="983" alt="pre-vs-post-synth-waveform-comparison" src="https://github.com/user-attachments/assets/537c8eb5-8437-4b49-8665-6116c6170205" />


**Result:** both simulations produced the same output — the GLS waveform matched the functional simulation waveform over the full run (0–~85 μs). This confirms the synthesized gate-level implementation is functionally correct.

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
├── 08-rtl-vs-gls-comparison/

```

---

## Conclusion

Over the two-day VSDIAT co-training at Anurag University, we carried the VSDBabySoC design through the full digital front-end verification flow: reviewing the specification, working with the provided RTL and testbench, running functional simulation to establish reference behavior, synthesizing the design in Yosys against the Sky130 standard cell library, and running gate-level simulation on the synthesized netlist.

Along the way, we hit and resolved a real GLS waveform mismatch — tracing it to an incorrect external library path being used during compilation — and confirmed, through a direct RTL-vs-GLS waveform comparison, that both simulations produced the same output.

Physical design, verification, and fabrication stages remain for future training sessions.
