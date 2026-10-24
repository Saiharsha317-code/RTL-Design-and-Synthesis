# EV Charging Slot Availability and Smart Allocation Controller

## Project Overview

This project implements a digital controller to monitor the availability of four EV charging slots and automatically allocate an available slot when a reservation request is received. The design is developed using Verilog HDL and taken through RTL simulation, synthesis, physical design, and timing analysis.

The main aim of this project is to understand the complete VLSI design flow, from writing RTL code to generating the physical layout.

## Project Details

- **Project Title:** EV Charging Slot Availability and Smart Allocation Controller
- **Developed by:** V. Sai Harsha
- **Department:** III-ECE
- **Technology:** SKY130A 130nm
- **HDL:** Verilog
- **Simulation:** Icarus Verilog and GTKWave
- **Synthesis:** Yosys
- **Physical Design:** OpenLane
- **Timing Analysis:** OpenSTA

## Key Features

- Monitors four EV charging slots.
- Displays slot availability and reservation status.
- Automatically assigns an available slot using fixed-priority allocation.
- Supports reservation cancellation.
- Generates grant and reject signals for reservation requests.
- Includes RTL simulation and waveform analysis.
- Supports synthesis and physical design analysis.

## Design Flow

The project follows these major stages:

1. **RTL Design:** Implemented the controller using Verilog HDL.
2. **RTL Simulation:** Verified the design using a testbench.
3. **Waveform Analysis:** Inspected signal transitions using GTKWave.
4. **Logic Synthesis:** Converted RTL into a gate-level netlist using Yosys.
5. **Gate-Level Verification:** Examined the synthesized design and its simulation evidence.
6. **Floorplanning:** Defined the initial layout area and design constraints.
7. **Placement:** Arranged standard cells in the layout.
8. **Clock Tree Synthesis (CTS):** Built the clock distribution network.
9. **Routing:** Connected the design components through metal interconnects.
10. **Timing Analysis:** Examined setup and hold timing across available timing corners.
11. **Physical Verification:** Reviewed the available DRC, LVS, and related reports.

## Project Presentation

The PowerPoint presentation explains the project objective, architecture, RTL design, simulation waveforms, synthesis, physical design flow, timing analysis, and results.

**PPT:** https://docs.google.com/presentation/d/1_bbprHfmGC0i20lMpqPLcB98JCBr6thE/edit?usp=sharing&ouid=105165548137670739998&rtpof=true&sd=true

## Project Demonstration Video

The demonstration video presents the implementation and the major stages completed during the project, including RTL design, GTKWave waveform analysis, synthesis, physical design, and timing reports.

**Video:** https://drive.google.com/file/d/1bsalTYVsdzENTS-Wz3ocIKeUMv8Tpr5d/view?usp=sharing

## Tools and Technologies

- Verilog HDL
- Icarus Verilog
- GTKWave
- Yosys
- OpenLane
- OpenSTA
- SKY130A standard-cell library
- Ubuntu and Docker

## Learning Outcomes

Through this project, I gained practical experience in RTL coding, simulation, waveform debugging, logic synthesis, physical design stages, and static timing analysis. I also learned how to organize design files and document implementation results in a GitHub repository.

## Conclusion

The EV Charging Slot Availability and Smart Allocation Controller demonstrates how a small digital control circuit can be developed through the VLSI implementation flow. This project helped me understand the connection between RTL design, verification, synthesis, physical implementation, and timing analysis.

---

**Author:** V. Sai Harsha  
**Department:** III-ECE
