# Hands-On ASIC Physical Design with OpenLane — picorv32a

## About this document

This is a record of my own hands-on work exploring the OpenLane RTL-to-GDSII flow, using the `picorv32a` RISC-V core as the design under test. Everything here reflects what I actually did on my machine, backed by terminal screenshots I captured while working through the flow. Where I'm describing a concept rather than something I directly ran and observed, I've been careful to say so explicitly rather than blur the line.

My goal with this project was to move past reading about ASIC physical design and actually get my hands on the tools — set up the environment myself, run the flow, look at the actual reports it generates, and understand *why* each piece exists rather than just what it's called.

---

## 1. Setting Up the Environment

Before I could run anything, I had to get familiar with how OpenLane is organized on disk and how it uses the SkyWater 130nm (sky130) PDK.

### Exploring the PDK structure

I started by navigating through the PDK directory tree myself to understand what OpenLane actually depends on.

[PDK libs.tech toolset]<img width="1272" height="652" alt="02_pdk_libstech_toolset" src="https://github.com/user-attachments/assets/6a62d91d-1c64-4f27-995e-823a58af01c5" />


*This screenshot is evidence of me exploring `pdks/sky130A/libs.tech/`, where I found subfolders for the different tools OpenLane stitches together — `magic`, `netgen`, `klayout`, `openlane`, `qflow`, `xschem`, and others. Before this, I only knew "OpenLane uses Magic and Netgen" as a fact from reading. Seeing the actual directory laid out helped me understand that OpenLane isn't one monolithic tool — it's an orchestration flow that calls a chain of separate, independent open-source tools (synthesis engine, placer, router, DRC/LVS tools, etc.), each of which has its own configuration under this tech library path.*

[PDK libs.ref sky130_fd_sc_hd]<img width="1285" height="657" alt="03_pdk_libsref_sky130_fd_sc_hd" src="https://github.com/user-attachments/assets/bdf449d8-9c2b-49a5-9efe-a3a7f16af544" />


*Here I drilled further into `libs.ref/sky130_fd_sc_hd/`, looking at the `lib`, `lef`, and `techlef` folders for the standard cell library. I saw the `.lib` timing files for different PVT (process-voltage-temperature) corners like `ff_100C_1v65`, `ss_100C_1v40`, `tt_025C_1v80`, and so on, and the single `sky130_fd_sc_hd.tlef` technology LEF file. This helped me understand something I had only read about before: standard cells aren't described by a single "correct" timing number — they have to be characterized across multiple corners because a real chip has to work across a range of voltage and temperature conditions after fabrication. This is why later, during synthesis, I saw OpenSTA specifically try to load `ff_n40C_1v95` and `ss_100C_1v60` corner libraries.*

### Getting OpenLane running via Docker

I checked what OpenLane images I already had pulled locally and then launched the flow interactively.

[Docker images list]<img width="1278" height="661" alt="06_docker_images_list" src="https://github.com/user-attachments/assets/3ec8d9c5-8f76-42eb-800a-dff10b48678c" />


*This is evidence that I set up the Docker environment myself — running `docker images` shows the `efabless/openlane:v0.21` image present on my system. Understanding that OpenLane ships as a containerized flow (rather than something you install natively) was one of my first practical lessons: the flow depends on a very specific, pinned set of tool versions (Yosys, OpenROAD components, Magic, Netgen, etc.), and Docker is what keeps all of that reproducible regardless of what's on the host machine.*

[Docker run and OpenLane banner]<img width="1281" height="657" alt="04_docker_run_openlane_banner" src="https://github.com/user-attachments/assets/a54d7685-0be2-472e-bb3b-b2e8a79c1406" />


*I launched the container with the volume mounts for `$PDK_ROOT` and the OpenLane flow directory, then started the flow interactively with `./flow.tcl -interactive` and `package require openlane 0.9`. Seeing the ASCII banner and the Tcl shell come up was the point where the flow stopped being an abstract idea to me and became something I was actually driving, command by command, instead of running a single black-box script.*

---

