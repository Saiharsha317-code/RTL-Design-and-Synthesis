# Stage 7 – GLS Problem and Debugging

**Problem:** early GLS runs showed flat/constant signals (`ENb_CP`, `VREFH`, parts of `RV_TO_DAC`) instead of the toggling pattern seen in functional simulation.
See [`gls-waveform-issue.png`]<img width="1362" height="362" alt="image" src="https://github.com/user-attachments/assets/ee56d932-e687-40b4-ae49-1d53d2b88568" />


## sky130-library-approach/
Debugging attempt using an external Sky130 library path from a *different* workshop's directory, which failed with a syntax error at `sky130_fd_sc_hd.v:74452` (an `` `endif `` line with a trailing macro name inside the `sky130_fd_sc_hd__lpflow_bleeder` cell model). See [`sky130-library-approach/sky130_fd_sc_hd-line-74452.png`]<img width="1920" height="983" alt="sky130_fd_sc_hd-line-74452" src="https://github.com/user-attachments/assets/d0169c09-7b90-412a-9ac4-7980e6aab75a" />


**Root cause identified:** the wrong (external, non-BabySoC) Sky130 library path was being used for compilation.

## vvp-approach/
Once the correct, BabySoC-repo-local include paths (`src/include`, `src/module`, `src/gls_model`) were used, `iverilog` + `vvp` completed cleanly and produced a valid `post_synth_sim.vcd`. See [`vvp-approach/terminal-debug-sequence.png`]<img width="1920" height="983" alt="VirtualBox_vsdworkshop1_30_08_2026_22_52_03" src="https://github.com/user-attachments/assets/d89efd22-d74e-442a-bd7d-bb532bb3f42b" />

