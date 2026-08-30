# Stage 4 – Functional (Pre-Synthesis) Simulation

```bash
iverilog -o ./pre_synth_sim.out -DPRE_SYNTH_SIM src/module/testbench.v -I src/include -I src/module/
./pre_synth_sim.out
gtkwave pre_synth_sim.vcd
```

See [`pre-synth-sim-terminal.png`]<img width="1920" height="983" alt="pre-synth-sim-terminal" src="https://github.com/user-attachments/assets/60409bd9-96a8-4aa4-b2f8-90c5a28186a6" />
 Completed successfully, producing the reference `pre_synth_sim.vcd` used later for GLS comparison.

waveform:<img width="1920" height="983" alt="day3_gls_simulation_withoutanychanges" src="https://github.com/user-attachments/assets/763714c3-a97a-4774-95c6-de63b65e45a2" />