## 2. Understanding the Design Files and Configuration

### Design source structure

[Designs directory and picorv32a src files]<img width="1281" height="663" alt="01_designs_directory_picorv32a_src" src="https://github.com/user-attachments/assets/26b26cd5-65af-444f-a7be-234a90ee6ed1" />


*I looked through `openlane/designs/` and saw dozens of example designs (aes, spm, usb, picorv32a, and others) that ship with OpenLane, then moved into `picorv32a/src/`, where I found exactly two files: `picorv32a.v` (the RTL) and `picorv32a.sdc` (the timing constraints file). This made something click for me — the entire physical design flow, no matter how many stages it has, ultimately starts from just these two inputs: the behavior of the design (RTL) and the timing intent of the design (constraints). Everything downstream — synthesis, placement, CTS, routing — exists to turn this pair of files into a manufacturable layout that still behaves and times the way the RTL and SDC describe.*

### The design-level configuration

[picorv32a config.tcl]<img width="1282" height="658" alt="10_picorv32a_design_config_tcl" src="https://github.com/user-attachments/assets/0f195f37-532a-4e39-8f7b-bf247701b356" />


*This is the design-specific `config.tcl` for picorv32a. I saw it set `DESIGN_NAME`, point to the Verilog and SDC files, and set `CLOCK_PERIOD` to `5.000` ns with `CLOCK_PORT` as `clk`. Reading this file taught me that OpenLane's configuration is layered: a design's own config.tcl only needs to declare what's specific to that design (its name, its RTL, its clock), and it sources a PDK/standard-cell-specific config file (`$PDK_$STD_CELL_LIBRARY_config.tcl`) underneath for everything that depends on the technology rather than the design itself.*

### The standard-cell-library configuration layer

[sky130 SCL config.tcl]<img width="1282" height="657" alt="08_sky130_scl_config_tcl" src="https://github.com/user-attachments/assets/94de94eb-fd13-47cc-af45-ecb9887a9035" />


