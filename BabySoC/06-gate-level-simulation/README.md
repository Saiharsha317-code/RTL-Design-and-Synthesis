# Stage 6 – Gate-Level Simulation (GLS)

```bash
iverilog -o ./post_synth_sim.out -DPOST_SYNTH_SIM -DFUNCTIONAL -I src/include -I src/module -I src/gls_model src/module/testbench.v
vvp post_synth_sim.out
gtkwave post_synth_sim.vcd
```

- [`stat-vsdbabysoc-cells.png`]<img width="1920" height="983" alt="stat-vsdbabysoc-cells" src="https://github.com/user-attachments/assets/59f54e92-194f-4598-97c5-a7d5512c1aec" />
 — final cell/hierarchy stats
- [`stat-check-pass-0-problems.png`]<img width="1920" height="983" alt="stat-check-pass-0-problems" src="https://github.com/user-attachments/assets/bcf8d38a-077d-4445-8121-8e76835e628e" />
 — Yosys `check` pass, 0 problems reported

 waveform:<img width="1920" height="983" alt="simulation_of_gls_and_functiional" src="https://github.com/user-attachments/assets/8d00d4f3-b197-4384-a367-83514b5a1c28" />


See [`../07-gls-debugging/`](../07-gls-debugging/) for the waveform issue encountered and how it was resolved.
