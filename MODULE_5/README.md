# Verilog Practicals — Incomplete if/case , looping constructs

These are the snapshots from my practical sessions in the RTL Design & Synthesis Workshop. In this set, I was mainly exploring what actually happens — both in simulation and in synthesis — when I leave an if or a case incomplete, when I only partially assign outputs inside a case, and when a case is written badly enough that it causes an actual mismatch between RTL and gate-level simulation. Alongside that, I also practiced building a demux with a for loop, a mux with a generate for loop, and finally a full adder that leads into a Ripple Carry Adder (RCA).

## Overview

I wanted to actually see, with my own waveforms and schematics, why "incomplete" coding in if/case is called out as dangerous, instead of just taking it as a rule to memorize. So for each caveat, I wrote a small module, ran it through Yosys to see the synthesized schematic, and then ran GTKWave to see how the signals actually behaved. I did this for incomplete if, incomplete if-else if, incomplete case, partial assignment inside case, and a "bad case" that actually causes a synthesis-simulation mismatch. After that, I moved on to two looping-construct examples (a for-loop demux and a generate for-loop mux), and closed the session with a full adder synthesis, which is the building block for the Ripple Carry Adder I built next.

Every image below has my own short note next to it — what I was looking at, and what I actually understood from it. I've also kept the rough Verilog I used for each case and the commands I ran, mainly so I remember my own flow the next time I come back to this.

## Table of Contents

