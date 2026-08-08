# RTL Design, Simulation & Logic Synthesis using Verilog, Icarus Verilog and Yosys

## 📌 Overview

This repository contains my learning and practical work on **RTL Design, Verilog Simulation, Testbenches, Waveform Analysis, Logic Synthesis and Standard-Cell Libraries**.

The classes helped me understand the complete flow from writing an RTL design to verifying its functionality and finally converting it into a gate-level representation.

The major tools used in this learning process are:

- **Verilog HDL** – RTL design and testbench development
- **Icarus Verilog** – RTL simulation
- **GTKWave** – waveform visualization
- **Yosys** – logic synthesis
- **Liberty (.lib)** – standard-cell library information
- **Netlist** – synthesized gate-level representation

---

## 📑 Table of Contents

1. [Objectives](#-objectives)
2. [Tools Used](#-tools-used)
3. [RTL Design](#-rtl-design)
4. [Design, Testbench and Simulator](#-design-testbench-and-simulator)
5. [Simulation Flow](#-simulation-flow)
6. [Icarus Verilog and GTKWave](#-icarus-verilog-and-gtkwave)
7. [Logic Synthesis](#-logic-synthesis)
8. [Standard-Cell Library](#-standard-cell-library)
9. [Fast, Medium and Slow Cells](#-fast-medium-and-slow-cells)
10. [Timing Concepts](#-timing-concepts)
11. [Hierarchy and Flattening](#-hierarchy-and-flattening)
12. [Sequential Logic and Reset](#-sequential-logic-and-reset)
13. [Combinational Logic and Glitches](#-combinational-logic-and-glitches)
14. [Optimization and Constraints](#-optimization-and-constraints)
15. [Example Verilog Codes](#-example-verilog-codes)
16. [Overall Learning](#-overall-learning)
17. [synthesis_waveforms](#-synthesis_waveforms)
18. [Summary](#-summary)

---

# 🎯 Objectives

The main objectives of this learning process were:

- Understand the fundamentals of **RTL design using Verilog HDL**.
- Learn how to write and verify Verilog modules.
- Understand the purpose of a **testbench**.
- Simulate RTL designs using **Icarus Verilog**.
- Analyze signal transitions using **GTKWave**.
- Understand the difference between **design and testbench**.
- Learn the basic flow of **RTL-to-gate-level synthesis**.
- Understand the role of **standard-cell libraries (.lib)**.
- Learn how synthesis tools select suitable logic cells.
- Understand **fast, medium and slow standard cells**.
- Understand basic timing concepts such as:
  - Propagation delay
  - Setup time
  - Hold time
  - Clock-to-Q delay
- Understand **hierarchical and flattened netlists**.
- Understand synchronous and asynchronous reset behavior.
- Understand how synthesis optimization affects **area, power and timing**.

---

# 🛠️ Tools Used

| Tool | Purpose |
|------|---------|
| **Verilog HDL** | RTL design and testbench coding |
| **Icarus Verilog** | Verilog compilation and simulation |
| **GTKWave** | Viewing simulation waveforms |
| **Yosys** | RTL synthesis and netlist generation |
| **Standard Cell `.lib`** | Cell timing, power and area information |
| **VCD File** | Stores simulation value changes |
| **Netlist** | Gate-level representation of the design |

---

# 🔹 RTL Design

**RTL (Register Transfer Level)** is a way of describing how data moves between registers through combinational logic.

A Verilog RTL design describes the intended functionality of the hardware.

Example:

```verilog
module and_gate (
    input  a,
    input  b,
    output y
);

assign y = a & b;

endmodule
```
a and b are primary inputs.
y is the primary output.
The RTL describes an AND operation.

---
## 🔹 Design, Testbench and Simulator
Design

The design is the actual Verilog module that represents the required hardware functionality.

Example:

        a ─────┐
               │
             AND ─── y
               │
        b ─────┘
Testbench

A testbench (TB) is used to provide test inputs to the design and observe its outputs.

The testbench normally does not represent physical hardware. Its main purpose is verification.

Example:
```
module tb;

reg a;
reg b;
wire y;

and_gate dut (
    .a(a),
    .b(b),
    .y(y)
);

initial begin
    a = 0; b = 0;
    #10 a = 0; b = 1;
    #10 a = 1; b = 0;
    #10 a = 1; b = 1;
    #10 $finish;
end

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb);
end

endmodule
```
---
## 🔹 Simulation Flow

The basic RTL simulation flow is:

        ┌─────────────┐
        │ RTL Design  │
        └──────┬──────┘
               │
               │
        ┌──────▼──────┐
        │  Testbench  │
        └──────┬──────┘
               │
               ▼
       ┌────────────────┐
       │ Icarus Verilog │
       └───────┬────────┘
               │
               ▼
          VCD File
               │
               ▼
          GTKWave
               │
               ▼
       Waveform Analysis

The simulator evaluates the design whenever relevant input or event changes occur.

---
##  🔹 Introduction to Yosys

Yosys is an open-source framework used for RTL synthesis.

A basic synthesis flow can be:
Inside Yosys:
```

read_verilog design.v
hierarchy -top design
proc
opt
techmap
abc
```
A netlist can then be generated using:
```
write_verilog netlist.v
```
The synthesized design can be inspected to understand how the RTL is represented using gates and standard cells.

---
## 🔹 Standard-Cell Library

A standard-cell library contains pre-designed and characterized cells used during synthesis and physical implementation.

Typical cells include:

1.AND
2.OR
3.NAND
4.NOR
5.NOT
6.XOR
7.Multiplexer
8.Flip-Flops
9.Buffers
10.Clock cells

Different versions of the same logic function can exist.

For example:
```
AND2_X1
AND2_X2
AND2_X4
```
The suffix generally indicates different drive strengths or cell sizes.

---
## 🔹 Liberty .lib File

The Liberty file (.lib) contains information about standard cells.

It may contain:

1 Cell functionality
2 Timing information
3 Power information
4 Area
5 Input capacitance
6 Output drive characteristics
7 Setup and hold information

Example conceptual structure:
```
cell (AND2_X1) {
    area : ...;

    pin(A) {
        direction : input;
        capacitance : ...;
    }

    pin(Y) {
        direction : output;
        function : "A & B";
    }
}
```
The synthesis tool uses this information to select suitable cells.

---
---
## 🔹 Fast, Medium and Slow Cells

Standard-cell libraries can provide cells with different performance characteristics.

For example:
```
Slow Cell
   ↓
Lower drive strength
Smaller area
Lower power
Higher delay

Medium Cell
   ↓
Balanced performance

Fast Cell
   ↓
Higher drive strength
Larger area
Higher power
Lower delay
```
A faster cell is not always the best choice.

The synthesis tool tries to find a suitable trade-off between:
```
Timing
Area
Power
Drive strength
Load
```
---
## 🔹 Why Faster Cells Are Required

In a synchronous digital circuit:
```
Flip-Flop A
    │
    ▼
Combinational Logic
    │
    ▼
Flip-Flop B
```
The data must reach Flip-Flop B within the available clock period.

A simplified timing relationship is:
```
Tclk >= Tcq + Tcomb + Tsetup
```
where:

Tclk = clock period
Tcq = clock-to-Q delay
Tcomb = combinational logic delay
Tsetup = setup time of receiving flip-flop

Therefore:
```
Higher combinational delay
        ↓
Lower maximum operating frequency
```
and approximately:

Fmax ≈ 1 / Tclk

---
## 🔹 Setup Time

Setup time is the minimum amount of time for which the input data must remain stable before the active clock edge.

If data arrives too late, a setup-time violation can occur.
```
Data ────────────────┐
                     │
                     ▼
Clock ───────────────┼──► Capture
                     ↑
                 Setup Time
```
---
## 🔹 Hold Time

Hold time is the minimum amount of time for which the data must remain stable after the active clock edge.

A hold violation can occur if new data reaches the receiving flip-flop too quickly.

Conceptually:
```
Clock edge
    │
    ▼
────┼────────────────
    │<-- Hold Time -->
    │
```
Data must remain stable

Therefore, simply using faster cells is not always good.

Very fast data paths can create hold-time violations.

---
## 🔹 Combinational Delay and Cell Size

A digital gate drives a certain load capacitance.

A simplified relationship is:
```
Higher Load
     ↓
More charging/discharging time
     ↓
Higher delay
```
Increasing the drive strength of a cell can reduce delay.

However:
```
Higher drive strength
       ↓
Larger transistor size
       ↓
More area + potentially more power
```
Therefore, synthesis is an optimization problem.

---
## 🔹 Hierarchy and Multiple Modules

Large RTL designs are usually divided into multiple modules.

Example:
```
Top Module
│
├── Sub Module 1
│
├── Sub Module 2
│
└── Sub Module 3
```
This is called hierarchical design.

Example:
```
module top (
    input  a,
    input  b,
    input  c,
    output y
);

wire w1;

sub_module u1 (
    .a(a),
    .b(b),
    .y(w1)
);

sub_module u2 (
    .a(w1),
    .b(c),
    .y(y)
);

endmodule
```
Hierarchy makes large designs easier to understand, debug and reuse.

---
## 🔹 Flattening

During synthesis, hierarchy may be preserved or flattened.

Flattening removes module boundaries and creates a more unified representation of the logic.

Conceptually:
```
Hierarchical Design

TOP
 ├── Module A
 └── Module B

        ↓ Flatten
```
Single Combined Logic Representation

Flattening can help optimization because the synthesis tool gets more freedom to optimize logic across module boundaries.

---
## 🔹 Constraints and Optimization

Synthesis does not simply convert RTL into gates.

It also tries to satisfy design requirements.

Important optimization parameters include:

Timing
Area
Power
Functionality
Load
Drive strength
Technology library

The general idea is:
```
RTL
 ↓
Synthesis
 ↓
Optimization
 ↓
Technology Mapping
 ↓
Gate-Level Netlist
```
---
## 🔹 Combinational Logic and Glitches

A glitch is an unwanted temporary transition in a digital signal caused by different propagation delays along different logic paths.

Example:
```
Input A ──► Logic Path 1 ──┐
                          ├──► Output
Input B ──► Logic Path 2 ──┘
```
If the two paths have different delays, the output can temporarily change before reaching its final value.

This becomes more important in larger combinational circuits.

---
## 🔹 Sequential Logic and Flip-Flops

A flip-flop stores one bit of information and changes its output according to the clock.

Example:
```
module dff (
    input clk,
    input d,
    output reg q
);

always @(posedge clk)
    q <= d;

endmodule
```
The important point is that the output changes only at the active clock edge.

---
## 🔹 Synchronous Reset

A synchronous reset is evaluated with the clock.
```
always @(posedge clk) begin
    if (reset)
        q <= 1'b0;
    else
        q <= d;
end
```
Here, q becomes zero when reset is active at the clock edge.

---
## 🔹 Asynchronous Reset

An asynchronous reset does not need to wait for the clock edge.
```
always @(posedge clk or posedge reset) begin
    if (reset)
        q <= 1'b0;
    else
        q <= d;
end
```
Here, the flip-flop can be reset immediately when reset becomes active.

---
## 🔹 Multiplexer Concept

A multiplexer selects one of multiple inputs.

For a 2:1 MUX:
```
        ┌─────┐
I0 ────►│     │
I1 ────►│ MUX ├──► Y
S ─────►│     │
        └─────┘
```
Verilog implementation:
```
module mux2 (
    input  a,
    input  b,
    input  sel,
    output y
);

assign y = sel ? b : a;

endmodule
```
---
## 🔹 Arithmetic Optimization

Some arithmetic operations can be implemented using simple wiring rather than complex hardware.

For example:

y = 2 × a

For a binary number, multiplication by 2 is equivalent to a left shift:

y = a << 1;

Example:
```
assign y = a << 1;

For a 3-bit input:

a = a[2:0]

y = {a[2:0], 1'b0}
```
This avoids requiring a general-purpose multiplier for a simple constant multiplication.

---
🔹 Example: Simple ALU
```
module simple_alu (
    input  [3:0] a,
    input  [3:0] b,
    input  [1:0] sel,
    output reg [3:0] y
);

always @(*) begin
    case (sel)
        2'b00: y = a + b;
        2'b01: y = a - b;
        2'b10: y = a & b;
        2'b11: y = a | b;
    endcase
end

endmodule
```
This example demonstrates how RTL can describe multiple operations using a single module.

---
🔹 Example Testbench
```
module tb;

reg [3:0] a;
reg [3:0] b;
reg [1:0] sel;

wire [3:0] y;

simple_alu dut (
    .a(a),
    .b(b),
    .sel(sel),
    .y(y)
);

initial begin

    a = 4'b0101;
    b = 4'b0011;
    sel = 2'b00;

    #10 sel = 2'b01;
    #10 sel = 2'b10;
    #10 sel = 2'b11;

    #10 $finish;

end

initial begin
    $dumpfile("alu.vcd");
    $dumpvars(0, tb);
end

endmodule
```
# Synthesis_Waveforms
<img width="954" height="359" alt="Screenshot 2026-08-09 021245 - Copy"
src="https://github.com/user-attachments/assets/2479a890-dea2-4918-811e-46afa593e74d" />
<img width="956" height="1003" alt="Screenshot 2026-08-09 022809" src="https://github.com/user-attachments/assets/ec940e2b-b6d5-4123-ae58-d89e25a1e2a5" />
<img width="952" height="1011" alt="Screenshot 2026-08-09 023753" src="https://github.com/user-attachments/assets/0003029c-a0cb-4187-b6a6-e64de679b1d8" />


## 📈 Levels of Concepts Understood

The learning progressed through multiple levels:

--
Level 1 – Verilog Fundamentals
Modules
Inputs and outputs
Continuous assignments
always blocks
Registers and wires

--
Level 2 – RTL Simulation
Testbench creation
Stimulus generation
Simulation
VCD generation
Waveform analysis

--
Level 3 – RTL Verification
Checking expected outputs
Understanding signal transitions
Debugging through GTKWave
Identifying incorrect behavior

--
Level 4 – Logic Synthesis
RTL-to-gate conversion
Technology mapping
Standard cells
Netlist generation
Logic optimization

--
Level 5 – Timing Understanding
Propagation delay
Clock-to-Q delay
Setup time
Hold time
Critical paths
Maximum operating frequency

--
Level 6 – Standard-Cell Understanding
.lib files
Cell variants
Fast/medium/slow cells
Drive strength
Area and power trade-offs

--
Level 7 – Design Optimization
Timing optimization
Area optimization
Power considerations
Hierarchy
Flattening
Arithmetic optimization
Glitch awareness

---
## 🧠 Key Learning Outcomes

Through these classes, I developed an understanding of how a digital design moves from an abstract RTL description toward an implementation-oriented representation.

The major understanding gained was:
```
Specification
      ↓
RTL Design
      ↓
Testbench
      ↓
RTL Simulation
      ↓
Waveform Verification
      ↓
Logic Synthesis
      ↓
Technology Mapping
      ↓
Standard Cells
      ↓
Gate-Level Netlist
      ↓
Timing / Area / Power Analysis
```
I also learned that functional correctness alone is not sufficient for a real digital design.
A design must satisfy:
```
Functionality
     +
Timing
     +
Area
     +
Power
     +
Technology Constraints
```
---
## 📚 Gaining from the Classes

The classes provided a gradual understanding of the digital design flow.

Initially, the focus was on writing simple Verilog modules and understanding how simulation works. Later, the concepts moved toward testbench development, waveform analysis and debugging.

The next level involved understanding synthesis and how RTL is converted into gates. This introduced standard-cell libraries, Liberty files, technology mapping and netlists.

The timing concepts helped connect the RTL design with actual hardware behavior. Concepts such as setup time, hold time, clock-to-Q delay and combinational delay showed why a logically correct circuit may still fail to operate at the required frequency.

The study of fast, medium and slow cells also demonstrated the trade-off between performance, area and power.

Finally, hierarchy, flattening, optimization, reset strategies and arithmetic optimization provided a broader understanding of how synthesis tools transform RTL into an efficient hardware implementation.

---
# 📝 Summary

This learning journey provided a foundation in the RTL-to-GDSII digital design flow, beginning with Verilog RTL design and simulation and progressing toward logic synthesis and standard-cell concepts.

The most important understanding gained is that a digital circuit passes through several abstraction levels:
```
Verilog RTL
     ↓
Simulation
     ↓
Verified RTL
     ↓
Synthesis
     ↓
Gate-Level Netlist
     ↓
Standard-Cell Implementation
     ↓
Timing / Power / Area Optimization
```

The combination of Verilog, Icarus Verilog, GTKWave and Yosys provides a practical environment for understanding how digital hardware is designed, verified and synthesized.

This repository documents my progression from basic RTL concepts to a better understanding of VLSI design, synthesis, timing and standard-cell implementation.



