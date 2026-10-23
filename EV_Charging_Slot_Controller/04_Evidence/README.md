# 04 — Project Evidence and Screenshots

This directory collects visual evidence from the EV Charging Slot Availability and Smart Allocation Controller project. The screenshots help a reviewer follow the design's progress from RTL simulation through synthesis, physical design, GDSII viewing, and timing analysis.

> Screenshots show what was displayed in the tool at capture time. Use the corresponding source files, run logs, and reports to validate exact results. Do not infer a passed DRC/LVS/timing check from a layout screenshot alone.

## Evidence sequence

The intended review sequence is:

**RTL source and functional simulation → GTKWave RTL waveform → Yosys synthesis and mapped-cell statistics → gate-level simulation (GLS) waveform → floorplanning and power planning → global/detailed placement → clock-tree synthesis (CTS) → routing → parasitic extraction → setup/hold and multi-corner STA → final layout/GDSII inspection.**

## 01 — RTL and verification

Folder: `01_RTL_and_Verification/`

- <img width="1920" height="983" alt="rtl_syntax_and_simulation" src="https://github.com/user-attachments/assets/ff64f9c9-8905-4d96-ab49-2ffa53d628a4" />
 — RTL compile/simulation terminal evidence.
- <img width="1920" height="983" alt="rtl_waveform_demo" src="https://github.com/user-attachments/assets/3a263e24-712b-4ba6-ba0b-9fb9e88c782b" />
  — waveform view of the controller's signals.
- <img width="1920" height="983" alt="testbench_waveforms" src="https://github.com/user-attachments/assets/c111e7b4-01b0-4480-92e9-05f71e6f5e79" />
  — testbench waveform evidence.
- <img width="1920" height="983" alt="controller_waveforms_extended" src="https://github.com/user-attachments/assets/9d453f4e-b902-4e61-b778-b5b6b1cbf2d6" />
 — extended waveform activity.

These images help show reset behavior, sensor inputs, reservation/cancellation requests, slot status, availability count, and response signals. The actual testbench and simulator output determine whether checks passed.

## 02 — Synthesis

Folder: `02_Synthesis/`

- <img width="1920" height="983" alt="yosys_synthesis_run" src="https://github.com/user-attachments/assets/f67e294a-399e-4194-96a0-5920e544c914" />
 — Yosys synthesis session.
- <img width="1920" height="983" alt="yosys_statistics" src="https://github.com/user-attachments/assets/7acbb8b5-cc97-4f20-b4f5-e4c36390c270" />
 and <img width="1920" height="983" alt="yosys_statistics_detail" src="https://github.com/user-attachments/assets/b24dcc8c-5633-41c7-9b02-f16ebc9bc039" />
` — synthesis statistics.
- <img width="1920" height="983" alt="yosys_mapped_cell_statistics" src="https://github.com/user-attachments/assets/b0d6fa62-09f4-4b09-af00-a2bf8e704525" />
 and <img width="1920" height="983" alt="standard_cell_statistics" src="https://github.com/user-attachments/assets/58cea32f-fdcd-4bc3-8e7e-abcd8ee6aed2" />
 — mapped-cell counts.
- <img width="1920" height="983" alt="synthesis_cell_mapping" src="https://github.com/user-attachments/assets/33b1e9b6-9111-4ef8-9cf5-dc4d57d21c36" />
 — standard-cell mapping evidence.
- <img width="1920" height="983" alt="synthesis_netlist_statistics" src="https://github.com/user-attachments/assets/68e4d176-c056-4477-83ac-ee65cb40d080" />
 and <img width="1920" height="983" alt="synthesis_netlist_view" src="https://github.com/user-attachments/assets/669a7f19-7d19-4eb4-bd4a-dfe2a6e2bc2c" />
 — netlist statistics and visualization.

For reproducible metrics, compare the images with `../03_Synthesis_Physical_Design/synth.log` and `mapped_ev_charging_controller.v`.

## 03 — Physical design

Folder: `03_Physical_Design/`

- <img width="1280" height="768" alt="physical_design_stage" src="https://github.com/user-attachments/assets/8fc44cb7-f51c-409e-b6eb-0559bb6c24c0" />
 and `<img width="1280" height="768" alt="physical_design_session" src="https://github.com/user-attachments/assets/cb26b628-4f02-4239-9bf5-392a066d634f" />
 — physical-design tool/session evidence.
