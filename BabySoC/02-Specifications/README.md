# Stage 2 – Specification Analysis

Reference: [`vsdbabysoc-architecture.png`]<img width="2270" height="1260" alt="babysoc_archi" src="https://github.com/user-attachments/assets/ddb7d564-cce6-4b42-a293-8bcfd993ffef" />


Key architectural points used to guide the RTL/testbench review:
- Digital core (`rvmyth`) + analog PLL (`avsdpll_1v8`) + analog DAC (`avsddac_3v3`)
- 1.8V and 3.3V voltage domains connected via level shifters
- `rvmyth` drives a 10-bit bus into the DAC, producing the analog `OUT`
