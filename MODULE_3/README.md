## 📑 Table of Contents

- [Overview](#overview)
- [Logic Optimization](#logic-optimization)
- [Combinational Logic Optimization](#combinational-logic-optimization)
- [Constant Propagation](#constant-propagation)
- [Boolean Logic Optimization](#boolean-logic-optimization)
- [Sequential Logic Optimization](#sequential-logic-optimization)
- [Basic Sequential Optimization](#basic-sequential-optimization)
- [Synthesis and Optimization](#synthesis-and-optimization)
- [Results and Observations](#results-and-observations)
- [Conclusion](#conclusion)

---

## 📌 Overview

In this module, I worked on **Logic Optimization** using RTL Verilog and synthesis tools.

I explored **Combinational Logic Optimization**, mainly Constant Propagation and Boolean Logic Optimization, followed by **Basic Sequential Logic Optimization**.

I also used **Yosys scripting for synthesis and optimization** and **GTKWave to check the simulation waveforms and verify the outputs**.

---
# 1. Introduction

In this module, I worked on Logic Optimization using the Yosys synthesis environment in the VSDIAT platform.

The main purpose of logic optimization is to simplify a digital circuit without changing its functionality. When we write a Verilog design, the RTL may contain unnecessary logic, redundant operations, or logic that can be replaced by a much simpler circuit.

The optimization process tries to reduce this unnecessary hardware so that the final design can have:

1. Less area
2. Less power consumption
3. Less logic complexity
4. Fewer gates
5. Better overall hardware efficiency

In this module, I divided logic optimization into two major categories:
```
Logic Optimization
│
├── Combinational Logic Optimization
│   ├── Constant Propagation
│   └── Boolean Logic Optimization
│
└── Sequential Logic Optimization
    └── Basic Sequential Optimization
```
The advanced sequential optimization topics were discussed theoretically but were not implemented in my practical work.

---
# 2. Combinational Logic Optimization

Combinational circuits are circuits where the output depends only on the present input values.

Examples include:

- AND gates
- OR gates
- NOT gates
- Multiplexers
- Adders
- Decoders

While writing RTL, a circuit may contain more logic than actually required. Therefore, Yosys can analyze the logic and simplify it while preserving the same input-output behavior.

In my practical work, I focused on two techniques:

- Constant Propagation
- Boolean Logic Optimization
 
---

# 3. Constant Propagation

Constant propagation is one of the simplest optimization techniques.

The basic idea is that if the value of an input is already known to be a constant, we can substitute that value throughout the logic and remove the logic that becomes unnecessary.

For example, consider:

Y = ((A & B) + C)'

Initially, the circuit contains:
```
A ──┐
    AND ──┐
B ──┘     │
          OR ── NOT ── Y
C ────────┘
```
Now suppose:
```
A = 0
```
Then:
```
A & B = 0 & B
       = 0
```
So the expression becomes:
```
Y = (0 + C)'
```
Therefore:
```
Y = C'
```
The original circuit required an AND gate, OR gate and NOT gate.
After constant propagation, only the NOT operation is required.
So the circuit changes from:
```
AND + OR + NOT
```
to:
```
NOT
```
This is the main idea I demonstrated in my practical work.
<img width="1901" height="970" alt="Screenshot 2026-08-19 204949" src="https://github.com/user-attachments/assets/c3175e5e-c83f-4adc-a660-537b8a835c04" />
if:
```
A=0 and B=0
```
we get:

<img width="1302" height="703" alt="Screenshot 2026-08-22 201406" src="https://github.com/user-attachments/assets/d8bfde7b-e5f6-447e-8e09-be82b719e4c7" />

## What I observed

When a constant value was applied to the input, Yosys was able to identify that some parts of the circuit could never affect the output.
Those unnecessary portions were removed during optimization.
This is called constant propagation because the known constant value is propagated through the logic.

---
# 4. Boolean Logic Optimization

The second part of combinational optimization is Boolean logic optimization.

Here, instead of simply replacing a known constant, the synthesis tool analyzes the Boolean logic and tries to simplify the expression.

For example, a circuit may contain multiple logic levels or redundant operations.

Instead of implementing every operation exactly as written in RTL, Yosys can transform the logic into an equivalent but simpler form.

The important point is:

``` The optimized circuit must produce the same output for every valid combination of inputs.```
So optimization does not mean changing the functionality.
It means finding a simpler implementation of the same functionality.
In my practical work, I used simple combinational examples and observed how Yosys reduced the logic.
For example, a multiplexer-based expression can sometimes be simplified into a direct Boolean expression.

The basic flow was:
```
Verilog RTL
     ↓
Read by Yosys
     ↓
Analyze Logic
     ↓
Boolean Optimization
     ↓
Remove Redundant Logic
     ↓
Optimized Design
```
Few synthesis snapshots of combinational logic optimisation:
<img width="604" height="635" alt="Screenshot 2026-08-20 214718" src="https://github.com/user-attachments/assets/a502dde6-ec1c-4dee-82e2-0a5adaa3a77c" />
<img width="608" height="635" alt="Screenshot 2026-08-20 214901" src="https://github.com/user-attachments/assets/1aac772f-dfba-4e02-b583-cd0684668c4d" />
<img width="600" height="578" alt="Screenshot 2026-08-20 215627" src="https://github.com/user-attachments/assets/a802d605-99f7-4924-a2ed-bc1e544ff53e" />
<img width="640" height="365" alt="Screenshot 2026-08-20 220043" src="https://github.com/user-attachments/assets/9838d474-92e0-4840-85e8-6fd163386434" />

---
# 5. Sequential Logic Optimization

After combinational optimization, I moved to Sequential Logic Optimization.
The major difference is that sequential circuits contain memory elements such as:

- Flip-flops
- Registers
- Counters
- State elements

Unlike combinational circuits, their output can depend on previous states.
In my Module 3 practical work, I focused only on the basic sequential optimization part.
The advanced topics such as:

- State optimization
- Retiming
- Sequential logic cloning

were not implemented.
So my practical scope was:
```
Sequential Logic Optimization
            │
            ▼
Basic Sequential Optimization
            │
            ▼
Sequential Constant Propagation
```
Few synthesis snapshots of sequential logic optimisation:
<img width="609" height="299" alt="Screenshot 2026-08-20 222922" src="https://github.com/user-attachments/assets/12424dd0-e991-4c4d-8fd0-942254539eb9" />
<img width="144" height="114" alt="Screenshot 2026-08-20 223609" src="https://github.com/user-attachments/assets/30954693-3395-409e-8e73-57350cafec6a" />
<img width="600" height="170" alt="Screenshot 2026-08-20 223722" src="https://github.com/user-attachments/assets/b532977c-d0e0-4c70-a9a6-4f5d92157a60" />
<img width="580" height="557" alt="Screenshot 2026-08-20 223913" src="https://github.com/user-attachments/assets/b411d955-1034-40fb-aa3c-974effba7e4c" />

---
# 6. Sequential Constant Propagation

Sequential constant propagation is similar to the combinational case, but it is applied to circuits containing sequential elements.
For example, consider a D flip-flop:
```
        ┌─────────┐
D ─────►│    D    │
CLK ───►│   DFF   │────► Q
RESET ─►│         │
        └─────────┘
```
If the input D is permanently fixed to a constant value, the synthesis tool can analyze whether the output Q is also forced to a constant.
For example:
```
D = 0
```
If the reset and clock behavior guarantee that the flip-flop output remains fixed, Yosys can identify that the sequential element is unnecessary.
The optimization can therefore remove unnecessary sequential hardware.

---
# 7. Practical Sequential Optimization

In my practical work, I created D flip-flop based examples and applied constant values to the sequential logic.
I then ran the Yosys optimization flow and observed the resulting design.
The important observation was that Yosys does not blindly preserve every flip-flop written in RTL.
Instead, it analyzes whether that flip-flop is actually required for the functionality of the circuit.
If its output is permanently determined, the logic can potentially be simplified.
This helped me understand that optimization is not only about reducing combinational gates. Sequential elements can also become unnecessary depending on how the RTL is written.

---
# 8. GTKWave – Simulation and Verification

GTKWave was used along with the Yosys flow to verify the functionality of the designs.
This part is important to explain correctly:
GTKWave itself does not perform logic optimization.
Yosys performs the synthesis and optimization.
GTKWave is used to observe the simulation results and verify that the optimized design behaves as expected.

The general flow is:
```
Verilog Design
      ↓
Testbench
      ↓
Simulation
      ↓
VCD File
      ↓
GTKWave
      ↓
Observe Waveforms
```
waveforms of combinational and sequential optimisation:
<img width="1256" height="1068" alt="Screenshot 2026-08-20 213244" src="https://github.com/user-attachments/assets/dc8c7307-5021-406d-9548-905690ba3ce3" />
<img width="954" height="659" alt="Screenshot 2026-08-20 213539" src="https://github.com/user-attachments/assets/cf4055ef-2492-4867-98c8-44eab49f4319" />
<img width="951" height="507" alt="Screenshot 2026-08-20 213851" src="https://github.com/user-attachments/assets/edfaabcc-c993-4b85-9c82-617f79599fa6" />
<img width="950" height="473" alt="Screenshot 2026-08-20 221235" src="https://github.com/user-attachments/assets/81e82b60-9495-4065-bdd1-40fc5927cfb6" />
<img width="953" height="476" alt="Screenshot 2026-08-20 221432" src="https://github.com/user-attachments/assets/705223e6-18f0-4a14-b38a-e06dc58ad2ab" />
I verified the waveforms of the optimised verilog_files with the initial waveforms

---
# 9. Why GTKWave Was Important

Using GTKWave gave me a second level of verification.
I could verify the design in two ways:

Before optimization
```
RTL
 ↓
Simulation
 ↓
GTKWave
After optimization
Optimized RTL
 ↓
Simulation
 ↓
GTKWave
```
If both designs produce the same output for the same input sequence, then the optimization has preserved the intended functionality.
So the overall concept I followed was:
```
Optimization
     ↓
Reduce unnecessary hardware
     ↓
Preserve functionality
     ↓
Verify using simulation
     ↓
Observe using GTKWave
```
---
# 10. Complete Module 3 Practical Flow

The complete flow of my work can therefore be represented as:
```
                    MODULE 3
               LOGIC OPTIMIZATION
                       │
          ┌────────────┴────────────┐
          │                         │
          ▼                         ▼
   COMBINATIONAL              SEQUENTIAL
   OPTIMIZATION               OPTIMIZATION
          │                         │
     ┌────┴────┐              Basic only
     │         │                    │
     ▼         ▼                    ▼
 Constant   Boolean          Sequential
 Propagation Logic           Constant
                             Propagation
     │         │                    │
     └────┬────┘                    │
          │                         │
          └────────────┬────────────┘
                       ▼
                  YOSYS OPT
                       │
                       ▼
                Optimized RTL
                       │
                       ▼
                  Simulation
                       │
                       ▼
                   GTKWave
                       │
                       ▼
                Waveform Analysis
                       │
                       ▼
             Functional Verification
```
---
# 11. What I Actually Learned

The main thing I understood from this module is that RTL code is not necessarily the final hardware implementation.

When we write:
```
assign y = some_logic;
```
we are describing functionality.

The synthesis tool then analyzes that description and asks:
```
"Can I implement the same functionality with less logic?"
```
That is where optimization comes in.

Through my experiments, I understood:

Constant propagation removes logic whose behavior is already determined by constants.
Boolean optimization simplifies redundant or unnecessarily complex Boolean logic.
Sequential optimization can remove sequential elements whose outputs are permanently determined.
Yosys performs the actual optimization.
show allows the optimized circuit structure to be visually inspected.
GTKWave allows the optimized design to be functionally verified.
Optimization should reduce unnecessary hardware without changing the output behavior.
