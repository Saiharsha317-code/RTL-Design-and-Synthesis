# VSDBabySoC — Multi-Corner Static Timing Analysis (16 PVT Corners)

Static Timing Analysis (STA) of the **VSDBabySoC** design with **OpenSTA** and the **SKY130 HD** standard-cell library, checked at **16 Process–Voltage–Temperature (PVT) corners**. For every corner the report gives hold slack, setup slack, WNS, TNS and a pass/fail status, followed by plots and a corner-by-corner discussion.

## Contents

1. [Project at a glance](#1-project-at-a-glance)
2. [About VSDBabySoC](#2-about-vsdbabysoc)
3. [Glossary — every term in plain words](#3-glossary--every-term-in-plain-words)
4. [Workflow with meaning of each step](#4-workflow-with-meaning-of-each-step)
5. [Understanding PVT corners](#5-understanding-pvt-corners)
6. [Timing equations](#6-timing-equations)
7. [Step-by-step commands](#7-step-by-step-commands)
8. [Results](#8-results)
9. [Plots](#9-plots)
10. [Analysis of the results](#10-analysis-of-the-results)
11. [Conclusion](#11-conclusion)
12. [Repository layout and references](#12-repository-layout-and-references)

---

## 1. Project at a glance

| Item | Detail |
|------|--------|
| Design | VSDBabySoC (RISC-V based mixed-signal SoC) |
| Technology | SKY130 |
| Standard-cell library | `sky130_fd_sc_hd` |
| Synthesis | Yosys with ABC technology mapping |
| Timing tool | OpenSTA |
| Constraints | SDC (Synopsys Design Constraints) |
| Corners analysed | 16 (6 FF, 8 SS, 2 TT) |
| Checks | Setup and hold |
| Metrics | Setup slack, hold slack, WNS, TNS |

**Result in one line:** hold timing is met at all 16 corners, setup timing is met at all 6 FF and both TT corners, and fails at all 8 SS corners. The worst case is `SS_n40C_1v28` with a WNS of **−62.563 ns**.

## 2. About VSDBabySoC

VSDBabySoC is a small mixed-signal System-on-Chip. It combines a RISC-V processor with analog blocks:

| Block | Role |
|-------|------|
| **RVMYTH** | RISC-V based processor core |
| **PLL** | Phase-Locked Loop, generates the system clock |
| **DAC** | Digital-to-Analog Converter, produces the analog output |

STA checks that data launched by one flip-flop reaches the next flip-flop inside the allowed time window under every operating condition.

## 3. Glossary — every term in plain words

| Term | Meaning |
|------|---------|
| **STA** | Static Timing Analysis. Checks every timing path of the circuit with delay numbers, without running a simulation |
| **Timing path** | Route from a launch point (flip-flop or input) through logic gates to a capture point (flip-flop or output) |
| **Launch / capture flop** | The flip-flop that sends the data and the flip-flop that receives it |
| **Clock period** | Time between two clock edges. Sets how long data has to travel |
| **Setup time** | How long data must be stable *before* the capture clock edge |
| **Hold time** | How long data must stay stable *after* the capture clock edge |
| **Slack** | Timing margin: how much time is left over (positive) or missing (negative) |
| **Setup slack** | Margin of the slowest path against the next clock edge. Checked with the *max* (longest) delays |
| **Hold slack** | Margin of the fastest path against the same clock edge. Checked with the *min* (shortest) delays |
| **Violation** | A path with negative slack |
| **WNS** | Worst Negative Slack. The single most negative setup slack. Reported as 0 when no path is negative |
| **TNS** | Total Negative Slack. Sum of every negative setup slack. Shows how many paths fail and by how much |
| **Critical path** | The path with the worst slack |
| **PVT** | Process, Voltage, Temperature. The operating conditions that change gate delay |
| **Corner** | One fixed PVT combination, for example `SS_n40C_1v28` |
| **FF / TT / SS** | Fast-Fast, Typical-Typical, Slow-Slow silicon process |
| **Liberty (.lib) file** | Library file that stores each cell's delay, setup and hold numbers for one corner |
| **Netlist** | Gate-level Verilog description of the design after synthesis |
| **SDC** | File that tells the tool the clock, its period and the input/output timing |
| **Timing closure** | State where setup and hold slack are non-negative at every corner |

## 4. Workflow with meaning of each step

```
VSDBabySoC RTL
      │
      ▼
  Synthesis ───────────► Gate-level netlist
      │
      ▼
 Physical design (floorplan → placement → clock tree → routing)
      │
      ▼
 OpenSTA reads: netlist + SDC + Liberty file of one corner
      │
      ▼
 Report setup slack, hold slack, WNS, TNS
      │
      ▼
 Repeat for all 16 corners
      │
      ▼
 Compare corners → plots → conclusion
```

| Step | What it means |
|------|---------------|
| **RTL** | The design written in Verilog describing behaviour |
| **Synthesis** | Yosys converts RTL into real SKY130 logic gates and flip-flops |
| **Gate-level netlist** | The output of synthesis: a list of gates and how they connect |
| **Floorplan / placement** | Chip area is fixed and cells are placed on it |
| **Clock tree synthesis** | Clock is distributed to every flip-flop with balanced arrival time |
| **Routing** | Wires are drawn between cells; wire delay now becomes part of timing |
| **Read Liberty** | Loads the cell delays for the chosen PVT corner |
| **Read netlist and link** | Loads the design and joins it with the library cells |
| **Read SDC** | Loads the clock definition and timing constraints |
| **Report slack / WNS / TNS** | The tool times every path and prints the worst values |
| **Repeat for 16 corners** | Only the Liberty file changes; the netlist and SDC stay the same |
| **Compare corners** | Shows which condition is the real timing limiter |

## 5. Understanding PVT corners

Gate delay is not a fixed number. It changes with three things:

| Factor | Effect on delay |
|--------|-----------------|
| **Process** (manufacturing variation) | FF gates are fastest, SS gates are slowest, TT is in between |
| **Voltage** | Lower voltage makes gates slower; higher voltage makes them faster |
| **Temperature** | Hot silicon is normally slower. At low voltage the effect can reverse and cold becomes slower (see section 10) |

### How to read a corner name

```
  ss  _  n40C  _  1v28
  │      │        └── voltage    → 1.28 V
  │      └─────────── temperature → n = negative → −40 °C
  └────────────────── process     → Slow-Slow
```

| Code | Meaning |
|------|---------|
| `n40C` | −40 °C |
| `025C` | 25 °C |
| `100C` | 100 °C |
| `1v28` | 1.28 V |
| `1v80` | 1.80 V (nominal) |

### The 16 corners

| No. | Corner | Process | Voltage | Temp | Why it matters |
|----:|--------|---------|--------:|-----:|----------------|
| 1 | `FF_100C_1v65` | Fast-Fast | 1.65 V | 100 °C | Fast, hot, low voltage |
| 2 | `FF_100C_1v95` | Fast-Fast | 1.95 V | 100 °C | Fast + hot + high voltage, shortest delays |
| 3 | `FF_n40C_1v56` | Fast-Fast | 1.56 V | −40 °C | Fast, cold, very low voltage |
| 4 | `FF_n40C_1v65` | Fast-Fast | 1.65 V | −40 °C | Fast, cold, low voltage |
| 5 | `FF_n40C_1v76` | Fast-Fast | 1.76 V | −40 °C | Fast, cold, mid voltage |
| 6 | `FF_n40C_1v95` | Fast-Fast | 1.95 V | −40 °C | Fast + cold + high voltage, classic worst case for hold |
| 7 | `SS_100C_1v40` | Slow-Slow | 1.40 V | 100 °C | Slow + hot + very low voltage, classic worst case for setup |
| 8 | `SS_100C_1v60` | Slow-Slow | 1.60 V | 100 °C | Slow, hot, low voltage |
| 9 | `SS_n40C_1v28` | Slow-Slow | 1.28 V | −40 °C | Slow, cold, lowest voltage |
| 10 | `SS_n40C_1v35` | Slow-Slow | 1.35 V | −40 °C | Slow, cold, low voltage |
| 11 | `SS_n40C_1v40` | Slow-Slow | 1.40 V | −40 °C | Slow, cold, low voltage |
| 12 | `SS_n40C_1v44` | Slow-Slow | 1.44 V | −40 °C | Slow, cold, low voltage |
| 13 | `SS_n40C_1v60` | Slow-Slow | 1.60 V | −40 °C | Slow, cold, nominal voltage |
| 14 | `SS_n40C_1v76` | Slow-Slow | 1.76 V | −40 °C | Slow, cold, high voltage |
| 15 | `TT_025C_1v80` | Typical | 1.80 V | 25 °C | Nominal baseline, reference for comparison |
| 16 | `TT_100C_1v80` | Typical | 1.80 V | 100 °C | Hot typical, shows temperature effect |

**Rule of thumb:** slow corners stress **setup** (data arrives late), fast corners stress **hold** (data arrives too early).

## 6. Timing equations

**Setup slack** — data must arrive before the next capture edge:

```
Setup Slack = Required Time − Data Arrival Time
            ≈ Clock Period − Setup Time − Clock Uncertainty − Data Path Delay
```

**Hold slack** — data must not arrive before the hold window ends:

```
Hold Slack = Data Arrival Time − Required Time
```

| Slack value | Meaning |
|-------------|---------|
| Positive | Requirement met with margin |
| Zero | Met exactly, no margin |
| Negative | Violation |

**WNS and TNS**

```
WNS = most negative setup slack   (0 if no path is negative)
TNS = sum of all negative setup slacks
```

A design can have a small WNS but a very large TNS (many paths slightly failing) or a large WNS with a small TNS (one bad path). Looking at both gives the full picture.

## 7. Step-by-step commands

**Step 1 — Check that OpenSTA is installed**

```bash
sta -version
```
Prints the OpenSTA version. If the command is not found, install OpenSTA first.

**Step 2 — Get the repository**

```bash
git clone https://github.com/efabless/skywater-pdk-libs-sky130_fd_sc_hd.git
cd RTL_Workspace/VSDBabySoC
```
`git clone` downloads the project, `cd` moves into the VSDBabySoC folder.

**Step 3 — Start OpenSTA**

```bash
sta
```
Opens the interactive OpenSTA prompt. Every command below is typed at this prompt.

**Step 4 — Load the library of one corner**

```tcl
read_liberty sky130_fd_sc_hd__tt_025C_1v80.lib
read_liberty avsdpll.lib
read_liberty avsddac.lib
```
`read_liberty` loads cell timing. The first line is the standard-cell library of the chosen corner. The other two are the timing models of the PLL and DAC blocks.

**Step 5 — Load the design**

```tcl
read_verilog vsdbabysoc.synth.v
link_design vsdbabysoc
```
`read_verilog` loads the gate-level netlist. `link_design` connects it to the library cells and selects `vsdbabysoc` as the top module.

**Step 6 — Load the constraints**

```tcl
read_sdc vsdbabysoc_synthesis.sdc
```
Loads the clock definition and input/output timing rules.

**Step 7 — Report the timing numbers**

```tcl
report_worst_slack -min -digits 3
report_worst_slack -max -digits 3
report_wns -digits 3
report_tns -digits 3
```

| Command | What it prints |
|---------|----------------|
| `report_worst_slack -min` | Worst **hold** slack (shortest paths) |
| `report_worst_slack -max` | Worst **setup** slack (longest paths) |
| `report_wns` | Worst Negative Slack |
| `report_tns` | Total Negative Slack |
| `-digits 3` | Print three decimal places |

**Step 8 — Look at the critical path in detail (optional)**

```tcl
report_checks -path_delay max -digits 3
report_checks -path_delay min -digits 3
```
`max` shows the worst setup path, `min` shows the worst hold path. Each report lists the startpoint, endpoint, every gate delay, data arrival time, data required time and the final slack.

**Step 9 — Repeat for every corner**

Exit with `exit`, start `sta` again and repeat steps 4 to 7, changing only the Liberty file name. The file name follows the corner name:

```
sky130_fd_sc_hd__<corner>.lib      e.g. sky130_fd_sc_hd__ss_n40C_1v28.lib
```

Collect the four numbers from each run into one table (section 8).

### Terminal output — PVT corner comparison table

```
CORNER                MIN SLACK    MAX SLACK          WNS          TNS STATUS
--------------------------------------------------------------------------
FF_100C_1v65              0.249        4.055        0.000        0.000 MET
FF_100C_1v95              0.196        5.567        0.000        0.000 MET
FF_n40C_1v56              0.292        2.278        0.000        0.000 MET
FF_n40C_1v65              0.255        3.411        0.000        0.000 MET
FF_n40C_1v76              0.224        4.430        0.000        0.000 MET
FF_n40C_1v95              0.187        5.592        0.000        0.000 MET
SS_100C_1v40              0.905      -17.122      -17.122    -2599.514 VIOLATED
SS_100C_1v60              0.642       -7.874       -7.874     -892.705 VIOLATED
SS_n40C_1v28              1.830      -62.563      -62.563   -13957.588 VIOLATED
SS_n40C_1v35              1.348      -39.697      -39.697    -7993.793 VIOLATED
SS_n40C_1v40              1.125      -29.694      -29.694    -5466.484 VIOLATED
SS_n40C_1v44              0.991      -23.908      -23.908    -4107.187 VIOLATED
SS_n40C_1v60              0.663      -10.609      -10.609    -1355.797 VIOLATED
SS_n40C_1v76              0.504       -4.382       -4.382     -367.928 VIOLATED
TT_025C_1v80              0.310        1.939        0.000        0.000 MET
TT_100C_1v80              0.314        2.094        0.000        0.000 MET

MIN SLACK = Worst hold slack
MAX SLACK = Worst setup slack
WNS       = Worst Negative Setup Slack
TNS       = Total Negative Setup Slack
STATUS    = MET if WNS >= 0, otherwise VIOLATED

Total PVT corners analyzed : 16
ALL 16 PVT CORNERS COMPLETED
```

## 8. Results

All values in nanoseconds (ns).

| Corner | Hold slack | Setup slack | WNS | TNS | Status |
|--------|-----------:|------------:|----:|----:|:------:|
| FF_100C_1v65 | 0.249 | 4.055 | 0.000 | 0.000 | MET |
| FF_100C_1v95 | 0.196 | 5.567 | 0.000 | 0.000 | MET |
| FF_n40C_1v56 | 0.292 | 2.278 | 0.000 | 0.000 | MET |
| FF_n40C_1v65 | 0.255 | 3.411 | 0.000 | 0.000 | MET |
| FF_n40C_1v76 | 0.224 | 4.430 | 0.000 | 0.000 | MET |
| FF_n40C_1v95 | 0.187 | 5.592 | 0.000 | 0.000 | MET |
| SS_100C_1v40 | 0.905 | −17.122 | −17.122 | −2599.514 | VIOLATED |
| SS_100C_1v60 | 0.642 | −7.874 | −7.874 | −892.705 | VIOLATED |
| SS_n40C_1v28 | 1.830 | −62.563 | −62.563 | −13957.588 | VIOLATED |
| SS_n40C_1v35 | 1.348 | −39.697 | −39.697 | −7993.793 | VIOLATED |
| SS_n40C_1v40 | 1.125 | −29.694 | −29.694 | −5466.484 | VIOLATED |
| SS_n40C_1v44 | 0.991 | −23.908 | −23.908 | −4107.187 | VIOLATED |
| SS_n40C_1v60 | 0.663 | −10.609 | −10.609 | −1355.797 | VIOLATED |
| SS_n40C_1v76 | 0.504 | −4.382 | −4.382 | −367.928 | VIOLATED |
| TT_025C_1v80 | 0.310 | 1.939 | 0.000 | 0.000 | MET |
| TT_100C_1v80 | 0.314 | 2.094 | 0.000 | 0.000 | MET |

Status is **MET** when WNS ≥ 0 and **VIOLATED** otherwise.

### Summary by process

| Group | Corners | Setup | Hold |
|-------|--------:|:-----:|:----:|
| FF | 6 | all met | all met |
| TT | 2 | all met | all met |
| SS | 8 | all violated | all met |
| **Total** | **16** | **8 met / 8 violated** | **16 met** |

### Corners ranked by setup slack (worst to best)

| Rank | Corner | Setup slack (ns) |
|-----:|--------|-----------------:|
| 1 | SS_n40C_1v28 | −62.563 |
| 2 | SS_n40C_1v35 | −39.697 |
| 3 | SS_n40C_1v40 | −29.694 |
| 4 | SS_n40C_1v44 | −23.908 |
| 5 | SS_100C_1v40 | −17.122 |
| 6 | SS_n40C_1v60 | −10.609 |
| 7 | SS_100C_1v60 | −7.874 |
| 8 | SS_n40C_1v76 | −4.382 |
| 9 | TT_025C_1v80 | 1.939 |
| 10 | TT_100C_1v80 | 2.094 |
| 11 | FF_n40C_1v56 | 2.278 |
| 12 | FF_n40C_1v65 | 3.411 |
| 13 | FF_100C_1v65 | 4.055 |
| 14 | FF_n40C_1v76 | 4.430 |
| 15 | FF_100C_1v95 | 5.567 |
| 16 | FF_n40C_1v95 | 5.592 |

## 9. Plots

Each plot has the 16 corners on the x-axis in the same order as the results table.

### Setup slack vs PVT corner
Positive values are safe. Everything below the zero line is a setup violation.

![Setup slack]<img width="1350" height="750" alt="setup_slack" src="https://github.com/user-attachments/assets/6c78ec18-f18b-4963-80ff-2a36dcf873bb" />


### Hold slack vs PVT corner
All points stay above zero, so there is no hold violation. The shape is the mirror image of the setup plot.

![Hold slack]<img width="1350" height="750" alt="hold_slack" src="https://github.com/user-attachments/assets/d62432a6-083f-4b16-bb93-3819acd9d300" />


### WNS vs PVT corner
Same as setup slack but clipped at zero, so only failing corners show a dip.

![WNS]<img width="1350" height="750" alt="wns" src="https://github.com/user-attachments/assets/60c9e0b3-2eac-461a-89ab-e3fa7d9be571" />


### TNS vs PVT corner
Shows how many paths fail, not just the worst one. The dip at `SS_n40C_1v28` is far deeper than at any other corner.

![TNS]<img width="1350" height="750" alt="tns" src="https://github.com/user-attachments/assets/f60ddc59-89d0-49a1-8144-274db1bd26f4" />


## 10. Analysis of the results

**Hold timing is clean.** Hold slack is positive at all 16 corners. The smallest value is 0.187 ns at `FF_n40C_1v95`, which is the expected hold worst case: fast silicon makes the shortest paths even shorter.

**Setup timing is the problem.** All 8 slow-slow corners fail. Fast and typical corners pass with margins from 1.939 ns to 5.592 ns.

**The worst corner is `SS_n40C_1v28`.** WNS is −62.563 ns and TNS is −13957.588 ns. It has the lowest voltage in the whole set, so gates are at their slowest.

**Voltage is the dominant factor.** Along the −40 °C slow-slow corners, WNS improves steadily as voltage rises:

| Voltage | 1.28 V | 1.35 V | 1.40 V | 1.44 V | 1.60 V | 1.76 V |
|---------|-------:|-------:|-------:|-------:|-------:|-------:|
| WNS (ns) | −62.563 | −39.697 | −29.694 | −23.908 | −10.609 | −4.382 |

Even at 1.76 V the slow corner still fails by 4.382 ns, so voltage alone does not fix the design.

**Cold is slower than hot at low voltage.** At the same voltage and slow process, the −40 °C corner is worse than the 100 °C corner:

| Voltage | 100 °C setup slack | −40 °C setup slack |
|---------|-------------------:|-------------------:|
| 1.40 V | −17.122 ns | −29.694 ns |
| 1.60 V | −7.874 ns | −10.609 ns |

This is the *temperature inversion* effect: at low supply voltage the gate threshold voltage rises in the cold and slows the gates down, which overrides the usual rule that hot silicon is slower. It is the reason cold corners have to be analysed together with hot ones.

**Setup and hold trade against each other.** The corners that are worst for setup (SS) have the best hold slack (0.504 to 1.830 ns), and the corners that are best for setup (FF) have the smallest hold slack (0.187 to 0.292 ns). Any fix that speeds up the data path must be re-checked for hold at the fast corners.

**TNS shows the spread.** `SS_n40C_1v28` has a TNS of −13957.588 ns, which means a very large number of paths fail there, not only one. `SS_n40C_1v76` has a TNS of only −367.928 ns, so only a small group of paths misses timing.

**The typical corners have limited margin.** `TT_025C_1v80` meets setup by only 1.939 ns, so the design has little headroom even under nominal conditions.

## 11. Conclusion

Across the 16 PVT corners, VSDBabySoC meets hold timing everywhere and meets setup timing at all FF and TT corners. All eight SS corners violate setup, with a worst WNS of −62.563 ns and a worst TNS of −13957.588 ns at `SS_n40C_1v28`.

| Check | Status |
|-------|:------:|
| Hold timing, 16 corners | Met |
| Setup timing, FF and TT corners | Met |
| Setup timing, SS corners | Violated |
| Timing closure across all corners | Not achieved |

This analysis shows why checking a single typical corner is not enough: the design passes at TT and FF and still fails badly at SS. Timing closure needs setup and hold to be non-negative at every corner at once.

## 12. Repository layout and references

```
VSDBabySoC/
├── README.md      # this report
└── images/
    ├── setup_slack.png
    ├── hold_slack.png
    ├── wns.png
    └── tns.png
```

- [OpenSTA](https://github.com/The-OpenROAD-Project/OpenSTA)
- [OpenROAD Project](https://github.com/The-OpenROAD-Project/OpenROAD)
- [SkyWater SKY130 PDK](https://github.com/google/skywater-pdk)
- [Yosys](https://github.com/YosysHQ/yosys)
