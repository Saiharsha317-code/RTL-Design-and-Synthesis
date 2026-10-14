# OpenLANE `picorv32a`: Power Grid, DRC and Final Report

Final stages of the `picorv32a` flow run `RUN_MOD5_CLEAN` in OpenLANE: power distribution network (PDN) generation,
Magic design-rule check, the final summary report, and a timing check.

## Flow

```
CTS result ──► PDN generation ──► Magic reads design ──► DRC (clean) ──► Final summary report
                                                                              │
                                                                  Timing check (ideal clock)
```

## 1. Power distribution network (PDN)

![pdn]<img width="2522" height="1510" alt="1-pdn-generation" src="https://github.com/user-attachments/assets/125d1252-d2b3-4722-a627-0f5ea730e835" />


* The PDN step builds the power and ground grid (stripes and rails) that supplies every cell.
* The ground net (VSS) is analysed with a conductance ("G") matrix: **19 223 nodes** on net VSS, and all PDN nodes are connected.
* `PSM-0030` warnings report that planned supply-source points (10 µm wide) were not on a power stripe, so they were moved to the closest stripe,
  for example from (5.52, 10.88) µm to (5.4, 107.18) µm.
* Result: **PDN generation was successful**. The layout moved from `results/cts/picorv32a.cts.def` to `tmp/floorplan/17-pdn.def`.

## 2. Magic loads the design

![magic reading]<img width="2520" height="1492" alt="2-magic-reading-cells" src="https://github.com/user-attachments/assets/b5bef252-4250-48cb-9d2c-63b398884fbb" />


* Magic reads every standard cell (`sky130_fd_sc_hd__…`) before running the check.
* CIF warnings: units rescaled by a factor of 5/1, and input off the lambda grid by 3/5 and snapped to the grid. This is the normal grid conversion when reading the layout.

## 3. DRC and final summary

![drc and summary]<img width="2522" height="1514" alt="3-drc-clean-and-final-summary" src="https://github.com/user-attachments/assets/593fd0c1-3caa-43f9-9dd9-aeee6f911c1c" />


| Check | Result |
|---|---|
| Magic DRC (`drc(full)` style) | No errors found, **COUNT: 0** |
| DRC after GDS streaming | No violations |
| Total runtime | **0 h 6 m 25 s** |
| Final summary: Magic DRC | **Total violations = 0** |
| Final summary: LVS | Source not found |
| Final summary: Antenna | No antenna report found |

The full table is written to `reports/final_summary_report.csv`.

## 4. Timing check (ideal clock)

![sta]<img width="2516" height="1482" alt="4-sta-ideal-clock-slack" src="https://github.com/user-attachments/assets/2058a533-66f8-4b45-b8db-4b06727589ca" />


* The path ends at flop `_27606_/D` after a chain of `or2_1` / `or2_2` gates (about 0.5–0.7 ns each).
* Clock edge **24.73 ns**, library setup time −0.28 ns → **required time 24.45 ns**.
* Data **arrival time 25.11 ns**.
* **Slack = 24.45 − 25.11 = −0.66 ns (VIOLATED)**.

## Key numbers

| Item | Value |
|---|---|
| Run name | `RUN_MOD5_CLEAN` |
| Nodes on VSS net | 19 223 |
| Magic DRC violations | 0 |
| Flow runtime | 6 min 25 s |
| Clock period (STA) | 24.73 ns |
| Setup slack (ideal clock) | −0.66 ns |

## Glossary

| Term | Meaning |
|---|---|
| **PDN** | grid of power and ground wires that supplies all cells |
| **DRC** | design-rule check: is the layout manufacturable? |
| **LVS** | layout vs schematic: does the layout match the circuit? |
| **Antenna check** | looks for long metal that could damage a gate during manufacturing |
| **Slack** | timing margin; negative means the path is too slow |
