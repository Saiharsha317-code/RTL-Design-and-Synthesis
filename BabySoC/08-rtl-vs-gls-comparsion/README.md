# Stage 8 – RTL vs GLS Comparison

Side-by-side GTKWave comparison of `pre_synth_sim.vcd` and `post_synth_sim.vcd` on the `RV_TO_DAC[9:0]` bus:
see [`pre-vs-post-synth-waveform-comparison.png`]<img width="1920" height="983" alt="pre-vs-post-synth-waveform-comparison" src="https://github.com/user-attachments/assets/6c9cfaf1-7ac7-4f39-810a-b2914adeb797" />


**Result:** both simulations produced the same output — the GLS waveform matched the functional simulation waveform over the full run. This confirms the synthesized gate-level implementation is functionally correct.
