# EV Charging Slot Availability and Smart Allocation Controller

A four-slot digital controller designed in Verilog HDL and taken through an RTL-to-GDSII implementation workflow using open-source digital-design tools and the Sky130A standard-cell platform. This repository documents the problem, architecture, RTL simulation, synthesis, gate-level verification guidance, physical-design stages, timing analysis, generated outputs, and visual evidence.

> **Project scope:** This is a digital control-logic prototype. It does not implement EV power conversion, charging-current control, payment, authentication, or a communications protocol.
>
> **Implementation status:** The included OpenLane summary reports `Flow_completed` and the repository contains GDSII, SPEF, Magic layout data, synthesis logs, and timing reports. A completed flow is not automatically equivalent to clean timing at every PVT corner or foundry sign-off. See the timing discussion below.

## Contents

- [Problem statement](#1-problem-statement)
- [Objectives](#2-objectives)
- [Controller functionality](#3-controller-functionality)
- [RTL-to-GDSII workflow](#4-rtl-to-gdsii-workflow)
- [Repository structure](#5-repository-structure)
- [Run RTL simulation and view GTKWave](#6-run-rtl-simulation-and-view-gtkwave)
- [Yosys synthesis](#7-yosys-synthesis)
- [Gate-level simulation](#8-gate-level-simulation-gls)
- [Physical-design stages](#9-physical-design-stages)
- [Static timing analysis](#10-static-timing-analysis)
- [Current results and limitations](#11-current-results-and-limitations)
- [Reproducibility](#12-reproducibility)
- [Evidence gallery](#13-evidence-gallery)

## 1. Problem statement

An EV charging station with several charging points needs to track which points are occupied, identify free points, allocate an eligible point to a reservation request, and release a reservation when cancellation is valid. The controller should avoid allocating a slot that is already occupied or reserved and should communicate whether a request was granted or rejected.

This project implements those decisions for **four charging slots** using synthesizable digital logic. Four occupancy inputs represent the observed slot states. Reservation and cancellation requests update the controller's registered state, while status outputs report availability and request outcomes. The design is intended to demonstrate a complete digital implementation process, from RTL design and verification through standard-cell mapping and physical implementation.

## 2. Objectives

1. Design a synthesizable Verilog controller for four EV charging slots.
2. Track occupancy and reservation state independently for each slot.
3. Calculate the number of available slots and indicate whether any slot is available or the station is full.
4. Select an eligible slot for a valid reservation request and report the assigned slot ID.
5. Support cancellation requests and report completion or rejection as defined by the RTL.
6. Verify expected behavior in simulation using a testbench and inspect signal transitions in GTKWave.
7. Synthesize the RTL with Yosys and map the design to Sky130 HD standard cells.
8. Preserve the mapped netlist, OpenLane configuration, physical-design artifacts, GDSII output, extracted parasitics, and timing reports.
9. Review timing at multiple process/voltage/temperature (PVT) corners and clearly document any corner that does not meet the timing target.

## 3. Controller functionality

The exact behavior and event priority are defined in `01_RTL_Design/ev_charging_controller.v`; the RTL source is authoritative if a summary below differs from an implementation detail.

| Signal | Width | Purpose |
|---|---:|---|
| `clk` | 1 | Clock input |
| `rst` | 1 | Reset input |
| `slot_sensor` | 4 | Occupancy sensor inputs for four slots |
| `slot_status` | 4 | Registered occupancy state |
| `reserved_status` | 4 | Reservation state for each slot |
| `sensor_valid` | 1 | Sensor/status validity indicator |
| `reserve_req` | 1 | Reservation request input |
| `cancel_req` | 1 | Cancellation request input |
| `cancel_slot_id` | 2 | ID of the slot to cancel |
| `assigned_slot_id` | 2 | ID of the selected slot |
| `available_count` | 3 | Number of available slots, 0–4 |
| `any_available` | 1 | Indicates at least one available slot |
| `station_full` | 1 | Indicates no slot is available |
| `grant` | 1 | Reservation accepted indicator |
| `reject` | 1 | Request rejection indicator |
| `cancel_done` | 1 | Cancellation completion indicator |

The intended behavior includes occupancy tracking, availability calculation, reservation allocation, cancellation handling, and request status reporting. Confirm corner cases against the RTL and self-checking testbench before making stronger functional claims.

## 4. RTL-to-GDSII workflow

The implementation flow is presented in the order below. The repository contains source, reports, and screenshots for the relevant milestones; the precise command sequence can vary with installed tool versions and the selected OpenLane version.

```mermaid
flowchart TD
    A[Problem statement and requirements] --> B[RTL design: Verilog]
    B --> C[RTL compile and functional simulation]
    C --> D[GTKWave: inspect RTL waveform]
    D --> E[Yosys synthesis and optimization]
    E --> F[Sky130 HD standard-cell mapping]
    F --> G[Gate-level simulation: mapped netlist + cell models]
    G --> H[GLS waveform inspection]
    H --> I[OpenLane physical-design flow]
    I --> J[Floorplanning and power planning]
    J --> K[Global placement and detailed placement]
    K --> L[Clock-tree synthesis (CTS)]
    L --> M[Global and detailed routing]
    M --> N[Parasitic extraction: SPEF]
    N --> O[Static timing analysis: setup and hold]
    O --> P[DRC/LVS and other available checks]
    P --> Q[GDSII export and layout inspection]
```

### Stage-by-stage explanation

1. **RTL design:** Describe the controller behavior at the register-transfer level in `01_RTL_Design/ev_charging_controller.v`.
2. **RTL simulation:** Compile the RTL with the testbench, run directed and randomized scenarios, and check the observed outputs against the reference model.
3. **GTKWave:** Open the generated VCD to inspect reset, slot sensors, reservation/cancellation requests, assigned slot, availability count, grant, reject, and cancellation acknowledgement over time.
4. **Yosys synthesis:** Parse the Verilog, process sequential/combinational logic, optimize the design, and report the resulting logic structure.
5. **Technology mapping:** Map generic logic to cells from the Sky130 HD library. The mapped netlist and synthesis log are preserved in `03_Synthesis_Physical_Design/`.
6. **Gate-level simulation (GLS):** Simulate the mapped netlist with compatible functional models for the mapped standard cells and a suitable testbench. Compare behavior with RTL simulation; timing-annotated GLS additionally requires valid delay data and simulator support.
7. **Floorplan and power planning:** Establish the die/core region, I/O and pin strategy, row structure, and power-distribution network according to the selected flow configuration.
8. **Placement:** Place standard cells, then optimize placement and timing as supported by the flow.
9. **Clock-tree synthesis:** Build and balance the clock distribution network for sequential elements.
10. **Routing:** Connect signal and clock nets using the process routing layers and design rules.
11. **Parasitic extraction:** Extract estimated or routed interconnect parasitics, commonly represented in SPEF, for timing analysis.
12. **Static timing analysis:** Check setup and hold paths against the clock and constraints, ideally across the required PVT corners.
13. **Physical checks and GDSII:** Review available DRC/LVS/antenna and other checks, export the layout database, and inspect the final GDSII in a layout viewer. Only claim sign-off for checks that were actually run and passed.

## 5. Repository structure

```text
EV-Charging-Slot-Controller/
├── README.md
├── .gitignore
├── 01_RTL_Design/
│   ├── README.md
│   └── ev_charging_controller.v
├── 02_Verification/
│   ├── README.md
│   └── tb_ev_charging_controller.v
├── 03_Synthesis_Physical_Design/
│   ├── README.md
│   ├── mapped_ev_charging_controller.v
│   ├── synth.log
│   ├── full_timing_report.log
│   ├── check_25ns.tcl
│   ├── run_full_sta.tcl
│   ├── run_multicorner_sta.tcl
│   ├── render_layout.tcl
│   ├── ev_charging_controller.mag
│   ├── openlane/
│   ├── results/
│   └── timing_multicorner/
└── 04_Evidence/
    ├── README.md
    ├── 01_RTL_and_Verification/
    ├── 02_Synthesis/
    ├── 03_Physical_Design/
    └── 04_Timing_Analysis/
```

## 6. Run RTL simulation and view GTKWave

Install Icarus Verilog and GTKWave in your Linux environment. From the repository root:

```bash
mkdir -p build
iverilog -g2012 -o build/ev_rtl_sim \
  01_RTL_Design/ev_charging_controller.v \
  02_Verification/tb_ev_charging_controller.v
vvp build/ev_rtl_sim
```

The testbench contains a VCD dump statement. Check its `$dumpfile(...)` name and the current working directory to find the generated waveform file. Then open it, for example:

```bash
gtkwave ev_charging_demo.vcd
```

If the VCD is written to a different path or has a different name, use that actual path. In GTKWave, add the DUT signals and group related signals so the waveform can be read as a transaction: reset, occupancy, reservation request, grant/reject, cancellation request, cancellation completion, and available count.

## 7. Yosys synthesis

The repository retains the synthesis log, mapped netlist, and screenshots of the Yosys run and cell statistics. A basic RTL parsing and synthesis check can be performed with Yosys as follows:

```text
read_verilog 01_RTL_Design/ev_charging_controller.v
hierarchy -check -top ev_charging_controller
proc
opt
check
synth -top ev_charging_controller
stat
```

For technology mapping, load the correct Sky130 HD Liberty file and use the mapping flow appropriate for the installed Yosys/PDK version. The example above is a generic synthesis outline, not a replacement for the recorded technology-mapping flow. The exact PDK library path is machine-dependent.

Useful artifacts:

- `03_Synthesis_Physical_Design/synth.log` — recorded synthesis log.
- `03_Synthesis_Physical_Design/mapped_ev_charging_controller.v` — mapped standard-cell netlist.
- `04_Evidence/02_Synthesis/` — synthesis and cell-statistics screenshots.

## 8. Gate-level simulation (GLS)

GLS verifies the mapped netlist rather than the behavioral RTL. To run a valid gate-level simulation, you need all of the following:

- The mapped netlist in `03_Synthesis_Physical_Design/mapped_ev_charging_controller.v`.
- The same testbench or a GLS-compatible testbench with matching top-level ports.
- Functional Verilog models for every Sky130 cell instantiated by the netlist.
- Correct compile ordering and any required simulator options.

A generic command template is shown below; replace the cell-model path with the actual functional-model file(s) from your installed Sky130 PDK:

```bash
iverilog -g2012 -s tb_ev_charging_controller -o build/ev_gls_sim \
  <sky130_functional_cell_models.v> \
  03_Synthesis_Physical_Design/mapped_ev_charging_controller.v \
  02_Verification/tb_ev_charging_controller.v
vvp build/ev_gls_sim
```

This is a template, not a guaranteed one-command run: standard-cell model filenames and compilation requirements differ by PDK installation. If the netlist uses escaped identifiers or cells with unsupported constructs, resolve those simulator-specific issues. For timing-annotated GLS, use a compatible SDF file and simulator annotation support; do not call a functional-only run timing-annotated GLS.

Open the VCD produced by the GLS testbench in GTKWave and compare it against the RTL waveform. The screenshots document the simulation evidence available in this repository; retain a separate, clearly named GLS VCD or screenshot when you capture a verified GLS run.

## 9. Physical-design stages

The OpenLane configuration and run log are in `03_Synthesis_Physical_Design/openlane/`. The physical-design screenshots are grouped in `04_Evidence/03_Physical_Design/`.

| Stage | What it does | Evidence / related artifact |
|---|---|---|
| Floorplanning | Defines die/core geometry, rows and initial implementation context | OpenLane configuration and physical-design screenshots |
| Power planning | Creates the power-distribution network (PDN) for power/ground | Layout screenshots; inspect detailed flow logs for the exact stage status |
| Global placement | Estimates cell positions and optimizes placement | `global_placement.png` |
| Detailed placement | Legalizes and refines cell locations | `placement_detail.png` |
| Clock-tree synthesis (CTS) | Inserts/balances clock-tree cells and routes the clock network | `clock_tree_synthesis_cts.png` |
| Routing | Connects signal nets using routing resources | `routing_view.png` |
| Parasitic extraction | Extracts interconnect resistance/capacitance for analysis | `results/ev_charging_controller.spef` |
| Layout database / GDSII | Preserves the physical layout for viewing and downstream use | `ev_charging_controller.mag`, `results/*.gds` |
| Physical verification | Runs the checks supported by the configured flow | `results/final_summary_report.csv` and OpenLane log |

The exact order and implementation of individual steps can vary by OpenLane version and configuration. Consult `openlane/run.log` and the generated summary rather than inferring that a stage passed from a screenshot alone.

### Layout and GDSII files

- `results/ev_charging_controller.gds` — generated GDSII artifact.
- `results/ev_charging_controller_magic.gds` — additional Magic-exported GDSII artifact.
- `ev_charging_controller.mag` — Magic layout database.
- `results/ev_charging_controller.spef` — extracted parasitic data.

GDSII is a physical layout database, not a source file that can be meaningfully reviewed as plain text. Use a compatible layout viewer such as Magic or KLayout to inspect it. Confirm that the stream-out corresponds to the intended final database and that the required checks have been run before describing it as sign-off ready.

## 10. Static timing analysis

The repository includes a full STA report, TCL scripts, a multi-corner summary, and screenshots. Timing is meaningful only with the constraints, Liberty corner, parasitic data, and timing-analysis setup that produced the report.

- **Setup analysis** checks whether data arrives early enough before the receiving register's active clock edge.
- **Hold analysis** checks whether data remains stable long enough after the active clock edge.
- **WNS (worst negative slack)** identifies the worst slack for the analyzed check group.
- **TNS (total negative slack)** aggregates negative slack over violating paths.
- **Multi-corner STA** evaluates the design under multiple process, voltage, and temperature assumptions; a pass at one corner does not imply a pass at all corners.

Timing artifacts:

- `full_timing_report.log`
- `timing_multicorner/summary.txt`
- `timing_multicorner/*.log`
- `run_full_sta.tcl`
- `run_multicorner_sta.tcl`
- `04_Evidence/04_Timing_Analysis/`

Before rerunning, inspect the TCL scripts for paths to the PDK, Liberty files, netlist, SDC/constraints, and SPEF. Update those paths for your environment. Preserve the exact corner name, voltage, temperature, clock period, setup slack, and hold slack when presenting timing results.

## 11. Current results and limitations

The included `results/final_summary_report.csv` records the OpenLane flow status as `Flow_completed`, a 20 ns configured clock period, a reported die area of `0.01 mm²`, and 96 cells. It also reports zero for the listed TritonRoute, short, metal-spacing, off-grid, Magic, antenna, LVS, and CVC violation fields in that summary row. These are values recorded in the supplied report; they have not been independently regenerated as part of preparing this repository.

The separate multi-corner summary includes the following setup-slack results:

| Corner | Setup slack (ns) | Hold slack (ns) |
|---|---:|---:|
| `ff_100C_1v65` | 18.13 | 0.32 |
| `ff_n40C_1v76` | 18.22 | 0.27 |
| `ss_100C_1v40` | 12.70 | 1.43 |
| `ss_n40C_1v28` | **-1.28** | 3.26 |
| `ss_n40C_1v40` | 8.70 | 1.90 |
| `tt_025C_1v80` | 17.62 | 0.42 |
| `tt_100C_1v80` | 17.69 | 0.42 |

The table above lists representative corners; see `timing_multicorner/summary.txt` for the full set. In the recorded multi-corner summary, `ss_n40C_1v28` has **negative setup slack (-1.28 ns)**. That corner therefore does not meet a zero-slack setup criterion in that report. Do not state that timing is closed at every corner until the constraint/model/report discrepancy or design timing issue has been investigated and the relevant STA rerun passes. Also verify whether the single-run OpenLane summary and the separate multi-corner analysis use equivalent constraints and parasitic data before comparing their numbers.

## 12. Reproducibility

Tool and PDK versions affect synthesis mapping, placement, routing, and STA results. To make the repository easier for another engineer to reproduce:

1. Record OS, tool versions, PDK revision, and standard-cell library corner names.
2. Review `openlane/config.tcl` and `openlane/config.json` for absolute paths or environment assumptions.
3. Ensure the source RTL and timing constraints are the versions used to generate the included artifacts.
4. Run RTL simulation and save the simulator output and VCD.
5. Re-run synthesis and compare the new cell statistics and mapped netlist.
6. Re-run the physical-design flow and retain the complete log, summary, and GDSII.
7. Re-run setup/hold STA for every required PVT corner and report any failing paths.
8. Do not commit huge temporary run directories unless they are needed for reproducibility; keep the final deliverables and evidence instead.

## 13. Evidence gallery

### RTL and verification

- [RTL syntax / simulation]<img width="1920" height="983" alt="rtl_syntax_and_simulation" src="https://github.com/user-attachments/assets/15029fa9-f3c6-45cd-a66b-1f41c0d72b9a" />


- [RTL waveform demo]<img width="1920" height="983" alt="rtl_waveform_demo" src="https://github.com/user-attachments/assets/5d285690-71ef-470e-8e14-7c5738ebc3ae" />

- [Testbench waveform]<img width="1920" height="983" alt="testbench_waveforms" src="https://github.com/user-attachments/assets/649d8ce6-f24f-445f-9ade-d36baa23b37a" />

- [Extended controller waveform]<img width="1920" height="983" alt="controller_waveforms_extended" src="https://github.com/user-attachments/assets/57bc7e4b-a26e-4249-8bd6-d21d71a38b7e" />


### Synthesis

- [Yosys synthesis run]<img width="1920" height="983" alt="yosys_synthesis_run" src="https://github.com/user-attachments/assets/75ca9088-2c66-4e44-896c-10b443b34e17" />

- [Yosys statistics]<img width="1920" height="983" alt="yosys_statistics" src="https://github.com/user-attachments/assets/80e32189-a68c-49c7-b21b-1ecd30f0dd64" />

- [Standard-cell statistics]<img width="1920" height="983" alt="standard_cell_statistics" src="https://github.com/user-attachments/assets/79a76025-2059-4cf1-ad9c-430815f099bf" />

- [Synthesis cell mapping]<img width="1920" height="983" alt="synthesis_cell_mapping" src="https://github.com/user-attachments/assets/e6ffbd13-688b-4cfd-ab3d-07e1a7b5e460" />
<img width="1920" height="983" alt="synthesis_netlist_view" src="https://github.com/user-attachments/assets/f2b79561-0271-4959-9c25-91ea31d3f5e6" />


### Physical design and timing

- [Global placement]<img width="1280" height="768" alt="global_placement" src="https://github.com/user-attachments/assets/ef9c75b7-c762-407f-9478-83ebb009d3cb" />

- [Clock-tree synthesis]<img width="1280" height="768" alt="clock_tree_synthesis_cts" src="https://github.com/user-attachments/assets/96f1eb92-e952-4057-9165-5a4881ab3f70" />

- [Routing view]<img width="1280" height="768" alt="routing_view" src="https://github.com/user-attachments/assets/a76d85f4-100b-486c-b7cf-323a5dd62acd" />

- [Final layout view]<img width="1280" height="768" alt="final_layout_view" src="https://github.com/user-attachments/assets/9a9205c5-94c3-407d-8ddc-135c162ed50b" />

- [GDS layout viewer](<img width="1280" height="768" alt="gds_layout_viewer" src="https://github.com/user-attachments/assets/f59668e3-f290-41fa-a42c-05ffa1be480b" />

- [Static timing report]<img width="1280" height="768" alt="static_timing_report" src="https://github.com/user-attachments/assets/972adcff-e9dd-4e24-81ba-d20d5c5deff9" />

- [Setup/hold report]<img width="1280" height="768" alt="setup_hold_timing_report" src="https://github.com/user-attachments/assets/049a3d95-ede0-47dd-9349-de6d04416eae" />

- [Multi-corner STA summary]
## Tools and technology

- Verilog HDL
- Icarus Verilog — RTL/GLS simulation
- GTKWave — waveform inspection
- Yosys — RTL synthesis and logic optimization
- OpenLane — RTL-to-GDSII flow orchestration
- Sky130A / `sky130_fd_sc_hd` — standard-cell platform
- Magic and KLayout — layout/GDSII inspection (as available in the environment)
- Static timing analysis scripts and multi-corner reports

