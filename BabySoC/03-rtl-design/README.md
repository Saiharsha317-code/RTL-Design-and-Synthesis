# Stage 3 – RTL Design

Reference: [`testbench-and-rvmyth-includes.png`]<img width="1920" height="983" alt="testbench-and-rvmyth-includes" src="https://github.com/user-attachments/assets/f29510b8-5fdb-42e8-b62c-2da008776c3d" />


- `testbench.v` conditionally includes RTL sources (`PRE_SYNTH_SIM`) or the synthesized netlist + Sky130 models (`POST_SYNTH_SIM`).
- `rvmyth` (generated via TL-Verilog) exposes `OUT[9:0]`, `CLK`, `reset`.
- Testbench module `vsdbabysoc_tb` drives `reset`, `VCO_IN`, `ENb_CP`, `ENb_VCO`, `REF`, `VREFL`, `VREFH` and observes `OUT`.