*This screenshot shows `sky130A_sky130_fd_sc_hd_config.tcl`, which sets library-specific parameters like `SYNTH_MAX_FANOUT`, `CLOCK_PERIOD` (here shown as `24.73`, a different default used before my design's own value overrides it), `FP_CORE_UTIL` (35%), and `PL_TARGET_DENSITY` computed from the core utilization. Understanding this layer helped me see that floorplan and placement aren't just "run and see what happens" steps — utilization and target density are conscious inputs. A higher `FP_CORE_UTIL` packs cells more tightly into a smaller die area, while a lower one leaves more room for routing at the cost of a larger chip.*

### Preparing the design run

[prep -design and LEF merge]<img width="1277" height="666" alt="05_prep_design_picorv32a_lef_merge" src="https://github.com/user-attachments/assets/29cc761c-cdd4-4427-8b16-0e66d4f007e0" />


*I ran `prep -design picorv32a` inside the interactive Tcl shell. From the log, I could see OpenLane sourcing my design's config.tcl, identifying the PDK root and the sky130A PDK, reading the standard cell library, and — importantly — reporting `The available metal layers are li1 met1 met2 met3 met4 met5`. I then watched it merge LEF files (`mergeLef.py`) and report exactly which macros were matched, including `sky130_ef_sc_hd__fakediode_2.lef: MACROs matched found: 1`. This was my first direct evidence of the fake antenna diode cell being part of the flow (more on this below) — I could literally see OpenLane pulling it into the merged LEF before any placement or routing had happened.*

[Full run configuration snapshot]<img width="1277" height="662" alt="15_full_run_config_tcl_diode_cts" src="https://github.com/user-attachments/assets/06f71505-7b96-4ba5-b4e8-f682ebb8eb85" />


*After prep completed, OpenLane wrote out a full resolved `config.tcl` for the run, capturing every parameter that would actually be used. This is where I found the antenna-related settings explicitly: `DIODE_CELL` set to `sky130_fd_sc_hd__diode_2`, `DIODE_CELL_PIN` set to `DIODE`, `DIODE_INSERTION_STRATEGY` set to `3`, `DIODE_PADDING` set to `2`, and `FAKEDIODE_CELL` set to `sky130_ef_sc_hd__fakediode_2`. I also saw the CTS-related environment variables (`CTS_CLK_BUFFER_LIST`, `CTS_TARGET_SKEW`, `CTS_TOLERANCE`, `CTS_SINK_CLUSTERING_SIZE`, etc.) and the routing-related ones (`DETAILED_ROUTER` set to `tritonroute`). Seeing these as concrete, named variables — rather than abstract flow-stage names — helped me understand that every stage of OpenLane is really just a script being handed a specific, tunable set of parameters, and that antenna handling is planned for from the very start of the run, not bolted on afterward.*

### The run directory structure created by OpenLane

[Run directory after prep]<img width="1276" height="662" alt="13_run_dir_ls_after_prep" src="https://github.com/user-attachments/assets/d9e2f18e-64d7-4fc1-abfa-2e8ec500696d" />


[tmp directory with per-stage folders]<img width="1277" height="661" alt="14_tmp_dir_stage_folders_merged_lef" src="https://github.com/user-attachments/assets/bf0b1793-9879-4e5a-a0ab-6586f589055b" />


*Once prep finished, I looked at the run directory it created (`runs/04-09_12-25/`) and its `tmp/` subfolder. I saw that OpenLane scaffolds a dedicated subfolder for every stage of the flow up front — `synthesis`, `floorplan`, `placement`, `cts`, `routing`, `magic`, `lvs`, `klayout`, `cvc` — along with `merged.lef`, `merged_unpadded.lef`, and the `trimmed.lib` file (a version of the standard cell timing library with fill/tap/decap cells excluded, per `trimmed.lib.exclude.list`). This showed me that OpenLane's structure mirrors the flow itself: each stage has an isolated place to write its results, and each stage consumes files (like the merged LEF and trimmed lib) that were prepared once, up front, so every downstream stage works from a consistent view of the technology and the design.*

---

## 3. Running RTL Synthesis and Studying the Results

This was the stage I actually took all the way through and could verify with real output — from invoking Yosys, to reading the generated netlist, to running post-synthesis static timing analysis with OpenSTA.

[Synthesis run log with OpenSTA]<img width="1285" height="658" alt="12_synthesis_run_log_opensta" src="https://github.com/user-attachments/assets/be86f202-7243-41f0-9838-1952253a3f75" />


*This is the terminal log from the synthesis run. I can see Yosys 0.9 finishing its run ("Yosys 0.9+3621 ... Time spent ..."), followed immediately by OpenSTA 2.3.0 being invoked to run static timing analysis on the freshly synthesized netlist. I noticed OpenSTA printing warnings that it couldn't find the `ff_n40C_1v95` and `ss_100C_1v60` operating condition libraries — a direct, practical confirmation of what I'd already seen in the PDK's `lib/` folder: multiple corner libraries exist, and the tool explicitly checks for the specific corners it needs. The log also shows the input/output delay values being set from my clock period, `set_max_fanout` being applied from `SYNTH_MAX_FANOUT`, and finally `tns -759.46`, `wns -24.89`, ending with `[INFO]: Synthesis was successful`.*

*Before this, my understanding of "synthesis" was purely conceptual — RTL gets converted to gates. Actually watching Yosys hand off directly into OpenSTA, in the same run, made me understand that synthesis in OpenLane isn't just "produce a gate-level netlist" — it's "produce a gate-level netlist **and immediately check whether it can meet timing**," using the same clock period and delay values defined all the way back in my design's config.tcl and SDC. The negative TNS/WNS values also gave me my first real look at what an unconstrained/un-optimized synthesis timing result actually looks like, rather than just reading about slack in the abstract.*

[Synthesis netlist output]<img width="1281" height="662" alt="18_synthesis_netlist_verilog" src="https://github.com/user-attachments/assets/69deb0bd-5a86-4b21-b61f-24a599dfd713" />


*This is `picorv32a.synthesis.v`, the actual gate-level Verilog netlist Yosys produced, opened directly in the terminal. I can see the module port list (`mem_valid`, `mem_instr`, `pcpi_rs1`, `pcpi_wr`, `irq`, `trace_data`, etc., matching the picorv32a RTL interface) followed by hundreds of auto-generated internal wire names like `_00001_`, `_00002_`. Seeing this file — a real, synthesizable netlist made only of standard cells and wires, with no behavioral constructs left — is what made "synthesis converts RTL into a gate-level netlist" stop being a definition I'd memorized and start being something I'd actually watched happen to a specific design.*

[Synthesis statistics report - top]<img width="1282" height="658" alt="16_synthesis_stat_report_top" src="https://github.com/user-attachments/assets/2c0bf3f7-efdc-4dd7-93e8-8759914b99b9" />


[Synthesis statistics report - chip area]<img width="1281" height="662" alt="17_synthesis_stat_report_chip_area" src="https://github.com/user-attachments/assets/f96ec875-11e9-4de3-815d-01cbfe9ccd99" />


*These two screenshots show Yosys's own statistics report for the picorv32a module: 14,596 wires, 14,876 cells in total, broken down by exact standard cell type — 1,656 `buf_1` cells, 1,613 `dfxtp_2` flip-flops, 1,615 `inv_2` inverters, 1,224 `mux2_1` cells, and so on, ending in a reported chip area of `147712.918400` (in the tool's native area units) for the module. This was useful for me because it showed synthesis output isn't just "a netlist" in the abstract — it's a very literal accounting of exactly which physical standard cells from the sky130_fd_sc_hd library were selected to implement my design's logic, down to the exact instance count of every cell type. It also made the connection between RTL and area concrete: this specific line of Verilog code produced this specific, countable list of physical cells.*

