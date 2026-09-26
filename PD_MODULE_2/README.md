# Physical Design: Floorplanning and Placement (OpenLane / picorv32a)

This module picks up right after synthesis and walks through the next two stages of the ASIC physical design flow: **floorplanning** and **placement**. It explains how the die/core area is sized, how fixed IP blocks, decoupling capacitors, power distribution, and pin locations are decided during floorplanning, how placement then maps the netlist onto real physical cells and optimizes it, and closes with a short look at how standard cells are characterized in the first place. The accompanying lab runs both stages in OpenLane on the `picorv32a` design and inspects the results in Magic.

## Contents

1. [Core and Die Geometry, Utilization, and Aspect Ratio](#1-core-and-die-geometry-utilization-and-aspect-ratio)
2. [Pre-Placed Cells](#2-pre-placed-cells)
3. [Decoupling Capacitors and Noise Margins](#3-decoupling-capacitors-and-noise-margins)
4. [Power Planning](#4-power-planning)
5. [Pin Placement](#5-pin-placement)
6. [Placement Blockages](#6-placement-blockages)
7. [Placement and Optimization](#7-placement-and-optimization)
8. [How Standard Cells Get Characterized](#8-how-standard-cells-get-characterized)
9. [Lab Walkthrough](#9-lab-walkthrough)
10. [Wrap-Up](#10-wrap-up)

---

## 1. Core and Die Geometry, Utilization, and Aspect Ratio

Floorplanning begins by locking down two nested rectangles:

- **Die** — the full silicon area handed to fabrication.
- **Core** — the region inside the die where the actual logic lives, leaving a margin around the edge for I/O cells and power structures.

**Aspect ratio** is simply height ÷ width. A value of `1` produces a square core; anything else produces a rectangle.

**Utilization** measures how densely the core is packed with the netlist's cells:

```
Utilization (%) = (area occupied by standard cells / total core area) × 100
```

In practice, target utilization is usually held around 50–60% or lower. Packing the core any tighter starts to starve the routing and buffer-insertion stages that come later — there simply isn't enough spare room to route around congestion.

## 2. Pre-Placed Cells

Not every part of a design is left to the automatic placer. Large, reusable blocks — memories, clock-gating cells, comparators, multiplexers, or whole sub-modules of pre-verified logic — are frequently walled off as **hard macros** ("black boxes") with a fixed footprint and clearly defined external pins, so they can be dropped into a design wherever needed.

These macros get a fixed (x, y) location before the automated flow ever runs — deciding that arrangement is itself part of floorplanning. Because their position is locked in advance, they're referred to as **pre-placed cells**. The automatic placer and router simply treat that footprint as occupied and work with whatever core area is left over.

## 3. Decoupling Capacitors and Noise Margins

Any digital signal has three zones: a valid logic-`0` band, a valid logic-`1` band, and an undefined band in between. If switching noise pushes the voltage into that undefined band, the receiving gate can no longer tell what value was intended.

One common source of that noise is **IR drop**: when a large number of cells switch simultaneously, they draw a sudden current spike from the power rails, and the local supply voltage can momentarily sag. **Decoupling capacitors (decaps)** placed close to the switching cells act as a small local reservoir of charge — they absorb that current spike locally and then top themselves back up from the main supply once demand falls. This keeps the local rail steady and keeps signals out of the undefined zone.

Decaps are inserted during floorplanning, usually scattered above, below, or between logic blocks across the core.

## 4. Power Planning

A single point of VDD/VSS connection for an entire chip is a bad idea — all the switching current has to funnel through one path, which worsens both supply droop (on VDD) and ground bounce (on VSS), either of which can again push a signal into the undefined logic band.

**Power planning** fixes this by spreading multiple VDD/VSS connections across the die, structured as **power rings** feeding into **power straps**, which in turn feed the standard cell rows:

```
Power source
     │
   VDD / VSS
     │
 Power ring
     │
 Power straps
     │
Standard cell rows
```

## 5. Pin Placement

A Verilog/VHDL netlist only describes *logical* connectivity — it says nothing about where anything physically sits. **Pin placement** assigns each top-level I/O signal a physical location on the die, typically along one of the four edges (top/bottom/left/right), chosen based on the design's connectivity and where any pre-placed macros already sit.

## 6. Placement Blockages

Once macros and pins are locked in, certain regions of the core can be explicitly declared off-limits to the automatic standard-cell placer — a **placement blockage**. This is typically used to protect routing channels around a macro or reserve space for something that hasn't been placed yet, giving the floorplan finer control over how the final layout turns out.

## 7. Placement and Optimization

With the floorplan finalized, **placement** decides exactly where each standard cell in the netlist physically sits within the core.

### 7.1 Binding logical gates to physical cells

Every gate in the netlist has to be matched against a real, physical cell in the standard-cell library. That library entry defines both the cell's physical footprint (a fixed-width, fixed-height rectangle) and its electrical behavior. Most logic functions are offered in several "drive-strength" flavors — a physically bigger version of the same gate typically switches faster (lower delay) at the cost of extra area and power.

### 7.2 Global and detailed placement

Once every gate has a matching physical cell, the tool arranges all of them inside the core area the floorplan defined. This is the step that actually turns an abstract netlist into a concrete arrangement of silicon.

### 7.3 Optimization pass

After an initial placement, the tool estimates wire length, capacitance, and the resulting delay for every net, and inserts buffers ("repeaters") on any net whose transition time has degraded past a healthy threshold:

```
Cell ──────── Buffer ──────── Cell
```

## 8. How Standard Cells Get Characterized

### 8.1 Concepts

Every timing and power number used throughout synthesis, placement, and static timing analysis traces back to pre-characterized data for each standard cell. Two common modeling approaches are the **Non-Linear Delay Model (NLDM)** and **CCS (Composite Current Source)** timing, alongside separate models for power and noise.

### 8.2 Building a cell library

A standard-cell library holds cells across a range of functions, sizes, and threshold voltages. Producing one cell involves:

- **Inputs:** the target PDK, DRC/LVS rule decks, SPICE device models, an existing reference library, and the spec for the new cell.
- **Design steps:** circuit design, physical layout, and parasitic extraction from that layout.
- **Outputs:** a CDL netlist, a GDSII layout, a LEF file (cell width/height and pin geometry for place-and-route), an extracted SPICE netlist including parasitic R/C, and the final characterized `.lib` files (timing, noise, power).

### 8.3 Characterization flow

Characterizing a cell (with a tool such as GUNA) follows a fixed sequence:

1. Read in the process/SPICE models.
2. Read the extracted SPICE netlist for the cell.
3. Identify what the cell actually does (buffer, inverter, etc.).
4. Read the subcircuit definition for that gate.
5. Attach the required power supplies.
6. Apply the input stimulus.
7. Set the output load capacitance.
8. Set up the simulation (typically a `.TRAN` transient run).

These eight items are packaged into a configuration deck and handed to the characterization tool, which outputs the resulting timing, noise, and power models.

### 8.4 Timing characterization

Delay and slew are both measured against a set of per-cell threshold points: `in_rise_thr`, `in_fall_thr`, `out_rise_thr`, `out_fall_thr` for delay, and `slew_low_rise_thr`, `slew_high_rise_thr`, `slew_low_fall_thr`, `slew_high_fall_thr` for transition time.

**Propagation delay:**

```
delay = time(out_threshold) − time(in_threshold)
```

Poorly chosen thresholds can make this come out negative.

**Transition time (slew):**

```
rise transition = time(slew_high_rise_thr) − time(slew_low_rise_thr)
fall transition = time(slew_low_fall_thr) − time(slew_high_fall_thr)
```

---

## 9. Lab Walkthrough

The lab picks up on the same OpenLane run for `picorv32a` used for synthesis, and takes it through `run_floorplan` and `run_placement`, inspecting both results in Magic.

### 9.1 Checking OpenLane's floorplan configuration options

Before running the stage, it helps to see what floorplan-related variables OpenLane actually exposes. The `configuration/` folder holds one `.tcl` file per stage, plus a `README.md` documenting every variable and its default:

```
config ls
```

![Configuration folder listing]<img width="1260" height="633" alt="01-configuration-folder-listing" src="https://github.com/user-attachments/assets/0a2d319c-1230-4e5a-a4cc-8d59a6126675" />


The README lists the required variables (`DESIGN_NAME`, `VERILOG_FILES`, `CLOCK_PERIOD`, `CLOCK_PORT`, `CLOCK_NET`) plus the optional synthesis-related ones:

![README — required and synthesis variables]<img width="1255" height="642" alt="02-readme-required-variables" src="https://github.com/user-attachments/assets/cd45f6fd-4166-4044-8aa9-28504e9f7f50" />


Further down, the floorplanning-specific variables are documented — `FP_CORE_UTIL`, `FP_ASPECT_RATIO`, `FP_SIZING`, `DIE_AREA`, the I/O metal layers, and the power-distribution-network pitch/offset settings:

![README — floorplan variables]<img width="1258" height="640" alt="03-readme-floorplan-variables" src="https://github.com/user-attachments/assets/baa53133-2c67-4fdf-90db-24af5149ac53" />


`configuration/floorplan.tcl` sets the defaults actually used unless a design overrides them — `FP_CORE_UTIL` defaults to 50%, `FP_ASPECT_RATIO` to 1, and so on:

![floorplan.tcl defaults]<img width="1252" height="643" alt="04-floorplan-tcl-defaults" src="https://github.com/user-attachments/assets/5e18b1f6-f15d-4c26-9aba-972fb6526cfa" />


### 9.2 Running the floorplan stage

```
run_floorplan
```

This drives OpenROAD through netlist/DEF conversion, tap-cell insertion, I/O pin placement, and PDN (power distribution network) generation. The tail of the run shows the PDN step snapping several stripe locations to the nearest valid stripe, then confirming the network was built successfully:

![PDN generation completes successfully]<img width="1258" height="646" alt="05-pdn-generation-successful" src="https://github.com/user-attachments/assets/74e25e4c-059b-4071-ba3b-f1018055d789" />


### 9.3 Reviewing the floorplan logs

Each run directory keeps a `logs/floorplan/` folder with one log per sub-step (`verilog2def`, `ioPlacer`, `tapcell`, `pdn`):

![Contents of logs/floorplan/]<img width="1257" height="642" alt="06-floorplan-logs-directory" src="https://github.com/user-attachments/assets/7bc59b34-fd8a-423c-a0a1-18200f9f498d" />


The `ioPlacer` log confirms the LEF/DEF files that were read, the pin count, and that pins were placed using a random/even distribution since this design has no macro blocks:

![ioPlacer log contents]<img width="1261" height="647" alt="07-ioplacer-log-contents" src="https://github.com/user-attachments/assets/d98a5ba9-1b0a-4d7f-91aa-b5cd670aa4b9" />


### 9.4 Utilization override for this run

This design's library-specific config, `sky130A_sky130_fd_sc_hd_config.tcl`, overrides the default 50% utilization down to 35% and derives a target placement density from it:

![sky130A config overriding utilization to 35%]<img width="1262" height="642" alt="08-sky130A-config-utilization-override" src="https://github.com/user-attachments/assets/e9c2d727-123b-4c01-8fa7-091d6eb18b17" />


The run's fully expanded `config.tcl` confirms `FP_CORE_UTIL` actually took the value `"35"` for this run, alongside the rest of the inherited floorplan/PDN settings:

![Expanded config.tcl showing FP_CORE_UTIL = 35]<img width="1258" height="640" alt="09-expanded-config-fp-core-util" src="https://github.com/user-attachments/assets/75de043e-cad5-45eb-88e6-c43db1f447b4" />


### 9.5 Inspecting the generated floorplan DEF

`results/floorplan/picorv32a.floorplan.def` records the actual die area and row layout OpenROAD produced. Coordinates are given in DEF database units, and `UNITS DISTANCE MICRONS 1000` means 1000 of those units equal 1 micron — so a die area of `(0 0) (660685 671405)` works out to roughly **660.7 µm × 671.4 µm**:

![floorplan.def — die area and rows]<img width="1251" height="635" alt="10-floorplan-def-die-area" src="https://github.com/user-attachments/assets/cf546d0f-0471-4be7-8c6e-12fdedac2548" />


### 9.6 Viewing the floorplan in Magic

The floorplan DEF, together with the merged LEF, can be opened directly in Magic:

```
magic -T /home/vsduser/Desktop/work/tools/openlane_working_dir/pdks/sky130A/libs.tech/magic/sky130A.tech \
      lef read ../../tmp/merged.lef \
      def read picorv32a.floorplan.def &
```

![Opening the floorplan DEF in Magic]<img width="1262" height="641" alt="11-magic-open-floorplan-def" src="https://github.com/user-attachments/assets/c6b97ee0-5587-43ac-9a4e-dc6040439323" />


### 9.7 Floorplan layout — pins, tap cells, and decap cells

At this stage the core is still mostly empty of actual logic. What's visible is the row structure, the I/O pin columns, and the tap/decap cells inserted during floorplanning:

![Full floorplan view — rows, I/O columns, tap/decap cells]<img width="1258" height="645" alt="12-floorplan-full-view" src="https://github.com/user-attachments/assets/f71a964c-3180-4a1d-b114-352f11dfc890" />


Zooming in shows individual decap cells (`sky130_fd_sc_hd__decap_3`) and labeled I/O pins such as `mem_la_wstrb[0]`, attached to the `metal3` layer:

![Floorplan detail — decap cells and mem_la_wstrb pin]<img width="1261" height="645" alt="13-floorplan-detail-tapcells-pins-a" src="https://github.com/user-attachments/assets/0b3593ab-c9d3-4025-aae6-67307fd60e85" />


Further along the same row, more decap/tap cells and other labeled pins (`mem_rdata[3]`, `trace_data[26]`) appear on `metal2`/`metal3`:

![Floorplan detail — mem_rdata and trace_data pins]<img width="1258" height="642" alt="14-floorplan-detail-tapcells-pins-b" src="https://github.com/user-attachments/assets/841e52fd-aab2-46e1-b85d-7adbdbb6e1c7" />


### 9.8 Running placement

```
run_placement
```

This runs global and detailed placement followed by a resizing/optimization pass. The completion log reports 21,699 total instances (6,354 of them fixed — the tap/decap/pin cells inserted during floorplanning), 15,449 nets, a design area of roughly 420,473 µm², about 36% utilization (55% once padding is counted), and 238 placement rows. HPWL (half-perimeter wire length) is reported before and after legalization, and a screenshot of the layout is written out via KLayout:

![run_placement completion stats]<img width="1262" height="645" alt="15-run-placement-stats" src="https://github.com/user-attachments/assets/b35e3f21-947e-4c86-a77c-a77fd56055a2" />


### 9.9 Opening the placement result in Magic

The new `results/placement/picorv32a.placement.def` opens the same way the floorplan did, this time showing the fully placed design:

```
magic -T /home/vsduser/Desktop/work/tools/openlane_working_dir/pdks/sky130A/libs.tech/magic/sky130A.tech \
      lef read ../../tmp/merged.lef \
      def read picorv32a.placement.def &
```

![Opening the placement DEF in Magic]<img width="1257" height="642" alt="16-magic-open-placement-def" src="https://github.com/user-attachments/assets/d19cb58b-c81f-4d95-a5c8-9b9272843314" />


### 9.10 Placement layout — full and detailed views

The full-core view now shows the core densely packed with standard cells, in contrast to the sparse floorplan-only layout from step 9.7:

![Full placement view — core densely packed with cells]<img width="1260" height="641" alt="17-placement-full-view" src="https://github.com/user-attachments/assets/c47567e8-03c7-4313-a00f-4c811ed0d757" />


Zooming into a section of the placed design shows individual standard-cell instances — flip-flops (`dfxtp_4`), muxes (`mux2_8`), buffers, and AND-OR-invert cells — each labeled with its net/instance name:

![Placement detail — labeled standard cell instances]<img width="1262" height="640" alt="18-placement-detail-cells" src="https://github.com/user-attachments/assets/8ab0d585-c79a-43bd-993a-f002c7c0c024" />


---

## 10. Wrap-Up

This module traced how a floorplan actually comes together — sizing the core and die, reserving space for pre-placed macros, surrounding them with decoupling capacitors, planning a multi-point power network, placing I/O pins, and blocking off regions from automatic placement — and then how placement itself binds the netlist to physical cells and optimizes the result. A short detour into library characterization showed where all the timing/power numbers used throughout the flow originate. The lab carried `picorv32a` through both `run_floorplan` and `run_placement` in OpenLane, confirmed the 35% target utilization override, and inspected both the sparse floorplan and the fully placed layout directly in Magic.
