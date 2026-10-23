# 03 — Synthesis, Physical Design, GDSII, and Timing

This folder preserves the synthesis and physical-design artifacts for the EV charging controller. It contains the mapped standard-cell netlist, synthesis and OpenLane logs/configuration, TCL scripts, timing reports, extracted parasitics, Magic layout database, GDSII files, and the flow summary CSV.

## End-to-end implementation sequence

```text
Verified RTL
  → Yosys parsing, process conversion, optimization
  → Sky130 HD technology mapping
  → mapped netlist
  → gate-level simulation (GLS)
  → floorplanning and power planning
  → global placement and detailed placement
  → clock-tree synthesis (CTS)
  → global/detailed routing
  → parasitic extraction (SPEF)
  → setup/hold static timing analysis (STA)
  → available physical verification checks
  → GDSII export and layout inspection
```

The stages above describe the normal logical flow. Check the actual `openlane/run.log` and generated reports to establish exactly which stages completed for the archived run. A screenshot alone is not proof of a clean check.

## Directory and artifact guide

| Path | Purpose |
|---|---|
| `mapped_ev_charging_controller.v` | Technology-mapped Verilog netlist |
| `synth.log` | Yosys synthesis output and cell statistics |
| `openlane/config.tcl` | OpenLane flow configuration |
| `openlane/config.json` | JSON configuration copy/summary |
| `openlane/run.log` | Recorded OpenLane execution log |
| `results/ev_charging_controller.gds` | Generated GDSII layout artifact |
| `results/ev_charging_controller_magic.gds` | Additional Magic-exported GDSII artifact |
| `results/ev_charging_controller.spef` | Extracted parasitic data for timing analysis |
| `results/final_summary_report.csv` | OpenLane summary, metrics, and listed violation fields |
| `ev_charging_controller.mag` | Magic layout database |
| `render_layout.tcl` | Layout-rendering helper script |
| `check_25ns.tcl` | STA/check script; review the actual constraints before use |
| `run_full_sta.tcl` | Full timing analysis script |
| `run_multicorner_sta.tcl` | Multi-corner timing analysis script |
| `full_timing_report.log` | Captured timing report output |
| `timing_multicorner/summary.txt` | Compact setup/hold summary by corner |
| `timing_multicorner/*.log` | Per-corner timing logs |

## 1. Yosys synthesis and standard-cell mapping

Yosys reads the RTL, checks the hierarchy, lowers procedural logic, optimizes the logic, and synthesizes the design. Technology mapping translates generic logic into cells supported by the target library. The source netlist and mapped netlist serve different purposes: the source is behavioral RTL, while the mapped netlist contains technology-specific cell instances.

The synthesis log and screenshots under `../04_Evidence/02_Synthesis/` preserve evidence of the Yosys run and cell statistics. The PDK's Liberty file must match the intended Sky130 library and timing corner. Library paths in scripts should be updated for the local environment.

## 2. Gate-level simulation (GLS)

Before relying on a mapped netlist, simulate it with functional models of all referenced standard cells. Use the same testbench intent as RTL verification and compare the outputs. Timing-annotated GLS additionally needs an appropriate SDF file and simulator support. The mapped netlist is included, but a runnable GLS command depends on the actual PDK model paths available on the machine; see `../02_Verification/README.md`.

## 3. Floorplanning and power planning

Floorplanning establishes the die/core dimensions, aspect ratio, placement rows, and design boundary. The archived OpenLane configuration specifies the design name, Sky130A platform, standard-cell library, clock port/period, and selected floorplan/placement settings. Power planning creates the power-distribution network for power and ground. Inspect the full run log for exact stage outcomes and any warnings.

## 4. Placement

Global placement estimates cell locations and optimizes the placement solution. Detailed placement legalizes cell positions and resolves placement constraints. Review the global placement and placement-detail images in `../04_Evidence/03_Physical_Design/`. Cell density and placement appearance are useful context, but not sufficient to establish timing or design-rule correctness.