[Reports/synthesis directory listing]<img width="1277" height="660" alt="11_reports_synthesis_dir_listing" src="https://github.com/user-attachments/assets/b5ed63f1-99bf-4630-98f7-1d4be254bc3e" />


*Finally, I navigated to `reports/synthesis/` and listed what OpenLane had actually written out: `1-yosys_4.stat.rpt`, `1-yosys_4.chk.rpt`, `1-yosys_pre.stat.rpt`, `1-yosys_dff.stat`, and then a separate set of OpenSTA reports — `2-opensta.rpt`, `2-opensta.timing.rpt`, `2-opensta.slew.rpt`, `2-opensta.min_max.rpt`, `2-opensta_tns.rpt`, `2-opensta_wns.rpt`. This confirmed something I'd started to suspect from the run log: OpenLane treats "synthesis" as two separate, numbered sub-steps that are logged and reported independently — step 1 being the actual Yosys synthesis/technology mapping, and step 2 being the OpenSTA-based timing sign-off on that synthesized netlist. Nothing about the physical layout has been decided yet at this point, but the design's static timing behavior is already being measured.*

[OpenSTA timing report path]<img width="1283" height="658" alt="09_opensta_timing_report_path" src="https://github.com/user-attachments/assets/f48b68d2-6612-4942-ad84-86a4487d024b" />


*This is `2-opensta.timing.rpt` opened directly, showing one full timing path: startpoint `_27862_` and endpoint `_27762_`, both rising-edge-triggered flip-flops clocked by `clk`, with `Path Group: clk` and `Path Type: max`. I can follow the path stage by stage — clock arriving at a `dfxtp_2` flip-flop, propagating through `irq_mask[3]`, then through a chain of gates (`o22ai_2`, `a221o_2`, `or4_2`, `o2111a_2`, `or3_2`, `or2_2`, and more), with fanout, capacitance, slew, delay, and cumulative arrival time listed at every hop. Reading an actual timing path like this — rather than a textbook diagram of one — helped me understand what "delay" really means in STA: it's not one number for the whole design, it's an accumulation of gate delay plus wire/net delay at every single logic stage between one flop and the next, and the tool traces that exact chain to compute whether the path meets the clock period.*

---

## 4. Understanding Antenna Violations

