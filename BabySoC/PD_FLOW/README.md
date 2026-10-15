# VSDBabySoC Physical Design and PVT Timing Analysis

This repository documents my physical-design exploration of **VSDBabySoC** using the **SKY130 HD** platform and **OpenROAD / OpenROAD-flow-scripts (ORFS)**. It brings together the layout screenshots captured during the flow and the post-route timing plots used to review setup and hold behaviour across process, voltage and temperature (PVT) corners.

> **Scope note:** this is an evidence-based record of the screenshots and timing plots included here. The images show physical-design GUI views and timing charts; they do not, by themselves, establish successful GDSII sign-off, DRC/LVS cleanliness, detailed-route completion, or closure at every PVT corner.

## Contents

- [Overview](#overview)
- [Design flow](#design-flow)
- [Tools and platform](#tools-and-platform)
- [Running the flow](#running-the-flow)
- [Captured physical-design results](#captured-physical-design-results)
- [PVT timing plots](#pvt-timing-plots)
- [Reading the timing results](#reading-the-timing-results)
- [Repository structure](#repository-structure)
- [Validation checklist](#validation-checklist)
- [References](#references)

## Overview

The physical-design flow transforms a synthesized design into a placed and routed implementation. The usual progression is:

1. **Synthesis** — generate a gate-level netlist from RTL and the selected cell library.
2. **Floorplanning** — define the die/core region, place macros and IO pins, and create the power-distribution network (PDN).
3. **Placement** — assign standard cells to legal locations and optimize their placement.
4. **Clock Tree Synthesis (CTS)** — build the clock distribution network.
5. **Routing** — connect the design using routing layers and vias.
6. **Static Timing Analysis (STA)** — evaluate setup and hold timing under the applied constraints and selected PVT libraries.
7. **Final checks** — review route/DRC/LVS results and verify GDSII generation when those steps are part of the configured flow.

### Flow illustration

![Physical-design flow overview]<img width="1680" height="936" alt="image" src="https://github.com/user-attachments/assets/a7873072-cfcc-425b-ad1a-6b707a6fdc64" />


*Figure 1. High-level RTL-to-GDSII flow diagram. The exact available stages and target names depend on the ORFS version and design configuration.*

## Design flow

### 1. Floorplan and power network

The floorplan establishes the physical canvas and rows that constrain standard-cell placement. Macro locations, IO pins, blockages and the power-distribution network should be checked before proceeding.

![Floorplan view]<img width="1057" height="578" alt="01_floorplan_overview" src="https://github.com/user-attachments/assets/fa1e5b3b-801e-48ea-922a-b4f6d7cb4d31" />


*Figure 2. OpenROAD GUI floorplan view.*

![Power distribution network]<img width="1053" height="583" alt="02_power_distribution_network" src="https://github.com/user-attachments/assets/cee93adf-67f2-4996-a174-5ee21a913bfb" />


*Figure 3. Floorplan view with the power network visible. A GUI view is useful for inspection, but it is not a substitute for PDN connectivity reports or sign-off checks.*

### 2. Placement

Placement assigns standard cells to legal locations in the core. Review cell legality, placement density/overflow, fixed macros and timing-oriented optimization reports.

![Placement view]<img width="1260" height="647" alt="03_placement_stage" src="https://github.com/user-attachments/assets/5c4fefbc-7b83-4a31-9273-370e45a7ac3a" />


*Figure 4. OpenROAD GUI view associated with the placement stage.*

### 3. Net and pin inspection

The inspector can be used to review nets and endpoints in the physical database. The selected net/pin view below is included as an inspection snapshot, not as proof that all connectivity checks passed.

![Net inspection]<img width="1260" height="628" alt="04_floorplan_net_inspection" src="https://github.com/user-attachments/assets/0e563410-fe9a-4a93-8b86-c1309290605c" />


*Figure 5. Selected net inspection in the OpenROAD GUI.*

### 4. Global routing and congestion inspection

A routing heat map helps identify regions with higher estimated routing demand. Use the actual routing logs and reports to verify congestion, unrouted nets and routing completion.

![Global routing heat map]<img width="1262" height="520" alt="05_global_route_heatmap" src="https://github.com/user-attachments/assets/34c1f3a6-ae45-46d0-9562-581c4320dfdc" />


*Figure 6. Routing-related heat-map view.*

### 5. Clock Tree Synthesis and timing context

CTS inserts clock buffers and builds the clock distribution network for sequential cells. Useful checks include clock-tree reachability, skew, insertion latency, transition and fanout.

![Clock tree view]<img width="1260" height="645" alt="06_cts_clock_tree_view" src="https://github.com/user-attachments/assets/bd36e329-68dc-4340-943b-7e92ca684002" />


*Figure 7. Physical-design database view around the clock-tree / implementation region.*

### 6. Routed layout inspection

The routed database can be inspected to review metal layers, vias, power nets, tap cells and cell placement. This screenshot sequence records GUI inspection of the implementation.

![Routed layout]<img width="1145" height="677" alt="07_routed_layout_inspection" src="https://github.com/user-attachments/assets/ce7c8220-1e9c-425b-a004-1bd22792c52a" />


*Figure 8. Routed layout view with routing layers enabled.*

![Tap cell inspection]<img width="1147" height="667" alt="08_routed_tapcell_inspection" src="https://github.com/user-attachments/assets/ac793517-bd99-4914-9153-c56795f0a4df" />


*Figure 9. Selected tap-cell instance in the routed layout. The inspector shows instance attributes; final physical verification still requires the actual reports.*

## Tools and platform

The reference command examples below assume a configured **OpenROAD-flow-scripts** checkout and the design configuration at:

```text
flow/designs/sky130hd/vsdbabysoc/config.mk
```

Typical components for this flow include:

- OpenROAD-flow-scripts (ORFS)
- OpenROAD and OpenSTA timing analysis
- SKY130 HD standard-cell libraries and technology files
- Design RTL, synthesized netlist, SDC constraints and any required macro views

The exact paths and available GUI targets vary by checkout. Confirm that the design configuration and required macro files match your local installation before running commands.

## Running the flow

### 1. Get ORFS (only if it is not already installed)

```bash
cd ~/Desktop
git clone https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git
cd OpenROAD-flow-scripts/flow
make
```

If you already have a working ORFS checkout, skip the clone and build steps and enter its `flow/` directory.

### 2. Run the configured design flow

Run from the ORFS `flow/` directory:

```bash
make DESIGN_CONFIG=./designs/sky130hd/vsdbabysoc/config.mk
```

This uses the configuration found at that path. It will not work unchanged unless the design RTL, technology files, timing constraints and any PLL/DAC macro views required by the configuration are present and correctly referenced.

### 3. Run individual implementation stages

Run stages separately when inspecting logs and databases:

```bash
# Synthesis
make DESIGN_CONFIG=./designs/sky130hd/vsdbabysoc/config.mk synth

# Floorplan and power network
make DESIGN_CONFIG=./designs/sky130hd/vsdbabysoc/config.mk floorplan

# Placement
make DESIGN_CONFIG=./designs/sky130hd/vsdbabysoc/config.mk place

# Clock Tree Synthesis
make DESIGN_CONFIG=./designs/sky130hd/vsdbabysoc/config.mk cts

# Global and detailed routing, as configured by ORFS
make DESIGN_CONFIG=./designs/sky130hd/vsdbabysoc/config.mk route
```

Use the command for a stage only when its required predecessor outputs exist. If a stage fails, read the corresponding log before attempting later stages.

### 4. Open stage databases in the GUI

The following targets are available in many ORFS versions, but target names can vary. Check `make help` or your local ORFS documentation if a target is missing.

```bash
make DESIGN_CONFIG=./designs/sky130hd/vsdbabysoc/config.mk gui_floorplan
make DESIGN_CONFIG=./designs/sky130hd/vsdbabysoc/config.mk gui_place
make DESIGN_CONFIG=./designs/sky130hd/vsdbabysoc/config.mk gui_cts
make DESIGN_CONFIG=./designs/sky130hd/vsdbabysoc/config.mk gui_route
```

### 5. Inspect outputs

Common ORFS output locations for this design are:

```text
results/sky130hd/vsdbabysoc/base/
logs/sky130hd/vsdbabysoc/base/
reports/sky130hd/vsdbabysoc/base/
```

List the generated files rather than assuming that every stage completed:

```bash
ls -lh results/sky130hd/vsdbabysoc/base/
find logs/sky130hd/vsdbabysoc/base -maxdepth 1 -type f -print | sort
find reports/sky130hd/vsdbabysoc/base -maxdepth 1 -type f -print | sort
```

Common intermediate databases include `2_floorplan.odb`, `3_place.odb`, `4_cts.odb`, and `5_route.odb`, along with stage-specific SDC files. Actual filenames depend on the configured flow and completed stages.

### 6. Inspect routed timing in OpenROAD

If a routed database and its matching SDC exist, an OpenROAD Tcl session can be used to inspect timing. Run paths relative to your actual ORFS `flow/` directory and adapt them if your run differs.

```tcl
read_db ./results/sky130hd/vsdbabysoc/base/5_route.odb
read_sdc ./results/sky130hd/vsdbabysoc/base/5_route.sdc
source ./platforms/sky130hd/setRC.tcl
estimate_parasitics -global_routing
sta::find_timing
sta::find_requireds
report_checks -path_delay min_max -format full_clock_expanded -digits 4
```

For separate max-delay (setup-oriented) and min-delay (hold-oriented) path reports:

```tcl
report_checks -path_delay max -format full_clock_expanded -digits 4
report_checks -path_delay min -format full_clock_expanded -digits 4
```

These commands inspect the timing context currently loaded. A complete multi-corner analysis additionally requires the correct timing libraries, operating conditions and constraints to be loaded and selected for each corner. `estimate_parasitics -global_routing` uses a global-routing-based estimate; it should not be described as detailed-route SPEF extraction.

## PVT timing plots

The following charts were provided as project screenshots and are retained as separate files to keep them readable.

### Setup slack

![Setup slack across PVT corners]<img width="657" height="380" alt="09_setup_slack_by_pvt" src="https://github.com/user-attachments/assets/e2d772f7-ae49-4919-ac5c-02f391946f2c" />


*Figure 10. Setup slack (labelled `setup WS` in the original chart) across the plotted PVT corners. Negative values indicate setup timing violations.*

### Worst Negative Slack (WNS)

![Setup WNS across PVT corners]<img width="817" height="445" alt="10_setup_wns_by_pvt" src="https://github.com/user-attachments/assets/d07d1c5d-48cf-4e18-b9db-506f9a2e9b42" />


*Figure 11. Setup WNS across the plotted PVT corners. In the shown plot, the most negative value occurs at an SS corner.*

### Total Negative Slack (TNS)

![Setup TNS across PVT corners]<img width="802" height="477" alt="11_setup_tns_by_pvt" src="https://github.com/user-attachments/assets/ee80647d-2091-46ac-81a0-8acc0680b2f5" />


*Figure 12. Setup TNS across the plotted PVT corners. Large negative values indicate many or substantial failing setup endpoints.*

### Hold slack

![Hold slack across PVT corners]<img width="855" height="576" alt="12_hold_slack_by_pvt" src="https://github.com/user-attachments/assets/3b4c31a0-d631-47c4-ab49-656fc03e5f5a" />


*Figure 13. Hold slack (`holdWS` in the original chart). Positive values indicate hold margin under the report's convention.*

### Hold WNS

![Hold WNS across PVT corners]<img width="681" height="373" alt="13_hold_wns_by_pvt" src="https://github.com/user-attachments/assets/43cf21cc-2495-49fa-a129-a7169fcce9e9" />


*Figure 14. Hold WNS in the supplied chart. The plotted values appear at zero for the corners shown.*

### Hold TNS

![Hold TNS across PVT corners]<img width="728" height="425" alt="14_hold_tns_by_pvt" src="https://github.com/user-attachments/assets/b60b55ff-c460-4dcf-af38-b94add14b3a4" />


*Figure 15. Hold TNS in the supplied chart. The plotted values appear at zero for the corners shown.*

## Reading the timing results

- **Setup slack / max-delay slack:** evaluates whether data arrives before the setup requirement. Negative slack means a setup violation.
- **Hold slack / min-delay slack:** evaluates whether data arrives late enough to satisfy the hold requirement. Negative slack means a hold violation.
- **WNS (Worst Negative Slack):** the worst slack for the check being reported. For setup timing, a negative WNS means at least one setup path fails.
- **TNS (Total Negative Slack):** the aggregate slack of violating endpoints under the report's conventions. More negative setup TNS usually means the timing problem affects more endpoints and/or has larger violations.
- **PVT corner:** a process, supply-voltage and temperature condition. Timing should be reviewed for every corner required by the project.

### What the screenshots support

The setup charts show negative setup slack/WNS/TNS in part of the SS corner set, with the largest drop around the `ss_n40C_1v28` label. The hold-slack chart is positive at the shown corners, while hold WNS and TNS are plotted at zero. These observations are based on the supplied plots and should be confirmed against the corresponding text reports and exact corner definitions.

**Do not claim timing closure across all corners from these plots.** The setup plots show failures at some corners. Also, a zero hold WNS/TNS graph is only meaningful when the hold checks are correctly constrained and the timing report confirms that no relevant hold paths were omitted.

The uploaded charts use different metric scales, especially the setup TNS chart. Keep each metric in its own plot and retain the corner labels exactly as produced by the run.

## Repository structure

The recommended layout is:

```text
VSDBabySoC-Physical-Design/
├── README.md
└── images/
    ├── 00_physical_design_flow.png
    ├── 01_floorplan_overview.png
    ├── 02_power_distribution_network.png
    ├── 03_placement_stage.png
    ├── 04_floorplan_net_inspection.png
    ├── 05_global_route_heatmap.png
    ├── 06_cts_clock_tree_view.png
    ├── 07_routed_layout_inspection.png
    ├── 08_routed_tapcell_inspection.png
    ├── 09_setup_slack_by_pvt.png
    ├── 10_setup_wns_by_pvt.png
    ├── 11_setup_tns_by_pvt.png
    ├── 12_hold_slack_by_pvt.png
    ├── 13_hold_wns_by_pvt.png
    └── 14_hold_tns_by_pvt.png
```

## Validation checklist

Before calling the physical-design flow complete, confirm these items from the actual logs and reports:

- [ ] Synthesis completes and the generated netlist is the intended design.
- [ ] Floorplan, IO pin placement, macro locations and PDN connectivity are checked.
- [ ] Placement legality and congestion/overflow metrics are reviewed.
- [ ] CTS clock reachability, skew, insertion latency and transition checks are reviewed.
- [ ] Routing finishes and the reports identify any unrouted nets, DRC or antenna violations.
- [ ] The SDC is checked for clocks, input/output delays and intended exceptions/unconstrained paths.
- [ ] Setup and hold reports are reviewed for every required PVT corner.
- [ ] Final GDSII is generated by the configured flow.
- [ ] DRC/LVS and any required antenna checks are run and their results retained.
- [ ] Post-route parasitics used for STA are explicitly documented (global-routing estimate or extracted SPEF).

## References

- [OpenROAD-flow-scripts (ORFS)](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts) — implementation flow and make targets.
- [OpenROAD](https://github.com/The-OpenROAD-Project/OpenROAD) — physical-design engine and GUI.
- [OpenSTA](https://github.com/The-OpenROAD-Project/OpenSTA) — static timing analysis engine.
- [SkyWater SKY130 PDK libraries](https://github.com/efabless/skywater-pdk-libs-sky130_fd_sc_hd) — standard-cell timing libraries.
- [VSDBabySoC reference project](https://github.com/manili/VSDBabySoC) — design context.

---