- <img width="1280" height="768" alt="global_placement" src="https://github.com/user-attachments/assets/4137bd41-1972-4292-9ce3-f396e8416cd2" />
 and <img width="1280" height="768" alt="placement_detail" src="https://github.com/user-attachments/assets/d9a4111c-7665-4e5c-a785-2e8762533452" />
 — placement views.
- <img width="1280" height="768" alt="clock_tree_synthesis_cts" src="https://github.com/user-attachments/assets/dc09c91c-3ea8-411d-8261-25e8caf0196c" />
 — CTS stage evidence.
- <img width="1280" height="768" alt="routing_view" src="https://github.com/user-attachments/assets/99ab31ca-4352-483c-b2e5-d8f0a48aaff0" />
 — routing view.
- <img width="1280" height="768" alt="physical_design_layout_full" src="https://github.com/user-attachments/assets/a3c515cc-11e5-42fb-ab1f-8636c1865d47" />
, <img width="1280" height="768" alt="physical_design_layout_zoom" src="https://github.com/user-attachments/assets/2b9d689a-7aa2-4d57-b5f3-a7bf4244323c" />
, <img width="1280" height="768" alt="magic_layout_overview" src="https://github.com/user-attachments/assets/58014bc4-7d92-4824-8258-d960eef58653" />
, and <img width="1280" height="768" alt="layout_detail_stage" src="https://github.com/user-attachments/assets/5ff46eb0-4d9c-4dfa-baa4-95c68142cbfd" />
` — layout views at different scales.
- <img width="1280" height="768" alt="gds_layout_viewer" src="https://github.com/user-attachments/assets/5e1ba47e-8747-4c42-b5d0-cd75317f5137" />
and <img width="1280" height="768" alt="final_layout_view" src="https://github.com/user-attachments/assets/2540d2ad-d94a-4947-8c31-710701110f55" />
 — GDS/layout inspection.
- <img width="1280" height="768" alt="layout_stage_finalization" src="https://github.com/user-attachments/assets/a987bc19-5680-43c4-8be4-c9ef496f0e84" />
, <img width="1280" height="768" alt="layout_detail_stage" src="https://github.com/user-attachments/assets/9120073b-cdb7-46a3-b9b9-20af639c9cdf" />
`, <img width="1920" height="983" alt="physical_design_tool_session" src="https://github.com/user-attachments/assets/fbaa44f3-17bf-492f-97a3-d7dd9080ef13" />
`, and<img width="1920" height="983" alt="netlist_graph_overview" src="https://github.com/user-attachments/assets/67bf62a0-09ed-464a-8a74-1b5050b0cd5e" />
— supporting tool and implementation views.

The associated layout database and GDSII files are in `../03_Synthesis_Physical_Design/`. The OpenLane run log should be consulted for stage status and warnings.

## 04 — Timing analysis

Folder: `04_Timing_Analysis/`

- <img width="1280" height="768" alt="static_timing_report" src="https://github.com/user-attachments/assets/39826cb1-cab9-4f40-bb7e-741d4568bb53" />
 — static timing report view.
- <img width="1280" height="768" alt="setup_hold_timing_report" src="https://github.com/user-attachments/assets/7ddf3964-391e-4ddc-a12d-c73579d32d20" />
 — setup/hold analysis view.
- <img width="1280" height="768" alt="multicorner_sta_summary" src="https://github.com/user-attachments/assets/32a202fe-e918-4dc3-a59c-a52b20859e56" />
 — multi-corner timing summary.

The corresponding text artifacts are `../03_Synthesis_Physical_Design/full_timing_report.log`, `../03_Synthesis_Physical_Design/timing_multicorner/summary.txt`, and the per-corner logs. The recorded summary includes negative setup slack (-1.28 ns) at `ss_n40C_1v28`. Therefore, these screenshots should not be presented as proof of all-corner timing closure.

## GLS evidence note

The repository's verification screenshots show simulation waveforms, but a waveform screenshot should be labelled **GLS** only when it was captured from the technology-mapped netlist with the required standard-cell functional models (and SDF if timing-annotated GLS is claimed). If you have a dedicated GLS waveform or transcript, add it to `01_RTL_and_Verification/` with a descriptive filename such as `gls_waveform.png` and document the exact simulation command in `02_Verification/README.md`.