I want to be clear about what's below: I did not run OpenLane all the way through routing, and I don't have a screenshot of an actual antenna-violation report or a "diode inserted here" log. What I *do* have direct evidence of is (a) the antenna-related fields present in the actual standard-cell LEF files, and (b) the specific antenna/diode configuration OpenLane resolved for my run. Based on that evidence and what I learned while working through it, here is my understanding of the concept and how OpenLane is set up to handle it.

### What I saw in the LEF file

[LEF file showing antenna area fields]<img width="1282" height="657" alt="07_lef_antenna_area_fields" src="https://github.com/user-attachments/assets/d1e965bf-1996-455b-bb0e-eb83e32b82c0" />


*This is the `merged_unpadded.lef` file, showing the `MACRO sky130_fd_sc_hd__dfstp_4` (a scan flip-flop) definition. Inside the pin definitions, I can see fields I had never paid attention to before: `PIN D` has `ANTENNAGATEAREA 0.222000`, and `PIN Q` has `ANTENNADIFFAREA 1.320000`. This was the first time antenna checking stopped being an abstract rule for me and became a concrete, per-pin, per-cell number sitting right there in the same LEF file that also defines the cell's physical size and pin locations. It made me understand that antenna sensitivity isn't calculated after the fact from a generic formula — it's characterized per pin, for every single standard cell in the library, as part of the PDK itself.*

### What I understand about the antenna effect

I understood that an antenna violation is not simply a software error the way, say, a syntax error is. It represents a physical, fabrication-related problem: during processes like plasma etching (reactive ion etching) used to pattern metal interconnect, a long, unfinished metal wire can act like an antenna and collect stray electrical charge from the plasma. Normally this charge has somewhere safe to go, but during fabrication the wire may be connected to a transistor's gate while the rest of the chip (including the protective diffusion regions that would otherwise leak the charge away) hasn't been fabricated yet. If enough charge accumulates on that isolated piece of metal, and it's connected only to a thin, delicate gate oxide, it can build up enough voltage to damage or break down that oxide — permanently harming the transistor before the chip has even finished being manufactured.

This is why antenna rules exist at all: they aren't there to make timing or routing "look nicer," they exist because a real physical failure mechanism can occur *during* manufacturing, long before the chip is ever tested. The ratio that matters is generally the exposed metal area connected to a gate versus the area of the gate itself — a large wire connected to a small, sensitive gate is far riskier than a large wire connected to a large diffusion area (which is exactly why the LEF file separately tracks `ANTENNAGATEAREA` for the gate-connected pin and `ANTENNADIFFAREA` for the diffusion-connected pin).

An antenna checker (in the OpenLane flow, this is done using a DRC-style check, typically via Magic) works through the routed metal geometry after routing and evaluates this area ratio, layer by layer, against a limit defined by the technology (the sky130 PDK, in this case). If a net's ratio on a given layer exceeds that limit, it's flagged as an antenna violation.

### What I understand about fixing antenna violations, and the diode strategy I found configured

The most direct fix for an antenna violation is to give the accumulated charge somewhere safe to go: a reverse-biased antenna diode connected to the same net as the sensitive gate. If charge builds up on the wire during fabrication, it can now discharge safely through the diode instead of building up voltage across the gate oxide.

What I found genuinely interesting, and this is where the resolved config.tcl screenshot above becomes relevant, is that OpenLane doesn't just add diodes reactively after finding violations — it plans for the possibility from the very start of the run. I can see this directly in what I found configured:

- `DIODE_CELL` = `sky130_fd_sc_hd__diode_2` — the real antenna diode cell from the standard cell library.
- `FAKEDIODE_CELL` = `sky130_ef_sc_hd__fakediode_2` — a placeholder diode cell.
- `DIODE_INSERTION_STRATEGY` = `3` and `DIODE_PADDING` = `2`, which control how and where diode insertion is attempted during placement.