1. [Incomplete if](#1-incomplete-if)
   - 1.1 [Code I wrote](#1-incomplete-if)
   - 1.2 [Schematic](#1-incomplete-if)
   - 1.3 [Waveform](#1-incomplete-if)
2. [Incomplete if-else if (incomp_if2)](#2-incomplete-if-else-if-incomp_if2)
   - 2.1 [Code I wrote](#2-incomplete-if-else-if-incomp_if2)
   - 2.2 [Schematic](#2-incomplete-if-else-if-incomp_if2)
   - 2.3 [Waveform](#2-incomplete-if-else-if-incomp_if2)
3. [Incomplete case](#3-incomplete-case)
   - 3.1 [Code I wrote](#3-incomplete-case)
   - 3.2 [Schematic](#3-incomplete-case)
   - 3.3 [Waveform](#3-incomplete-case)
4. [Partial Assignment in case](#4-partial-assignment-in-case)
   - 4.1 [Code I wrote](#4-partial-assignment-in-case)
   - 4.2 [Waveform](#4-partial-assignment-in-case)
5. [Bad Case → Synthesis-Simulation Mismatch](#5-bad-case-overlapping-case--synthesis-simulation-mismatch)
   - 5.1 [Code I wrote](#5-bad-case-overlapping-case--synthesis-simulation-mismatch)
   - 5.2 [Schematic](#5-bad-case-overlapping-case--synthesis-simulation-mismatch)
   - 5.3 [RTL Waveform](#5-bad-case-overlapping-case--synthesis-simulation-mismatch)
   - 5.4 [GLS Waveform](#5-bad-case-overlapping-case--synthesis-simulation-mismatch)
6. [Demux Using for Loop](#6-demux-using-for-loop)
7. [Mux Using generate for Loop](#7-mux-using-generate-for-loop)
8. [Full Adder → Ripple Carry Adder (RCA)](#8-full-adder--ripple-carry-adder-rca)
9. [Blocking Caveat (Cross-Check)](#9-blocking-caveat-cross-check)
10. [Commands I Used (Yosys + Icarus + GTKWave)](#10-commands-i-used-yosys--icarus--gtkwave)
11. [Files in This Repo](#11-files-in-this-repo)
12. [What I Actually Took Away From This](#12-what-i-actually-took-away-from-this)

---

## 1. Incomplete `if`

This is just a plain if with no else attached to it. My thought going in was — if I don't write an else, what does the tool even do when the condition is false? Turns out, since there's no path defined for that case, the design can't just leave y undefined — it has to hold on to whatever value y had before.

```verilog
module incomp_if (input i0, input i1, input i2, output reg y);
  always @(*) begin
    if (i0)
      y = i1;
    // no else here — this is the problem
  end
endmodule
```

That "holding on to the previous value" is exactly what a latch does, so Yosys synthesizes this as a `$_DLATCH_P_` sitting between my inputs and `y`.

[incomp_if schematic]<img width="1920" height="983" alt="01_incomp_if_schematic" src="https://github.com/user-attachments/assets/c621e739-1119-4b74-9a88-077402561e2e" />


And when I actually looked at the waveform, this became obvious — instead of `y` reacting immediately to `i0`, `i1`, `i2` like a normal combinational signal should, there's a flat stretch (marked in red) where `y` just doesn't move at all. That flat patch is the latch doing exactly what a latch does — holding its state.

[incomp_if waveform]<img width="1920" height="983" alt="02_incomp_if_waveform" src="https://github.com/user-attachments/assets/6d7557bf-dde8-4587-b37d-6def8cea5ac3" />


## 2. Incomplete `if-else if` (incomp_if2)

Next I tried the same experiment but with a chain — `if`, `else if`, and then nothing after that. I expected this to behave a bit better since there are two conditions being checked instead of one, but the underlying issue doesn't go away.

```verilog
module incomp_if2 (input i0, input i1, input i2, input i3, output reg y);
  always @(*) begin
    if (i0)
      y = i1;
    else if (i2)
      y = i3;
    // still no final else
  end
endmodule
```

The schematic shows a mux and a nor-gate combination still feeding into a `$_DLATCH_N_`, because there's still one combination of inputs that isn't explicitly handled by either branch.

[incomp_if2 schematic]<img width="1920" height="983" alt="03_incomp_if2_schematic" src="https://github.com/user-attachments/assets/26cbdb25-fd02-405c-9a44-345d8b3b9884" />


Same story on the waveform side — `y` holds its value for a stretch before catching up again. This confirmed for me that it doesn't matter how many `else if` branches I chain — if the very last `else` is missing, I'm going to get a latch, full stop.

[incomp_if2 waveform]<img width="1920" height="983" alt="04_incomp_if2_waveform" src="https://github.com/user-attachments/assets/459146f4-c4ee-4612-99d3-f465968a5135" />


## 3. Incomplete `case`

Same caveat, different statement. This time I wrote a `case` block but didn't add a `default`, so one particular `sel` value has nothing tied to it.

```verilog
module incomp_case (input i0, input i1, input i2, input [1:0] sel, output reg y);
  always @(*) begin
    case (sel)
      2'b00: y = i0;
      2'b01: y = i1;
      // 2'b10 and 2'b11 not handled — missing default
    endcase
  end
endmodule
```

I wanted to see if `case` behaves any differently from `if` in this regard — it doesn't. Since one `sel` combination is unhandled, synthesis has no option but to infer a latch to cover that missing branch.

[incomp_case schematic]<img width="1920" height="983" alt="05_incomp_case_schematic" src="https://github.com/user-attachments/assets/2c7a48f0-1548-4c68-935a-7631ba69cf31" />


On the waveform, every time `sel` lands on that missing value, `y` just freezes instead of updating. This is the same symptom as the incomplete `if` case above — which really drove home the point that `if` and `case` share this exact same danger, just dressed up differently in the syntax.

[incomp_case waveform]<img width="1920" height="983" alt="06_incomp_case_waveform" src="https://github.com/user-attachments/assets/15f9b954-bbfd-4204-ab96-faa28c0472cb" />


## 4. Partial Assignment in `case`

This one caught me off guard a little. I made sure my `case` was "complete" this time — every `sel` value has a branch. But inside one of those branches, I only assigned one of my two output signals and forgot the other one.

```verilog
always @(*) begin
  case (sel)
    2'b00: begin x = a; end          // y not assigned here!
    2'b01: begin x = c; y = b; end
    default: begin x = d; y = b; end
  endcase
end
```

Even though the `case` looks complete on paper, that one output I forgot about still infers a latch, because for that particular branch, it still doesn't have a defined value. The lesson I took from this: "complete case" isn't just about covering every `sel` value — I also have to make sure *every output* is driven in *every* branch.

[partial_case waveform]<img width="1920" height="983" alt="07_partial_case_waveform" src="https://github.com/user-attachments/assets/b483140c-5a17-4014-b530-97ec8bede259" />


## 5. Bad Case (Overlapping Case → Synthesis-Simulation Mismatch)

This is the one I found the most interesting out of all of these. I built a 4:1 mux using a `case` statement, but wrote the case items in a way that overlaps or doesn't cleanly separate the `sel` combinations.

```verilog
module bad_case (input i0, input i1, input i2, input i3,
                  input [1:0] sel, output reg y);
  always @(*) begin
    case (sel)
      2'b00: y = i0;
      2'b01: y = i1;
      2'b10: y = i2;
      2'b1?: y = i3;   // overlapping / careless bit-pattern
    endcase
  end
endmodule
```

The synthesized schematic still looks like a normal 4:1 mux (`sky130_fd_sc_hd__mux4_2`) on the outside.

[bad_case schematic]<img width="1920" height="983" alt="08_bad_case_schematic" src="https://github.com/user-attachments/assets/2d3a1896-5124-43c9-b0c8-7ff272634987" />


When I ran the RTL simulation first, `y` followed the inputs and `sel` exactly the way I'd written the Verilog — nothing looked wrong at this stage.

[bad_case RTL waveform]<img width="1920" height="983" alt="09_bad_case_rtl_waveform" src="https://github.com/user-attachments/assets/f4f6934e-a712-4cc3-966a-c9adad2d503e" />


But then I ran GLS — same testbench, but now pointed at the synthesized netlist instead of the RTL — and `y` did NOT match what I saw in the RTL run for some `sel` values. This was the first time I actually saw a synthesis-simulation mismatch with my own eyes instead of just reading about it, and it made it very clear why this "bad case" style of coding is called out as dangerous — the RTL sim can lie to me about what the real hardware is going to do.

[bad_case GLS waveform]<img width="1920" height="983" alt="10_bad_case_gls_waveform" src="https://github.com/user-attachments/assets/94bfc4c8-058a-4862-a27b-0a0a1dcdca53" />


## 6. Demux Using `for` Loop

Moving away from the latch caveats for a bit, I built a demux using a `for` loop inside an `always` block. The idea is simple: one input `i` gets routed to exactly one of 8 outputs (`o0` through `o7`), depending on what `sel` currently is. Internally this comes out as a bunch of AND/NOR gates, one per output line, built up by the loop evaluating its condition for each value of `sel`.

[demux_case schematic]<img width="1920" height="982" alt="11_demux_case_schematic" src="https://github.com/user-attachments/assets/5f82a682-4dd2-43e1-a9e1-26f66da6854c" />


On the waveform, I can see `i` toggling, and depending on where `sel` is, that toggling only shows up on one of the `o` lines at a time — everything else stays flat. This is exactly the demux behavior I was expecting, and it's a nice concrete example of what "the `for` loop is just evaluating expressions, not generating hardware" actually looks like in practice.

[demux_case waveform]<img width="1920" height="982" alt="12_demux_case_waveform" src="https://github.com/user-attachments/assets/7b33dae9-4f65-4320-ba7a-9b22218f814d" />


## 7. Mux Using `generate for` Loop

This one's the opposite side of the coin — a `generate for` loop, which actually replicates/instantiates hardware instead of just evaluating an expression. Here I used it to build a 4:1 mux (`mux4_2`) that feeds into a latch, with `sel` choosing between `i0` through `i3`.

[mux_generate schematic]<img width="1920" height="982" alt="13_mux_generate_schematic" src="https://github.com/user-attachments/assets/1e1bee44-6a6d-4f29-a1aa-387f3f73be6c" />


The waveform shows `y` tracking whichever input `sel` is currently pointing to, while `i_int` cycles through all the input combinations. Comparing this to the demux example above helped me really lock in the difference between the two looping constructs — one (`for`) evaluates, the other (`generate for`) builds.

[mux_generate waveform]<img width="1920" height="982" alt="14_mux_generate_waveform" src="https://github.com/user-attachments/assets/ded8e9e6-81ab-42e0-a59b-f9ac97ab54c8" />


## 8. Full Adder → Ripple Carry Adder (RCA)

Before jumping into the full Ripple Carry Adder, I synthesized just a single full adder (`fa`) on its own to see what it collapses down to. It came out as a `maj3` gate (majority-of-3) for the carry-out, and an `xor3` gate for the sum — a nice clean way to see that a full adder is really just those two functions computed on `a`, `b`, and `c` together.

[full adder schematic]<img width="1920" height="982" alt="15_full_adder_schematic" src="https://github.com/user-attachments/assets/78bbca32-6ee3-49a5-bf19-3ef7dad32f93" />


Then I put together the full `tb_rca` testbench, added `num1` and `num2`, and checked that `sum_out` was coming out correctly — one bit wider than the inputs, which lines up exactly with the addition rule I noted down earlier (N-bit + N-bit = N+1 bit result). Seeing sums like `93 + 6 = 99` land correctly on the waveform was a good sanity check that the whole chain of full adders was ripple-carrying properly.

[rca waveform]<img width="1920" height="982" alt="16_rca_waveform" src="https://github.com/user-attachments/assets/1a1b1c84-8d49-469c-ace8-1d06ab117ec7" />


## 9. Blocking Caveat (Cross-Check)

I'm keeping this one here too, even though I already covered the blocking-caveat design in an earlier module, because it was part of the same batch of screenshots I took during this session — this is the GLS waveform of that same `blocking_caveat` design, just as a quick cross-check while I was going back through all my snapshots together.

[blocking_caveat GLS waveform]<img width="1147" height="634" alt="17_blocking_caveat_gls_waveform" src="https://github.com/user-attachments/assets/cf6472d4-68c5-4400-988a-8ccfb24d2884" />


---

## 10. Commands I Used (Yosys + Icarus + GTKWave)

Just noting my usual flow here so I don't forget it:

**RTL simulation:**
```bash
iverilog design.v tb_design.v
./a.out
gtkwave tb_design.vcd
```

**Synthesis with Yosys:**
```bash
yosys
read_liberty -lib ../lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog design.v
synth -top design
abc -liberty ../lib/sky130_fd_sc_hd__tt_025C_1v80.lib
show
write_verilog -noattr design_net.v
```

**GLS (gate-level simulation):**
```bash
iverilog ../my-lib/verilog-model/primitives.v \
         ../my-lib/verilog-model/sky130_fd_sc_hd.v \
         design_net.v tb_design.v
./a.out
gtkwave tb_design.vcd
```

## 11. Files in This Repo

```
verilog-case-mux-rca-notes/
├── README.md
└── images/
    ├── 01_incomp_if_schematic.png
    ├── 02_incomp_if_waveform.png
    ├── 03_incomp_if2_schematic.png
    ├── 04_incomp_if2_waveform.png
    ├── 05_incomp_case_schematic.png
    ├── 06_incomp_case_waveform.png
    ├── 07_partial_case_waveform.png
    ├── 08_bad_case_schematic.png
    ├── 09_bad_case_rtl_waveform.png
    ├── 10_bad_case_gls_waveform.png
    ├── 11_demux_case_schematic.png
    ├── 12_demux_case_waveform.png
    ├── 13_mux_generate_schematic.png
    ├── 14_mux_generate_waveform.png
    ├── 15_full_adder_schematic.png
    ├── 16_rca_waveform.png
    └── 17_blocking_caveat_gls_waveform.png
```

## 12. What I Actually Took Away From This

- Incomplete `if` and incomplete `case` are really the same problem wearing different syntax — anywhere a condition isn't handled, the tool infers a latch to hold the previous value.
- A `case` can look "complete" (every `sel` value handled) and still infer a latch if I forget to assign one of my output signals inside a branch — completeness has to be checked per-output, not just per-condition.
- The "bad case" example is the one that matters most for me going forward — it's the first time I actually saw RTL and GLS disagree with my own eyes, and it's a real reminder that clean, non-overlapping `case` writing isn't just a style preference.
- `for` loops (inside `always`) evaluate expressions — they don't create extra hardware by themselves; `generate for` loops (outside `always`) do the opposite and actually replicate hardware.
- A full adder collapses to a `maj3` + `xor3` pair at the gate level, and chaining these together is literally what a Ripple Carry Adder is — the output width growing by exactly one bit is the same addition rule I noted down before I even built the RCA.
- My own flow for all of this stayed the same throughout: write RTL → simulate → synthesize with Yosys → run GLS on the netlist → compare waveforms. Having that flow fixed in my head made every one of these caveats a lot easier to actually verify instead of just trusting the textbook explanation.

## Next Time

A few things I want to carry forward into my next session:

- Before writing any `if`/`case` block, I want to get into the habit of asking myself "have I handled every single input combination, and does every output get a value in every branch?" — basically doing the latch-check mentally before Yosys has to point it out to me.
- I want to re-run the `bad_case` example but fix the overlapping `sel` pattern properly, then re-check GLS against RTL again to confirm the mismatch actually goes away once the case is written cleanly.
- I still need to extend the single full adder into the complete 8-bit Ripple Carry Adder chain and verify the carry propagates correctly all the way through, not just for the couple of test values I checked here.
- I want to compare the `for`-loop demux and `generate for`-loop mux side by side in one write-up, since seeing them back-to-back like this made the "evaluate vs instantiate" distinction click a lot better than reading about it on its own.