## 5. Clock-tree synthesis (CTS)

CTS builds the clock distribution network to deliver the clock to sequential cells with controlled skew and delay. The flow may insert clock buffers/inverters and perform timing-driven optimization. Review `clock_tree_synthesis_cts.png` in the evidence directory and the relevant OpenLane log section for stage completion and warnings.

## 6. Routing

Global routing estimates routes and congestion; detailed routing creates the final geometric connections using the available routing layers and design rules. The `routing_view.png` evidence shows the routed layout view. The flow summary reports zero for its listed TritonRoute violation field, but use the full log and the checks supported by the run to validate that result.

## 7. Parasitic extraction

The SPEF file records extracted or flow-generated interconnect parasitics. Timing analysis should use parasitics corresponding to the design revision and physical implementation being evaluated. Do not compare STA results generated from different netlists, constraints, or parasitic versions as if they were directly equivalent.

## 8. Static timing analysis (STA)

The supplied TCL scripts and logs support setup/hold analysis and a multi-corner summary. Before running them on another machine, check the paths to the Liberty libraries, netlist, SDC/constraints, and SPEF. Confirm the clock period, uncertainty, input/output delays, and PVT corner setup.

- **Setup slack:** positive slack indicates the analyzed setup path meets the specified constraint; negative slack indicates a setup violation.
- **Hold slack:** negative hold slack indicates a hold violation for the analyzed path/check group.
- **WNS:** worst slack in the analyzed group.
- **TNS:** total negative slack over violating paths.
- **Multi-corner STA:** checks timing under multiple PVT assumptions; all required corners must be evaluated.

The included `timing_multicorner/summary.txt` contains a negative setup slack at `ss_n40C_1v28` (-1.28 ns). Treat that corner as failing the zero-slack setup criterion in this report. Investigate and rerun STA before claiming all-corner timing closure.

## 9. GDSII and layout inspection

`results/ev_charging_controller.gds` is the generated GDSII file. `results/ev_charging_controller_magic.gds` is another GDSII artifact, and `ev_charging_controller.mag` is a Magic layout database. Open these with a compatible layout tool to inspect layers and geometry. Confirm which artifact corresponds to the intended final run before sharing it as the final layout.

A generated GDSII file by itself does not prove foundry sign-off. Check the available DRC, LVS, antenna, connectivity, and other required reports. The supplied flow summary lists zero values for several violation/error fields, but the scope of those checks is determined by the actual run configuration.

## 10. Reported metrics and caveats

The included `results/final_summary_report.csv` records:

- Flow status: `Flow_completed`
- Configured clock period: 20 ns
- Reported die area: 0.01 mm²
- Cell count: 96
- Zero in the listed TritonRoute, short, metal-spacing, off-grid, Magic, antenna, LVS, and CVC violation/error fields

These are archived report values and have not been regenerated during documentation updates. The separate multi-corner summary reports setup slack of -1.28 ns at `ss_n40C_1v28`, despite positive setup slack at the other listed corners. The report sets are not necessarily generated with identical constraints or parasitic assumptions; investigate the scripts and full logs before reconciling differences.

## Evidence

See `../04_Evidence/02_Synthesis/`, `../04_Evidence/03_Physical_Design/`, and `../04_Evidence/04_Timing_Analysis/` for screenshots of synthesis, placement, CTS, routing, layout/GDS viewing, and STA. Use the text reports for numeric values.

## Portability checklist

- Install compatible Yosys, OpenLane, Sky130A PDK, Magic/KLayout, and STA tools.
- Update machine-specific PDK/source paths in the configuration and TCL scripts.
- Confirm the Liberty corner and constraints match the intended analysis.
- Run functional simulation before synthesis; run GLS with matching standard-cell models after mapping.
- Re-run the full physical flow for a changed RTL or configuration.
- Re-run setup/hold STA for every required corner and resolve negative slack before claiming timing closure.
