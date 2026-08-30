# Stage 5 – Synthesis

Yosys script targeting Sky130 (`sky130_fd_sc_hd__tt_025C_1v80.lib`):
see [`yosys-synthesis-and-post-synth-sim-commands.png`]<img width="1024" height="1536" alt="ChatGPT Image Aug 30, 2026, 10_32_16 PM" src="https://github.com/user-attachments/assets/f31ba8e6-24d2-4a51-89e6-d3193f5ce005" />


Three netlists are written at different points in the flow:
- `baby_soc_netlist.v` — right after `abc` technology mapping
- `baby_soc_netlist1.v` — after `flatten`
- `baby_soc_netlist2.v` — final, after `setundef -zero` / `clean -purge` / `rename -enumerate` — this is the netlist used in GLS (Stage 6)

ABC mapping results and final `stat`/`check` output:
- [`abc-mapping-results-1.png`]<img width="1920" height="983" alt="abc-mapping-results-1" src="https://github.com/user-attachments/assets/9c39236d-eed9-4831-98bb-dd8cfe8f3245" />

- [`abc-mapping-results-2.png`]<img width="1920" height="983" alt="abc-mapping-results-2" src="https://github.com/user-attachments/assets/ff0e1f75-80e8-4f5a-b770-75de27ee6118" />

- [`hierarchy-pass-stat.png`]<img width="1920" height="983" alt="hierarchy-pass-stat" src="https://github.com/user-attachments/assets/8bad3abf-283b-49fe-ae8b-5b697d9e5d82" />

- [`post-synth-stat-1.png`]<img width="1920" height="983" alt="post-synth-stat-1" src="https://github.com/user-attachments/assets/33990096-98fe-4242-8301-b009152721b9" />

- [`post-synth-stat-2.png`]<img width="1920" height="983" alt="post-synth-stat-2" src="https://github.com/user-attachments/assets/6ad6297a-6a42-4ecb-83db-af316ca12ace" />

- [`full-chip-schematic-dot-viewer.png`]<img width="1920" height="983" alt="full-chip-schematic-dot-viewer" src="https://github.com/user-attachments/assets/d18730e0-ebb5-40bd-b28f-e4c33a2393d3" />



