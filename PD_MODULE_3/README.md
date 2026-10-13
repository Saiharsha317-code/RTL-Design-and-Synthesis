# SKY130 Inverter: Layout → Extraction → SPICE → DRC

My personal lab journal for designing and verifying a **CMOS inverter standard cell** in the open-source
**SkyWater SKY130A** process, using **Magic**, **ngspice** and the **OpenLANE** workspace.

I wrote this so that when I come back in a few weeks I can answer, quickly:
**what did I do, why did I do it, what did I see, and what is still open?**

Everything lives in this one README; every claim is backed by a screenshot in [`images/`](images/) (upscaled and sharpened for readability).

---

## 1. The big picture

```
 CMOS fabrication theory ──► why an inverter looks the way it does in layout
        (Part 1)                         │
 Inverter robustness (Vm) ──► why NMOS/PMOS sizes matter
        (Part 2)                         │
                                          ▼
   sky130_inv.mag  ──extract all──►  sky130_inv.ext  ──ext2spice──►  sky130_inv.spice
   (Magic layout)      (Part 3)       (parasitics)     (Part 3)        (raw netlist)
                                                                            │ edit: models, supplies, pulse
                                                                            ▼
                                                           ngspice transient simulation  (Part 4)
                                                                            │
                                                         output Y is the inverted input A  ✔

   Separate lab: Magic DRC on SKY130A test layouts (met3, via2, poly) (Part 5)
```

## 2. Contents