From this, and from what I learned about how OpenLane's flow is structured, I understand the general strategy as: a **fake antenna diode cell** — same footprint/size as the real diode but electrically inert — gets placed near cells that are statistically likely to need antenna protection, before routing even happens. This reserves physical space for a diode without committing to one everywhere, which would waste area. Routing then proceeds using this placeholder. Afterward, the antenna checker runs against the actual routed geometry. Only where a real violation is detected does the flow go back and **swap the fake diode cell for the real diode cell** (`sky130_fd_sc_hd__diode_2`) at that specific location, connecting it to the offending net. This fake-first, swap-if-needed approach is what let me understand the merged-LEF evidence I saw earlier during `prep -design` (`sky130_ef_sc_hd__fakediode_2.lef: MACROs matched found: 1`) — that fakediode cell being pulled into the merged LEF at prep time is the flow reserving that capability before placement or routing has even started.

I want to be upfront that I have not yet run the placement → routing → antenna-check → diode-swap sequence myself and captured its output, so I'm not claiming to have observed a violation being detected or fixed in this project. What I have is solid evidence that the mechanism is configured and ready in the flow (the diode/fakediode cell names, the insertion strategy, and the fakediode cell actually being merged into my design's LEF at prep time), combined with my own conceptual understanding of why it works the way it does.

---

## 5. How This Connects to the Full RTL-to-GDSII Picture

Working through even this much of the flow changed how I think about the stages that come after synthesis, even the ones I haven't run to completion yet:

- **Floorplanning** decides the die area and core utilization (I saw `FP_CORE_UTIL` and the derived `PL_TARGET_DENSITY` set in the SCL config before any floorplanning ran) — this is the stage that turns a target density number into an actual chip outline.
- **Placement** takes the synthesized netlist (the exact one I generated, with its exact cell counts) and decides where each of those ~14,876 cell instances physically sits within that outline, while also reserving fake diode locations per the diode insertion strategy.
- **Clock Tree Synthesis (CTS)** builds a balanced clock distribution network using the specific clock buffer cells I saw listed in the config (`sky130_fd_sc_hd__clkbuf_1/2/4/8`) — this exists because a real physical clock signal doesn't arrive at every flip-flop at the exact same instant; CTS is what controls that skew.
- **Routing** (global then detailed, with `tritonroute` as the detailed router in my config) turns the abstract netlist connectivity into actual metal wires across the `li1`–`met5` layers I saw listed for this PDK — and this is exactly the stage where antenna risk becomes physically real, since it's the metal geometry itself that can act as an antenna.
- **Antenna checking and diode swapping**, as I described above, happens against that real routed geometry.
- **RC extraction, post-route STA, and physical verification (DRC/LVS via Magic and Netgen)** all exist to re-verify, using the *actual* physical layout rather than estimates, that the design still meets timing and is physically/electrically correct before it's signed off as GDSII.

One important thing this project helped me understand is that passing one stage doesn't mean the design is "done." My synthesis run finished and reported success, but that only means the netlist is logically correct and gives an *early estimate* of timing — the real, physically-accurate timing and correctness checks only become meaningful after placement, CTS, and routing have actually fixed real locations and real wire lengths. Every stage in this flow exists because an earlier stage's view of the design was necessarily incomplete.

---

## 6. Reflections

Before doing this hands-on work, I understood the RTL-to-GDSII flow the way it's usually taught — a linear list of stage names. Actually setting up the Docker environment, exploring the real PDK directory structure, running `prep`, and pushing a real design through Yosys and OpenSTA changed that. I now think of the flow less as "steps" and more as a chain of tools that each read specific files produced earlier (the merged LEF, the trimmed lib, the synthesized netlist) and each write specific, inspectable reports of their own.

The antenna-diode part of this project was the clearest example of that shift for me. I initially thought of antenna rules as a somewhat obscure DRC checkbox. Seeing the actual `ANTENNAGATEAREA`/`ANTENNADIFFAREA` numbers sitting in the standard cell LEF, and seeing the fake/real diode cell names explicitly configured in my own run before placement even happened, made me understand it instead as a real fabrication-physics problem that the entire flow is quietly built around handling, well before routing ever produces a wire that could actually cause it.

---
