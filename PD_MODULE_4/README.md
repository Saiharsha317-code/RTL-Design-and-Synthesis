# From Custom Cell to Clock Tree: Pre-Layout Timing of `picorv32a` in OpenLANE

My lab journal for the part of the flow where a **custom standard cell (`sky130_vsdinv`)** meets a real design
(**picorv32a**) and I check what **timing** looks like before and after **Clock Tree Synthesis (CTS)**.

I wrote this so that in a few weeks I can answer quickly: **what did I run, what numbers did I get, what do they mean, and what is still unresolved?**
Everything is in this one README; each claim is backed by a screenshot in [`images/`](images/) (upscaled and sharpened for readability).

---

## Contents

1. [The flow in one picture](#1-the-flow-in-one-picture)
2. [Timeline](#2-timeline)
3. [Numbers worth remembering](#3-numbers-worth-remembering)
4. [Part 1 · Cell geometry and the routing grid](#part-1--cell-geometry-and-the-routing-grid)
5. [Part 2 · Liberty timing libraries (three corners)](#part-2--liberty-timing-libraries-three-corners)
6. [Part 3 · Timing constraints (SDC)](#part-3--timing-constraints-sdc)
7. [Part 4 · Placement: finding my cell in the design](#part-4--placement-finding-my-cell-in-the-design)
8. [Part 5 · Timing with ideal clocks (before CTS)](#part-5--timing-with-ideal-clocks-before-cts)
9. [Part 6 · Clock Tree Synthesis](#part-6--clock-tree-synthesis)
10. [Part 7 · Timing with real clocks (after CTS)](#part-7--timing-with-real-clocks-after-cts)
11. [Slack before vs after CTS](#slack-before-vs-after-cts)
12. [Concepts I used](#concepts-i-used) · [Quick-recall questions](#quick-recall-questions) · [Open items](#things-i-still-need-to-double-check) · [Next steps](#next-steps) · [Command cheat-sheet](#command-cheat-sheet)

---

## 1. The flow in one picture

```
 sky130_vsdinv (my inverter)                                      picorv32a RTL
   layout ──► LEF  (size, pins)  ─┐                                     │
   (Part 1)   + liberty timing   ─┼─► OpenLANE: synthesis ─► floorplan ─► placement ─► CTS ─► (routing …)
              (Part 2)            │      (uses SDC, Part 3)      (Part 4)      (Part 6)
                                  │                                  │            │
                                  └───────────── STA (OpenSTA) ──────┴────────────┘
                                          ideal clocks (Part 5)     real clocks (Part 7)
```

* **LEF** tells the placer/router the *physical* facts (size, pin shapes). **Liberty** tells STA the *timing* facts (delay tables).
* **SDC** tells STA what clock and I/O timing to aim for.
* **STA before CTS** assumes a perfect clock; **STA after CTS** uses the real buffered clock tree.

## 2. Timeline

| When (from screenshot clocks) | What | Section |
|---|---|---|
| Wed 18:26 | Re-opened `sky130_inv` layout in Magic | [Part 1](#part-1--cell-geometry-and-the-routing-grid) |
| Sat 13:04 | Read `tracks.info` of the sky130_fd_sc_hd library | [Part 1](#part-1--cell-geometry-and-the-routing-grid) |
| Sat 16:33 | Read `sky130_vsdinv.lef` | [Part 1](#part-1--cell-geometry-and-the-routing-grid) |
| Sat 16:44–16:47 | Looked at the typical, slow and fast `.lib` files | [Part 2](#part-2--liberty-timing-libraries-three-corners) |
| Sun 03:10 | Edited the SDC in `picorv32a/src` | [Part 3](#part-3--timing-constraints-sdc) |
| Sun 09:24–10:43 | Opened the placement DEF in Magic | [Part 4](#part-4--placement-finding-my-cell-in-the-design) |
| Sun 11:56–11:58 | STA with ideal clocks | [Part 5](#part-5--timing-with-ideal-clocks-before-cts) |
| Sun 12:28 | CTS run | [Part 6](#part-6--clock-tree-synthesis) |
| Sun 12:40–12:42 | Printed the CTS-related environment variables | [Part 6](#part-6--clock-tree-synthesis) |
| Sun 12:59 | First STA with real clocks | [Part 7](#part-7--timing-with-real-clocks-after-cts) |
| Sun 13:16–13:17 | Later STA with real clocks (much better setup, hold met) | [Part 7](#part-7--timing-with-real-clocks-after-cts) |

## 3. Numbers worth remembering

| Item | Value | Where |
|---|---|---|
| `sky130_vsdinv` size | **1.380 µm × 2.720 µm**, site `unithd` | LEF |
| Routing grid (li1) | X: offset 0.23, pitch 0.46 · Y: offset 0.17, pitch 0.34 | `tracks.info` |
| Library corners | ss 100 °C 1.60 V · tt 25 °C 1.80 V · ff −40 °C 1.95 V | `.lib` headers |
| Design | 409 pins · 21 555 components · 15 303 nets | CTS log |
| Clock period seen in STA reports | **12 ns** (capture edge at 12.00) | STA |
| Pre-CTS setup | **WNS −36.62 ns, TNS −3854.15 ns** | `report_wns` / `report_tns` |
| Pre-CTS hold (shown path) | +0.24 ns (met) | STA |
| CTS root buffer | `sky130_fd_sc_hd__clkbuf_16` | env var |
| CTS buffer list | `clkbuf_1`, `_2`, `_4`, `_8` | env var |
| `CTS_MAX_CAP` | 1.53169 | env var |
| Post-CTS, first run | setup **−38.29 ns**, hold **−1.93 ns** (both violated) | STA 12:59 |
| Post-CTS, later run | setup **−9.26 ns** (violated), hold **+0.1075 ns** (met) | STA 13:16–13:17 |

---

## Part 1 · Cell geometry and the routing grid

Before a cell can live in a design, its **layout** must fit the library's **grid**, and its **LEF** must describe it.

### The layout (revisited)

![inverter layout]<img width="2985" height="1800" alt="sky130-inv-layout-in-magic" src="https://github.com/user-attachments/assets/2d3dbb7c-66f4-4119-94be-93842bf70b9d" />


Same inverter as in my earlier layout/SPICE lab: **VPWR** rail on top, **VGND** rail below, input **A** on the left (li1 pad), output **Y** on the right,
one shared poly gate, PMOS in the N-well (top), NMOS (bottom).

### The grid: `tracks.info`

![tracks]<img width="2991" height="1785" alt="tracks-info" src="https://github.com/user-attachments/assets/0556f698-c426-4fa6-8e8c-1308432e0980" />


Each line is `layer direction offset pitch` (µm):

| Layer | X offset / pitch | Y offset / pitch |
|---|---|---|
| li1 | 0.23 / 0.46 | 0.17 / 0.34 |
| met1 | 0.17 / 0.34 | 0.17 / 0.34 |
| met2 | 0.23 / 0.46 | 0.23 / 0.46 |
| met3 | 0.34 / 0.68 | 0.34 / 0.68 |
| met4 | 0.46 / 0.92 | 0.46 / 0.92 |
| met5 | 1.70 / 3.40 | 1.70 / 3.40 |

**Why it matters:** the router puts wires only on these tracks, so cell pins must sit on them. My cell is **1.38 µm = 3 × 0.46 µm** wide and
**2.72 µm = 8 × 0.34 µm** tall, i.e. an exact number of li1 pitches: it snaps to the grid.

### The LEF

![lef]<img width="2991" height="1791" alt="sky130-vsdinv-lef" src="https://github.com/user-attachments/assets/b10433c8-1ca8-40ca-b2d0-270fa4543d64" />


What the file tells the tools:

| LEF entry | Meaning |
|---|---|
| `MACRO sky130_vsdinv`, `CLASS CORE` | an ordinary standard cell |
| `SIZE 1.380 BY 2.720`, `SITE unithd` | footprint = 3 sites wide, one row tall |
| `PIN A` (INPUT), li1 rectangle `0.060 1.180 – 0.510 1.690` | where a router may connect to the input |
| `ANTENNAGATEAREA 0.1656` | gate area for antenna-rule checks on A |
| `PIN Y` (OUTPUT), several li1 rectangles | output pin shape |
| `ANTENNADIFFAREA 0.2878` | diffusion area at Y (helps antenna checks) |
| `PIN VPWR` (INOUT, USE POWER) with `nwell` and li1 shapes | power pin, includes the N-well rectangle |

> The Magic bounding box of the layout was 1.77 × 3.28 µm because it includes the N-well overhang (−0.2 … 1.57 µm in X). The LEF `SIZE` (1.38 × 2.72) is the **abutment** box used for placement.

---

## Part 2 · Liberty timing libraries (three corners)

STA needs delays. A **Liberty (`.lib`)** file stores them as lookup tables for every cell, measured at a **PVT corner** (process, voltage, temperature).
The workshop folder holds three versions of the same library:

| Corner | Library name in file | Voltage | Temperature | Typical use |
|---|---|---|---|---|
| **Fast** | `sky130_fd_sc_hd__ff_n40C_1v95` | 1.95 V | −40 °C | **hold** checks (shortest delays) |
| **Typical** | `sky130_fd_sc_hd__tt_025C_1v80` | 1.80 V | 25 °C | nominal |
| **Slow** | `sky130_fd_sc_hd__ss_100C_1v60` | 1.60 V | 100 °C | **setup** checks (longest delays) |

![typical]<img width="2613" height="1566" alt="lib-typical-tt-025C-1v80" src="https://github.com/user-attachments/assets/bd10c413-ca29-4121-8dcf-4a0a55aabbb6" />

![slow]<img width="2616" height="1551" alt="lib-slow-ss-100C-1v60" src="https://github.com/user-attachments/assets/de237a04-94db-4da7-a2fc-ee6deaeccede" />

![fast]<img width="2598" height="1548" alt="lib-fast-ff-n40C-1v95" src="https://github.com/user-attachments/assets/b5910b19-de47-49f3-bf9d-a94a2cbee044" />


Things I noticed in the headers (identical in all three unless stated):

* `delay_model : "table_lookup"`: delays come from tables indexed by input slew and output load.
* Units: `time_unit "1ns"`, `voltage_unit "1V"`, `current_unit "1mA"`, `leakage_power_unit "1nW"`, `pulling_resistance_unit "1kohm"`, `capacitive_load_unit (1, "pf")`.
* `default_max_transition : 1.5` (ns).
* Fast corner: `default_arc_mode : "best_edges"`; slow and typical use `"worst_edges"`.
* `operating_conditions`: name, voltage, process = 1.0, temperature (typical shows 25, fast shows −40), `tree_type : "balanced_tree"`.

In my OpenLANE run the flow variables point to the **typical** library (see [Part 6](#part-6--clock-tree-synthesis)).

---

## Part 3 · Timing constraints (SDC)

![sdc]<img width="2484" height="1184" alt="base-sdc-file" src="https://github.com/user-attachments/assets/9bd505f3-35d7-4ebf-b668-88b9e54eec24" />


The SDC in `designs/picorv32a/src` (opened in vim) says:

| Line (paraphrased) | Meaning |
|---|---|
| `CLOCK_PORT = clk`, `CLOCK_PERIOD = 5.000` | the clock port and its period in the file |
| `create_clock … -period` | define the clock |
| `IO_PCT = 0.9892` | input/output delays are 98.92 % of the period |
| `input_delay_value = CLOCK_PERIOD × IO_PCT` (same for output) | external delay used for all I/O |
| `set_input_delay … all_inputs_wo_clk_rst` | applies to every input except the clock and the reset (`resetn` is handled on its own line) |
| `set_output_delay … all_outputs` | applies to all outputs |
| `SYNTH_DRIVING_CELL = sky130_fd_sc_hd__buf_8`, pin `X` | model of whatever drives the inputs; a commented line shows I also had `sky130_vsdinv` here as an option |
| `set_driving_cell -lib_cell … -pin … [all_inputs]` | applies that driver to every input |
| `SYNTH_CAP_LOAD = 17.65` → `set_cap_load = 17.65/1000` | output load (converted to pF) |
| `set_load $cap_load [all_outputs]` | applies the load to every output |

---

## Part 4 · Placement: finding my cell in the design

I opened the placed design in Magic by reading the merged LEF and the placement DEF from `results/placement`:

```bash
magic -T <pdk>/libs.tech/magic/sky130A.tech lef read ../../tmp/merged.lef def read picorv32a.placement.def
```

![placement overview]<img width="2988" height="1785" alt="placement-overview-in-magic" src="https://github.com/user-attachments/assets/9b42c3d3-4d95-498a-bcc1-82e7810c2867" />


Overview of the whole placed die: standard cells fill the core, with pins along the edges.

![placement zoom]<img width="2979" height="1773" alt="placement-zoomed" src="https://github.com/user-attachments/assets/f0436a8b-f01a-4b51-8614-61b4c4c760d5" />


Zoomed in, the instance named **`_17267_`** is a **`sky130_vsdinv`**: *my* inverter, placed by OpenLANE alongside library cells.

![custom cell]<img width="2991" height="1776" alt="custom-cell-instance-17267" src="https://github.com/user-attachments/assets/f7aec845-976a-4342-960a-5513691a9fc4" />


Neighbours visible here: a tap cell (`sky130_fd_sc_hd__tapvpwrvgnd_1`), a physical-only cell (`PHY_…`), and a `sky130_fd_sc_hd__nor2_2` (`_17264_`).
This confirms that the LEF integration worked: the tool accepted the cell and used it.

---

## Part 5 · Timing with ideal clocks (before CTS)

With **ideal clocks** the clock arrives everywhere instantly (the reports say *clock network delay (ideal) 0.00*), so only the **data path** matters.

### Setup: failing badly

![setup]<img width="2985" height="1776" alt="setup-wns-tns" src="https://github.com/user-attachments/assets/c3aa00cc-90bd-4d23-807c-71afd79c876e" />


* The critical path ends at flop `_27762_/D` and is a **long chain of `or2_2` gates** (each ≈ 0.65–0.68 ns), finishing with an `o221a_2`.
* **Data arrival = 48.32 ns.**
* The capture edge is at **12.00 ns**, and the flop's library setup time is −0.29 → **data required = 11.71 ns**.
* **Slack = required − arrival = 11.71 − 48.32 = −36.62 ns → VIOLATED.**
* `tns -3854.15` is the sum of all negative endpoint slacks; `wns -36.62` is the single worst.

### Hold: fine

![hold]<img width="2988" height="1776" alt="hold-slack-and-vsdinv-path" src="https://github.com/user-attachments/assets/11efa1a9-537b-40e5-bede-37225e819d8a" />


* A hold path launched by `_26669_` (flop) through a `buf_1` back into a flop: arrival 0.23 ns vs required −0.02 ns → **slack +0.24 ns, MET**.
* The next path in the report (setup, from flop `_27860_`) passes through **`_13108_/Y (sky130_vsdinv)`**, i.e. my custom inverter is part of a real timing path of the design.

---

## Part 6 · Clock Tree Synthesis

CTS builds a balanced tree of clock buffers so every flop sees the clock at nearly the same time.

![cts log]<img width="2991" height="1791" alt="cts-run-log" src="https://github.com/user-attachments/assets/d6206de3-3369-44f1-9c93-ae484392bf20" />


From the log:

* `Clock Tree Synthesis was successful`; the layout changed from `…/placement/picorv32a.placement.def` to `…/cts/picorv32a.cts.def`.
* OpenROAD **0.9.0** read the merged LEF: **13 technology layers, 25 technology vias, 442 library cells**.
* The design has **409 pins, 21 555 components, 15 303 nets**.
* A step then took a Klayout screenshot of the CTS layout (`picorv32a.cts.def.png`).

### Variables I printed afterwards

![env a]<img width="2976" height="1761" alt="cts-env-variables-a" src="https://github.com/user-attachments/assets/f7209ece-5bc6-4a81-867f-857e930f271a" />

![env b]<img width="2973" height="1785" alt="cts-env-variables-b" src="https://github.com/user-attachments/assets/d9b27220-2e66-456b-8bdd-b5490d364981" />


| Variable | Value | Meaning |
|---|---|---|
| `LIB_SYNTH_COMPLETE`, `LIB_TYPICAL` | `…/src/sky130_fd_sc_hd__typical.lib` | library used by synthesis/STA |
| `CURRENT_DEF` | `…/results/cts/picorv32a.cts.def` | the layout that STA will now use |
| `CTS_CLK_BUFFER_LIST` | `clkbuf_1 clkbuf_2 clkbuf_4 clkbuf_8` | buffers the CTS tool may insert |
| `CTS_ROOT_BUFFER` | `clkbuf_16` | buffer at the root of the tree |
| `SYNTH_MAX_TRAN` | 2.473 | max transition used in synthesis (ns) |
| `CTS_MAX_CAP` | 1.53169 | max capacitance for the clock nets (pF) |

---

## Part 7 · Timing with real clocks (after CTS)

Now the clock is a real buffered tree, so the reports list every clock buffer (`clkbuf_0_clk`, `clkbuf_1_1_0_clk`, …, `clkbuf_leaf_…`) and the flops get **different clock arrival times**.
That makes **hold** checks meaningful, and gives a **clock reconvergence pessimism (CRPR)** correction.

### First run (12:59)

![setup first]<img width="2610" height="1566" alt="first-run-setup-violated" src="https://github.com/user-attachments/assets/242002b7-f8d4-4364-8238-2b431a5b64c8" />


* Clock reaches `_27762_/CLK` at 12.9270 (12 ns edge + 0.9270 ns of clock tree) , +0.1202 CRPR, −0.2827 setup → **required 12.7645 ns**.
* Data arrival **51.0556 ns** → **setup slack −38.29 ns (VIOLATED)**: a little worse than the ideal-clock result (arrival grew from 48.3 to 51.1 ns), so the real clock tree did not help the setup problem; the long logic path is the real cause.

![hold first]<img width="2601" height="1551" alt="first-run-hold-violated" src="https://github.com/user-attachments/assets/6c32f243-855f-476b-b392-c3099e7975cb" />


* Hold: data arrival **1.3311 ns** vs required **3.2599 ns** (the capture clock arrives ≈ 3.4 ns after the source, much later than the data) → **hold slack −1.93 ns (VIOLATED)**.
* A hold violation means the data changes too soon after the capturing clock edge; here it is a **clock-skew** problem, not a slow-logic problem.

### Later run (13:16–13:17)

![setup later]<img width="2616" height="1551" alt="later-run-setup-violated" src="https://github.com/user-attachments/assets/fb7b9335-a45f-4f6a-8850-d3a42319ed1b" />


* Data arrival is now **22.5579 ns** (was 51.06) and required is 13.2959 → **setup slack −9.26 ns**: still violated, but much better.

![hold later]<img width="2613" height="1545" alt="later-run-hold-met" src="https://github.com/user-attachments/assets/7d0e9b88-7113-4c08-b3d5-4dc522f0911b" />


* Hold: arrival 1.9086 vs required 1.8012 → **slack +0.1075 ns (MET)**. Startpoint `_26374_`, endpoint `_27762_`.

> Something changed between the 12:59 and 13:16 runs (the data path became ~28 ns shorter and the hold violation disappeared). My screenshots do not show what, so I list it under *open items*.

## Slack before vs after CTS

| Run | Clock | Setup slack (worst shown) | Hold slack (shown) |
|---|---|---|---|
| 11:56–11:58 | ideal | **−36.62 ns** | +0.24 ns (met) |
| 12:59 | real (post-CTS) | **−38.29 ns** | **−1.93 ns** (violated) |
| 13:16–13:17 | real (post-CTS) | **−9.26 ns** | **+0.1075 ns** (met) |

---

## Concepts I used

| Term | Meaning |
|---|---|
| **Setup check** | data must arrive *before* the capture clock edge (minus the flop's setup time). `slack = required − arrival` |
| **Hold check** | data must *not* change too soon *after* the capture edge. `slack = arrival − required` |
| **Slack** | margin; negative = violation |
| **WNS / TNS** | worst negative slack / total negative slack over all endpoints |
| **Ideal clock** | clock arrives everywhere with zero delay (pre-CTS) |
| **Propagated clock** | clock delay is computed through the real buffers (post-CTS) |
| **Clock skew** | difference in clock arrival between launch and capture flops |
| **CRPR** | credit given when launch and capture clock paths share the same buffers, to remove false pessimism |
| **Corner (PVT)** | slow corner → worst setup, fast corner → worst hold |
| **LEF vs Liberty** | LEF = physical shape; Liberty = timing/power |

## Quick-recall questions

<details><summary><b>Q1.</b> Why is the pre-CTS setup slack −36.62 ns?</summary>

The data path to flop `_27762_` is ~48.3 ns (a long chain of `or2_2` gates) but the clock period is 12 ns, so required time is only 11.71 ns.
</details>

<details><summary><b>Q2.</b> Why can hold violations appear only after CTS?</summary>

With ideal clocks every flop sees the clock at the same time (no skew). After CTS the clock arrival differs between flops; if the capture flop's clock is late compared to the data, hold fails.
</details>

<details><summary><b>Q3.</b> Which corner is used for setup, which for hold?</summary>

Setup → slow (ss) corner, hold → fast (ff) corner. My OpenLANE run used the typical library.
</details>

<details><summary><b>Q4.</b> Why is my cell exactly 1.38 × 2.72 µm?</summary>

3 × 0.46 µm (li1 X pitch) by 8 × 0.34 µm (li1 Y pitch): one standard-cell row tall, three sites wide.
</details>

<details><summary><b>Q5.</b> How do I know my custom cell was really used?</summary>

In Magic the placement shows an instance `_17267_` of `sky130_vsdinv`, and an STA path lists `_13108_/Y (sky130_vsdinv)`.
</details>

## Things I still need to double-check

- [ ] **Clock period mismatch.** The SDC screenshot shows `CLOCK_PERIOD 5.000`, but all STA reports capture at **12.00 ns**. Find out which SDC/period the STA run actually used.
- [ ] **What changed between 12:59 and 13:16?** Record the exact command(s) (e.g. cell replacement/re-sizing, buffer-list change, re-run of CTS) that took setup from −38.29 to −9.26 ns and fixed hold.
- [ ] The commands that produced the STA reports (`report_checks`, `report_wns`, `report_tns`) are inferred from their output format; note the exact lines used.
- [ ] The Wednesday 18:26 inverter screenshot is from a different day than the rest; confirm it is the same `sky130_inv` layout used to make the LEF.
- [ ] The `Part 4` reading of the Magic view (which instance is which) is from labels visible in the screenshot; re-check if the placement is regenerated.

## Next steps

1. Fix the remaining **−9.26 ns setup violation**: options are to speed up the long `or2_2` chain (re-synthesise, upsize or buffer high-fanout nets) or to relax the clock period if the design allows.
2. Re-check **hold** after any change (the margin is only +0.1075 ns).
3. Compare timing with the **slow** and **fast** libraries instead of only the typical one.
4. Continue down the flow: **routing**, post-route STA, then signoff checks.

## Command cheat-sheet

| Command / variable | Use |
|---|---|
| `echo $::env(VAR)` | print an OpenLANE variable (`CURRENT_DEF`, `CTS_CLK_BUFFER_LIST`, `CTS_ROOT_BUFFER`, `CTS_MAX_CAP`, `LIB_TYPICAL`, …) |
| `magic -T sky130A.tech lef read <merged.lef> def read <file.def>` | view a placed/CTS design in Magic |
| `less` / `vim` on `.lib`, `.lef`, `tracks.info`, `.sdc` | inspect library and constraint files |
| `report_checks` | print timing paths (setup/hold) in OpenSTA |
| `report_wns`, `report_tns` | worst / total negative slack |

---

*Tools: OpenLANE (OpenROAD 0.9.0, TritonCTS flow), OpenSTA, Magic 8.x, SkyWater SKY130A PDK, Ubuntu VM.
Everything here is my own notes and screenshots.*