1. [Timeline](#3-timeline-of-what-i-did)
2. [Key facts and numbers](#4-key-facts-and-numbers-worth-remembering)
3. [Part 1 · CMOS fabrication](#part-1--the-16-mask-cmos-fabrication-process)
4. [Part 2 · Inverter Vm](#part-2--cmos-inverter-robustness-switching-threshold-vm)
5. [Part 3 · Layout and extraction](#part-3--setup-layout-and-extraction)
6. [Part 4 · SPICE simulation](#part-4--spice-simulation-of-the-extracted-inverter)
7. [Part 5 · DRC in Magic](#part-5--design-rule-checking-drc-in-magic)
8. [Quick-recall questions](#quick-recall-questions) · [Open items](#things-i-still-need-to-double-check) · [Next steps](#next-steps)
9. [Appendix A · Netlists](#appendix-a--netlists) · [Appendix B · Cheat-sheet](#appendix-b--command-cheat-sheet-and-glossary)

## 3. Timeline of what I did

| When | What | Notes |
|---|---|---|
| Fri (19:33) | Looked at an OpenLANE **picorv32a floorplan** in Magic | Context only; see Part 3.0 |
| Fri 11 Sep (19:41) | Cloned `vsdstdcelldesign`, copied `sky130A.tech` into it, opened `sky130_inv.mag` | [Part 3](#part-3--setup-layout-and-extraction) |
| Sat 12 Sep (16:49–17:04) | Identified NMOS/PMOS, ran `extract all` + `ext2spice` | [Part 3](#part-3--setup-layout-and-extraction) |
| Sat (17:30–18:07) | Inspected the model libs, edited the netlist, first ngspice runs (one error) | [Part 4](#part-4--spice-simulation-of-the-extracted-inverter) |
| Sun (10:02) | Transient waveform of the inverter | [Part 4](#part-4--spice-simulation-of-the-extracted-inverter) |
| Tue (20:48–22:23) | DRC exercises on met3, via2 and poly test cells | [Part 5](#part-5--design-rule-checking-drc-in-magic) |
| (lecture slides) | 16-mask CMOS process and inverter Vm | [Part 1](#part-1--the-16-mask-cmos-fabrication-process), [Part 2](#part-2--cmos-inverter-robustness-switching-threshold-vm) |

## 4. Key facts and numbers worth remembering

| Item | Value | Where I saw it |
|---|---|---|
| Cell bounding box | **1.770 µm × 3.280 µm** (area 5.806 µm²), i.e. 177 × 328 in Magic units | `box` in tkcon |
| NMOS (to VGND) | W = 35, L = 23 → with `scale=0.01u`: **0.35 µm / 0.23 µm** | extracted netlist |
| PMOS (to VPWR) | W = 37, L = 23 → **0.37 µm / 0.23 µm** | extracted netlist |
| Supply | **3.3 V** (`VDD VPWR 0 3.3V`) | edited netlist |
| Input stimulus | pulse 0 → 3.3 V, 4 ns period | waveform |
| Simulation window | `.tran 1n 20n` (20 ns) | edited netlist |
| Parasitic caps extracted | six (C0–C5), from 0.0754 fF to 0.781 fF | extracted netlist |
| DRC counts seen | 22 (met3 cells), 10 (poly cell) | Magic toolbar |
| Vm, equal W/L (lecture, 2.5 V supply) | ≈ **1.0 V** | Part 2 |
| Vm, PMOS ×2.5 wider | ≈ **1.2 V** (closer to VDD/2) | Part 2 |


---

## Part 1 · The 16-mask CMOS fabrication process

Slides from the lecture. A **mask** is a pattern used in photolithography to decide *where* a step happens.
Each numbered step below is one stage of the cross-section; the picture is the proof that I followed it.

**How to read the slides:** P-substrate at the bottom; N-well (left) holds the **PMOS**, P-well (right) holds the **NMOS**.
Brown blocks = isolation oxide, red = polysilicon gate, green = side-wall spacers, dark blue = silicide/contact layer,
pink = metal.

| Mask seen in my screenshots | Used for |
|---|---|
| Mask1 | Active-region definition |
| Mask6 | Gate (poly) |
| Mask11 | Local interconnect (TiN) |
| Mask12 | Higher-level metal / contact holes |
| Mask16 | Final passivation / pad openings |

(Masks 2–5, 7–10 and 13–15 were in the lecture but not in my screenshots.)

---

### Step 1 · Select a substrate

![substrate]<img width="2456" height="1392" alt="01-substrate" src="https://github.com/user-attachments/assets/ecdc279e-7da1-4149-a02d-4726d4c58d93" />


Start with a **P-type silicon wafer**. Everything is built in and on top of it.

### Step 2 · Create the active regions (Mask1)

![active region]<img width="2496" height="1340" alt="02-active-region-mask1" src="https://github.com/user-attachments/assets/be5f67cd-0911-4439-bd25-8c2cee05282c" />


A stack is deposited: **~40 nm SiO₂**, **~80 nm Si₃N₄**, **~1 µm photoresist**. Mask1 exposes the resist, and the
areas where transistors will *not* be are etched and filled with oxide. The nitride protects the future
transistor areas while isolation oxide is formed.

![isolation formed]<img width="2374" height="1384" alt="03a-isolation-before-well-implant" src="https://github.com/user-attachments/assets/de2aacbf-aeef-45d1-a063-d001637f7296" />


*Result: the brown isolation blocks separate neighbouring devices, leaving thin oxide over the active areas.*

### Step 3 · N-well and P-well formation

Dopants are implanted through masks (one well type at a time), then pushed deeper in a furnace.

![drive-in]<img width="2384" height="1390" alt="03b-well-drive-in-diffusion" src="https://github.com/user-attachments/assets/bce43558-b864-4a1a-87ec-1953cf6e63f8" />


**Drive-in diffusion** in a high-temperature furnace spreads the dopants to the target depth. After this the
N-well and P-well meet under the isolation oxide.

### Step 4 · Formation of the gate (Mask6)

![gate]<img width="2374" height="1374" alt="04-gate-formation-mask6" src="https://github.com/user-attachments/assets/8d21b54d-5192-4a5a-af90-6b86eabb56a9" />


Polysilicon is deposited over the thin gate oxide; Mask6 leaves resist only where gates should be, and the rest of the
poly is etched away. The faint **N** / **P** layers under the oxide are the threshold-adjust implants.

### Step 5 · Lightly doped drain (LDD)

![ldd]<img width="2342" height="1344" alt="05-ldd-formation" src="https://github.com/user-attachments/assets/c86e9e95-ce0b-4d80-a450-1def8757dfeb" />


A light **N⁻** implant (into the P-well, for the NMOS) and a light **P⁻** implant (into the N-well, for the PMOS) are
made next to the gate. **Side-wall spacers** (green) then keep the heavy implants a small distance away from the channel.

**Why:** the electric field at the drain edge is lower, reducing hot-carrier effects and short-channel problems.

### Step 6 · Source and drain formation

![source drain]<img width="2374" height="1384" alt="06-source-drain-formation" src="https://github.com/user-attachments/assets/1bde4d52-f80a-4de2-8596-06c74aacafcb" />


Heavy **N⁺** (NMOS) and **P⁺** (PMOS) implants form the source/drain regions, self-aligned to the spacers.
A high-temperature furnace step activates the dopants and repairs implant damage.

### Step 7 · Contacts and local interconnect

**7a. Structure before contacts**

![before contacts]<img width="2164" height="1360" alt="07a-before-contact-formation" src="https://github.com/user-attachments/assets/4d1ff2c9-3efb-46ad-921c-f8751a787ad7" />


**7b. Etch the thin oxide with HF** so that silicon and poly are exposed where contacts are needed.

![hf etch]<img width="2222" height="1364" alt="07b-hf-thin-oxide-etch" src="https://github.com/user-attachments/assets/49e99a3e-f43b-4c46-a930-1ff0a6a6af46" />


**7c. Titanium + anneal.** Titanium is deposited, then the wafer is heated at **~650–700 °C in N₂ for ~60 s**. The slide's
conclusion: **TiN is used only for local communication** (local interconnect). Titanium in contact with silicon/poly
forms a low-resistance silicide layer, which is what gives good contacts.

![tin]<img width="2490" height="1260" alt="07c-titanium-anneal-tin" src="https://github.com/user-attachments/assets/d1f94a9e-82d0-43b3-8e5f-696e460d5f76" />


**7d. Mask11** patterns the TiN so that it forms the local wiring.

![mask11]<img width="2424" height="1264" alt="07d-local-interconnect-mask11" src="https://github.com/user-attachments/assets/21f61ecf-b4c2-455b-b161-aa78e25b6684" />


### Step 8 · Higher-level metal formation

**Mask12** opens contact holes through the thick oxide that was deposited on top; the holes are filled and metal is
patterned. This is repeated for more metal levels.

![mask12]<img width="2440" height="1266" alt="08a-higher-metal-mask12" src="https://github.com/user-attachments/assets/3ba00685-61da-4c31-8a80-e9c8f2630072" />


The **final mask (Mask16)** opens the holes in the top passivation layer so the chip can be connected to the outside.

![mask16]<img width="2412" height="1254" alt="08b-final-mask16-passivation" src="https://github.com/user-attachments/assets/22e5333a-b120-4ae6-8d0e-897ec3e64fdf" />


#### Finished cross-section

The labels **S, G, D** show where each transistor terminal reaches the metal layers: PMOS on the left (P⁺ S/D in the
N-well), NMOS on the right (N⁺ S/D in the P-well).

![finished]<img width="2466" height="1286" alt="08c-completed-cross-section" src="https://github.com/user-attachments/assets/763e4546-5d26-4544-ad40-50554016409d" />


---

### Why this matters for the layout work

The colours I draw in Magic map directly onto these steps: **n-well**, **diffusion**, **poly**, **local interconnect**, **contacts**, **metal**.
When a DRC rule says "poly spacing to diffusion" or "metal3 minimum area", it is really protecting one of the
steps above from printing or etching badly.

---

## Part 2 · CMOS inverter robustness: switching threshold (Vm)

![Vm two sizes]<img width="2424" height="1372" alt="vm-two-wl-ratios" src="https://github.com/user-attachments/assets/da161ff0-c4ab-446f-ba4a-f3305d218e41" />


### What the slide shows

Two SPICE DC sweeps of the **voltage transfer characteristic (VTC)** of a CMOS inverter, supply = 2.5 V, L = 0.25 µm.
The blue diagonal is **Vin = Vout**. Where the green VTC crosses it is **Vm**, the switching threshold.

| | Left plot | Right plot |
|---|---|---|
| Wn, Wp | 0.375 µm, 0.375 µm | 0.375 µm, 0.9375 µm |
| Wn/Ln | 1.5 | 1.5 |
| Wp/Lp | 1.5 | 3.75 (PMOS 2.5× wider) |
| Vm (read from plot) | **≈ 1.0 V** | **≈ 1.2 V** |
| Ideal Vm = VDD/2 | 1.25 V | 1.25 V |

### Interpretation

* With equal sizes, the NMOS is the stronger device (electrons are more mobile than holes), so the output starts falling
  *early*: Vm lands **below** VDD/2.
* Making the PMOS wider strengthens the pull-up and moves Vm **up toward VDD/2**. The VTC is then more symmetric, which gives
  more balanced noise margins and similar rise/fall times.
* Rough model (long-channel approximation):
  `Vm ≈ (Vtn + r·(VDD − |Vtp|)) / (1 + r)`, with `r = sqrt( μp (W/L)p / (μn (W/L)n) )`.
  Bigger `r` (wider PMOS) → bigger Vm.

### Connection to my own cell

My extracted cell has **NMOS W = 0.35 µm** and **PMOS W = 0.37 µm**, i.e. nearly equal widths, with a 3.3 V supply. By the logic above
I should expect its Vm to be **somewhat below 1.65 V**. I have *not* simulated that yet; it is on the to-do list in the
[README](#next-steps).

---

## Part 3 · Setup, layout and extraction

### 3.0 Context: a floorplan viewed in Magic (before this lab)

Just before starting this lab I had an OpenLANE **picorv32a floorplan** open in Magic (the terminal later shows I was in
`designs/picorv32a/runs/.../results/floorplan`). Cyan marks along the edges are I/O pins; the dense vertical columns are
the regularly spaced cells placed by the floorplan step. This is only context; the lab itself is one small cell.

![floorplan overview]<img width="2436" height="1204" alt="floorplan-overview-alt-view" src="https://github.com/user-attachments/assets/f396b99e-8567-4bdf-8509-0eaba906edcb" />

![floorplan zoom]<img width="2392" height="1270" alt="floorplan-overview-magic" src="https://github.com/user-attachments/assets/69d8b3c2-ffd0-403a-8f1e-06476df9b4bb" />

![floorplan alt]<img width="2524" height="1244" alt="floorplan-zoom-io-pins" src="https://github.com/user-attachments/assets/7955fb73-beb3-408e-a21f-a9bc6d12c7cf" />


### 3.1 Get the files

1. Go into the PDK's Magic tech folder and copy the technology file into my working folder.

   ![copy tech]<img width="2374" height="566" alt="cp-sky130A-tech-to-workdir" src="https://github.com/user-attachments/assets/6de8dabb-e6f2-4779-a376-cb9bb636f651" />


   `pdks/sky130A/libs.tech/magic/` contains `sky130A.tech` (the layer/DRC/extraction rules), `sky130A.magicrc`, `sky130A.tcl`, etc.
   I copied `sky130A.tech` into `openlane/vsdstdcelldesign`.

2. Clone the workshop repository that contains the inverter cell.

   ![clone]<img width="2370" height="1132" alt="git-clone-vsdstdcelldesign" src="https://github.com/user-attachments/assets/72aa7148-ebed-42e6-ac88-27bc906cb15f" />


   It gives me `README.md`, `LICENSE`, `Images/`, `extras/`, `libs/` and the layout **`sky130_inv.mag`**.

3. Open the layout with the tech file:

   ```bash
   magic -T sky130A.tech sky130_inv.mag &
   ```

   ![open magic]<img width="2799" height="1026" alt="open-magic-with-tech-file" src="https://github.com/user-attachments/assets/3eb87a1d-514f-4726-9a1c-b75554235b29" />


   `-T` selects the technology; `&` keeps the terminal usable.

### 3.2 The inverter layout

![inverter layout]<img width="2516" height="1274" alt="sky130-inv-layout-in-magic" src="https://github.com/user-attachments/assets/3479d998-60f9-467a-a591-bc190c1d63f2" />


How to read it (Magic's sky130A colour style):

* **VPWR** rail at the top, **VGND** rail at the bottom.
* One **vertical poly stripe** (red) is the shared gate, which is input **A**.
* **PMOS** at the top (inside the grey-hatched **N-well**), **NMOS** at the bottom.
* The two transistors' drains are joined by the blue local-interconnect line, which is output **Y**.
* Squares with an ✕ are contacts.

#### Confirming which transistor is which

Selecting a channel region and typing `what` in the tkcon window reports the layer:

![what command]<img width="2516" height="1280" alt="nmos-pmos-identified-with-what" src="https://github.com/user-attachments/assets/25fab98b-e487-4e1b-a84e-17886eadfea8" />


The first selection reported **nmos**, the second **pmos**. Good way to confirm the top device is the PMOS.

#### Cell size

`box` (with the whole cell selected) printed:

```
microns:  1.770 x 3.280   (-0.200, -0.240), (1.570, 3.040)   area 5.806
lambda:   177 x 328       (  -20,   -24 ), ( 157,   304 )    58056
```

So **1.77 µm × 3.28 µm**, and Magic's unit here is 0.01 µm.

### 3.3 Extraction: layout → circuit

In the tkcon window:

```tcl
extract all                     ;# makes sky130_inv.ext
ext2spice cthresh 0 rthresh 0   ;# keep every parasitic capacitor, no thresholding
ext2spice                       ;# writes sky130_inv.spice
```

![extract running]<img width="2506" height="1280" alt="extract-all-running" src="https://github.com/user-attachments/assets/13b7e61f-ef8e-4d8c-9196-c512293101b8" />


![extraction finished]<img width="2514" height="1266" alt="ext2spice-finished" src="https://github.com/user-attachments/assets/5b2bf67c-8491-4bb7-bdf8-cd5e8480ffae" />


> A line earlier in the console says `Unknown command: 'cif' 'scale' 'out'`; that command was not valid in this Magic
> version and did not affect the extraction.

Afterwards the folder contains the two new files:

![files]<img width="2474" height="790" alt="files-after-extraction" src="https://github.com/user-attachments/assets/0a8db76c-b3d9-48c4-98cb-d2070c55b79b" />


| File | Size | Meaning |
|---|---|---|
| `sky130_inv.ext` | 1365 B | Magic's extracted circuit (devices + parasitics) |
| `sky130_inv.spice` | 404 B | SPICE netlist generated from it |

---

## Part 4 · SPICE simulation of the extracted inverter

### 4.1 What `ext2spice` gave me

![raw netlist]<img width="2372" height="900" alt="raw-extracted-netlist" src="https://github.com/user-attachments/assets/7586d52d-ff3a-45c3-9133-7f9d226e0b87" />


```spice
.option scale=10m
.subckt sky130_inv A Y VPWR VGND
X0 Y A VGND VGND sky130_fd_pr__nfet_01v8 ad=1.44n pd=0.152m as=1.37n ps=0.148m w=35 l=23
X1 Y A VPWR VPWR sky130_fd_pr__pfet_01v8 ad=1.44n pd=0.152m as=1.52n ps=0.156m w=37 l=23
C0 VPWR Y 0.117f   C1 A Y 0.0754f   C2 A VPWR 0.0774f
C3 Y VGND 0.279f   C4 A VGND 0.45f   C5 VPWR VGND 0.781f
.ends
```

* `X0` = NMOS (source side on **VGND**), `X1` = PMOS (on **VPWR**).
* `w=35 l=23` are in Magic units; `scale` converts them to metres.
* `C0…C5` are the **parasitic capacitances** found by the extractor (this is why the post-layout simulation is more realistic than a schematic one).

### 4.2 Models available in the workshop `libs/`

![libs]<img width="2384" height="364" alt="libs-folder-listing" src="https://github.com/user-attachments/assets/683cd4d3-163c-462f-a72e-8ce24f277e53" />


`pshort.lib` and `nshort.lib` hold simple model cards; the `sky130_fd_sc_hd__{fast,typical,slow}.lib` files are the standard-cell timing libraries.

**PMOS model** (`pshort_model.0`, a BSIM4 `pmos`, level 54, version 4.5):

![pmos]<img width="2506" height="1284" alt="pshort-model-0-pmos" src="https://github.com/user-attachments/assets/f38ea238-d85a-4edc-9628-d1cff2ee55bf" />


**NMOS model** (`nshort_model.0`, a BSIM4 `nmos`):

![nmos]<img width="2500" height="1274" alt="nshort-model-0-nmos" src="https://github.com/user-attachments/assets/b8b2530d-aa2c-4f6b-8bd6-f67bbd51831b" />


Observation: both cards declare `lmin = 1.45e-7 … lmax = 1.55e-7` and `wmin ≈ 1.255e-6 … wmax ≈ 1.265e-6`. My drawn device (0.23 µm × 0.35 µm)
is outside that bin, so I treat the waveform as **qualitative**.

### 4.3 Edits I made to the netlist

| # | Edit | Reason |
|---|---|---|
| 1 | `.option scale=10m` → `scale=0.01u` | Magic units are 0.01 µm |
| 2 | add `.include ./libs/pshort.lib` and `./libs/nshort.lib` | bring in the model cards |
| 3 | `X…` lines → `M…` lines with `pshort_model.0` / `nshort_model.0` | `X` means *subcircuit*; a `.model` needs an `M` (MOSFET) device |
| 4 | add `VDD VPWR 0 3.3V`, `VSS VGND 0 0V` | supplies |
| 5 | add `Va A VGND PULSE(...)` | stimulus |
| 6 | add `.tran 1n 20n` and a `.control / run / .endc` block | run a 20 ns transient |

#### First run: error

![first run]<img width="2512" height="1284" alt="ngspice-first-run-error" src="https://github.com/user-attachments/assets/59ac1bc9-2669-4960-91c5-7359474f9ae8" />


```
Error: unknown subckt: x0 y a vgnd vgnd pshort_model.0 ad=1.44n ...
```

ngspice treated the line starting with `X` as a subcircuit instance and could not find a subcircuit called `pshort_model.0`.
Fix: rename to an `M` device (edit 3), reopen in `vim`, rerun.

#### The netlist as I saved it

![edited netlist]<img width="2504" height="1274" alt="edited-netlist-in-vim" src="https://github.com/user-attachments/assets/0d7e81b5-d602-41fb-9140-d026ede4baf3" />


### The bug I should not forget

Look at the two transistor lines in that screenshot:

```spice
M0 Y A VGND VGND pshort_model.0 ...   ← connected to ground, but uses the PMOS model
M1 Y A VPWR VPWR nshort_model.0 ...   ← connected to VDD,    but uses the NMOS model
```

The models are **swapped**: the device tied to VGND must be the NMOS, and the one tied to VPWR must be the PMOS.
The second ngspice run printed an *Initial Transient Solution* with **y = 0.309 V while a = 0 V**; a correct inverter would give ≈ 3.3 V.
That is consistent with this swap.

Also, the saved `PULSE(0V 3.3V 0 0.1ns 2ns 4ns)` has only six numbers; SPICE's `PULSE` takes seven
(`V1 V2 TD TR TF PW PER`). The waveform I got later has sharp 4 ns-period edges, so the file I finally simulated must have been corrected.
A clean, correct version is in the cleaned netlist in the [appendix](#appendix-a--netlists).

### 4.4 Result: transient waveform

![waveform]<img width="2512" height="1274" alt="transient-waveform-a-vs-y" src="https://github.com/user-attachments/assets/adcb5fe0-870d-4c50-ac33-2d822a47ed53" />


* **Blue = A (input)**, **red = Y (output)**, 0 → 3.3 V, 20 ns shown, 5 clean periods.
* Y is the **inverse** of A: when A is high Y is low and vice versa: the cell works as an inverter.
* Small spikes slightly above 3.3 V at the edges are expected from the gate-to-drain coupling capacitance (`C1 A Y`).

#### What to measure next (to fill in later)

| Quantity | Definition | Value |
|---|---|---|
| Rise time | Y from 20 % to 80 % of 3.3 V | _TODO_ |
| Fall time | Y from 80 % to 20 % | _TODO_ |
| Propagation delay (L→H / H→L) | 50 % of A to 50 % of Y | _TODO_ |

---

## Part 5 · Design-rule checking (DRC) in Magic

**DRC** checks the layout against the foundry's geometric rules (minimum width, spacing, area, enclosure, …).
Magic runs it continuously and shows the number of errors in the toolbar (e.g. **DRC=22**). The rules live in the
`DRC` section of `sky130A.tech`.

These exercises use SKY130A test layouts: each cell contains a small drawing for every rule of one layer, some correct and some incorrect.

### 5.1 Metal 3 test cell

![met3 overview]


Each yellow label (`m3.1`, `m3.2`, `m3.3c`, `m3.3d`, `m3.4`, `m3.5`, `m3.6`, `m3.7`) marks the drawing that tests that rule.
`m3.4` is annotated *"Correct by design"* and `m3.7` *"Incorrect"*.

#### Asking Magic *why* there is an error

![drc why]


```tcl
drc why
Metal3 spacing < 0.3um (met3.2)
drc why
Metal3 minimum area < 0.24um^2 (met3.6)
```

| Rule | Meaning |
|---|---|
| **met3.2** | Spacing between metal-3 shapes must be ≥ 0.3 µm |
| **met3.6** | A metal-3 shape must have area ≥ 0.24 µm² |

The console also said `Input cell met3 scales magic internal geometry by factor of 2` and `Loading DRC CIF style`, which means the
DRC for this layer uses a CIF-based (derived layer) check, not only simple edge rules.

### 5.2 The m3.3c cell: array of cuts

![m3.3c]<img width="2510" height="1280" alt="m3-3c-via-array" src="https://github.com/user-attachments/assets/7eccf11e-a61d-44ad-a3f2-fee1fd6dbfb9" />



An 8 × 8 array of square cuts inside a metal-3 block; the toolbar shows **DRC=22**. I need to confirm in the rule
document exactly what `m3.3c` checks (it concerns the metal-3 / via relationship).

### 5.3 Looking at a single via (`m3contact`, `cif see VIA2`)

![m3contact]<img width="2502" height="1284" alt="m3contact-and-cif-see-via2" src="https://github.com/user-attachments/assets/069933c0-65b7-4cb5-8adb-849b2a461edb" />



```tcl
paint m3contact       ;# paint a metal3/via2 contact in the box
cif see VIA2          ;# show the VIA2 layer that Magic would generate for mask output
snap int
box                   ;# measure the box
```

```
microns:  0.190 x 0.200  (5.320, 5.595), (5.510, 5.795)  area 0.038
```

The point of `cif see` is to compare what I *drew* with the **derived mask layer** that is actually checked/manufactured.

### 5.4 Poly rule `poly.9`

![poly9]<img width="2506" height="1282" alt="poly9-box-measurement" src="https://github.com/user-attachments/assets/3002fb7f-7b58-4b07-9278-05247ab51bc4" />


```tcl
load poly
box
microns:  0.335 x 0.210  (17.870, 4.270), (18.205, 4.480)  area 0.070
```

The toolbar showed **DRC=10**. I used `box` to measure the poly feature and the gap that the `poly.9` label points to.
Red = poly, green = diffusion, orange hatch = other mask layers.

### 5.5 Habits to keep

1. Zoom on the error marker, make a **box** around it, run `drc why`.
2. Use `box` to *measure*, compare with the rule number.
3. Fix the layout (or the tech-file rule if the rule itself is incomplete), then watch the DRC counter drop.

> ⚠ My screenshots show the *checks*, not the final fix. Add the exact change (before/after DRC count) here once I redo or recall it.

---

## Quick-recall questions

<details><summary><b>Q1.</b> Why does the inverter output go to 0.31 V when A = 0 V in my first ngspice run?</summary>

That was a symptom of the NMOS/PMOS model names being attached to the wrong transistors in my edited netlist
(see [Part 4](#the-bug-i-should-not-forget)). A working inverter must give Y ≈ 3.3 V when A = 0 V.
</details>

<details><summary><b>Q2.</b> What does <code>.option scale=10m</code> → <code>0.01u</code> change?</summary>

Magic writes W and L in its own internal units (here 1 unit = 0.01 µm). `scale` tells SPICE how to convert them, so `w=35` becomes 0.35 µm. `10m` would have meant 1 unit = 10 mm: nonsense for a transistor.
</details>

<details><summary><b>Q3.</b> Which command lists <i>why</i> a DRC error exists?</summary>

`drc why` (with the offending area selected or inside the box). Example outputs I got: *Metal3 spacing < 0.3 µm (met3.2)* and *Metal3 minimum area < 0.24 µm² (met3.6)*.
</details>

<details><summary><b>Q4.</b> Why is the PMOS usually drawn wider than the NMOS?</summary>

Holes are less mobile than electrons, so for equal strength (symmetric switching, Vm ≈ VDD/2) the PMOS needs a larger W/L. See [Part 2](#part-2--cmos-inverter-robustness-switching-threshold-vm).
</details>

<details><summary><b>Q5.</b> What is the purpose of the LDD step in the 16-mask process?</summary>

Lightly doped drain/source extensions next to the channel soften the electric field at the drain edge, which reduces hot-carrier damage and short-channel effects. Spacers then offset the heavy N+/P+ implants. See [Part 1](#part-2--cmos-inverter-robustness-switching-threshold-vm).
</details>

<details><summary><b>Q6.</b> What file is made by <code>extract all</code>, and what by <code>ext2spice</code>?</summary>

`extract all` → `sky130_inv.ext` (Magic's extracted circuit incl. parasitics). `ext2spice` → `sky130_inv.spice` (a SPICE netlist).
</details>

## Things I still need to double-check

- [ ] The saved netlist (screenshot in Part 4) has the two model names swapped and a `PULSE(...)` line with only six numbers; confirm the file I actually simulated for the waveform was corrected.
- [ ] I read the picorv32a Magic views as a floorplan from the earlier OpenLANE run; verify.
- [ ] Record the exact **tech-file edits** (if any) I made while fixing the DRC cases, since the screenshots only show the checks, not the fixes.
- [ ] The model library bins (`lmin/lmax`, `wmin/wmax`) do not contain my 0.23 µm / 0.35 µm device; treat the waveform as qualitative.

## Next steps

1. Measure **rise time, fall time, propagation delay** from the waveform (20 %–80 % and 50 % points).
2. Run a **DC sweep** to find this inverter's real Vm and compare with the lecture plots.
3. Add the DRC tech-file fixes to Part 5 with before/after counts.
4. Continue down the flow: LVS, then place this cell into a library (LEF/liberty) for OpenLANE.

---

## Appendix A · Netlists

**A1. Raw output of `ext2spice`** (as in the Part 4 screenshot)

```spice
* SPICE3 file created from sky130_inv.ext - technology: sky130A
* (transcribed from my screenshot of the raw ext2spice output)

.option scale=10m

.subckt sky130_inv A Y VPWR VGND
X0 Y A VGND VGND sky130_fd_pr__nfet_01v8 ad=1.44n pd=0.152m as=1.37n ps=0.148m w=35 l=23
X1 Y A VPWR VPWR sky130_fd_pr__pfet_01v8 ad=1.44n pd=0.152m as=1.52n ps=0.156m w=37 l=23
C0 VPWR Y 0.117f
C1 A Y 0.0754f
C2 A VPWR 0.0774f
C3 Y VGND 0.279f
C4 A VGND 0.45f
C5 VPWR VGND 0.781f
.ends
```

**A2. Cleaned simulation netlist** (written from my screenshots; not yet re-run)

```spice
* sky130_inv: post-layout transient simulation (cleaned version of my edited netlist)
* NOTE: written from my screenshots; NOT yet re-run after cleaning. Run from the vsdstdcelldesign folder:
*       ngspice sky130_inv.spice   (then:  plot y vs time a)
*
* Fixes compared with the file I saved on Sat 18:07:
*   - NMOS (to VGND) now uses nshort_model.0, PMOS (to VPWR) uses pshort_model.0   (they were swapped)
*   - PULSE has all seven parameters: V1 V2 TD TR TF PW PER

.option scale=0.01u
.include ./libs/pshort.lib
.include ./libs/nshort.lib

* devices (W, L in Magic units; scale converts to metres: w=35 -> 0.35 um, l=23 -> 0.23 um)
M0 Y A VGND VGND nshort_model.0 ad=1.44n pd=0.152m as=1.37n ps=0.148m w=35 l=23
M1 Y A VPWR VPWR pshort_model.0 ad=1.44n pd=0.152m as=1.52n ps=0.156m w=37 l=23

* supplies and stimulus
VDD VPWR 0 3.3V
VSS VGND 0 0V
Va A VGND PULSE(0V 3.3V 0 0.1ns 0.1ns 2ns 4ns)

* extracted parasitic capacitances
C0 VPWR Y 0.117f
C1 A Y 0.0754f
C2 A VPWR 0.0774f
C3 Y VGND 0.279f
C4 A VGND 0.45f
C5 VPWR VGND 0.781f

.tran 1n 20n

.control
run
plot y vs time a
.endc
.end
```

---

## Appendix B · Command cheat-sheet and glossary

#### Shell

| Command | What it does |
|---|---|
| `ls -ltr` | list files, oldest first (newest at the bottom) |
| `cp <file> <dir>` | copy, used to bring `sky130A.tech` into the work folder |
| `git clone <url>` | fetch the `vsdstdcelldesign` repository |
| `vim sky130_inv.spice` | edit the netlist |
| `ngspice sky130_inv.spice` | run the simulation |
| `magic -T sky130A.tech sky130_inv.mag &` | open the layout with the SKY130A technology |

#### Magic (type in the tkcon window)

| Command | What it does |
|---|---|
| `box` | print the size/position of the current box (microns, lambda, internal units) |
| `what` | list the layers in the current selection (confirmed nmos / pmos) |
| `pwd` | show the working folder (extraction writes here) |
| `extract all` | extract the layout to `<cell>.ext` |
| `ext2spice cthresh 0 rthresh 0` | keep all parasitic caps / resistances |
| `ext2spice` | write `<cell>.spice` |
| `drc why` | explain the DRC errors in the box |
| `load <cell>` | open another cell (e.g. `load poly`, `load met3`) |
| `paint <layer>` | paint a layer in the box (e.g. `paint m3contact`) |
| `erase <layer>` | erase a layer in the box |
| `cif see <layer>` | display a generated (mask) layer such as `VIA2` |
| `snap int` | snap the cursor to integer grid |

#### ngspice

| Item | Meaning |
|---|---|
| `.option scale=0.01u` | multiply every W/L by 0.01 µm |
| `.include file` | load model cards |
| `M<name> d g s b model w= l=` | MOSFET instance |
| `PULSE(V1 V2 TD TR TF PW PER)` | square-wave source |
| `.tran step stop` | transient analysis, e.g. `.tran 1n 20n` |
| `plot y vs time a` | plot Y and A against time |

#### Glossary

| Term | Meaning |
|---|---|
| **PDK** | Process design kit: tech files, models, rules for a fab process (here SKY130A) |
| **Tech file (`.tech`)** | Magic's definition of layers, DRC rules, extraction rules |
| **`.mag`** | Magic layout file |
| **`.ext`** | Extraction output (devices + parasitics) |
| **Parasitics** | Unwanted capacitance/resistance from the drawn geometry |
| **DRC** | Design rule check: geometric manufacturability rules |
| **LVS** | Layout vs schematic: does the layout implement the intended circuit? (not done yet) |
| **VTC** | Voltage transfer characteristic Vout(Vin) |
| **Vm** | Switching threshold: Vin = Vout |
| **LDD** | Lightly doped drain, a gentle implant that reduces drain-edge field |
| **BSIM4** | MOSFET compact model used in the `.lib` model cards |
| **Passivation** | Protective top layer, opened only at the pads (final mask) |


---
