# 02 — Verification and Waveform Analysis

This folder contains the Verilog testbench used to exercise the EV charging controller. Verification checks that the design's outputs agree with expected behavior for reset, slot occupancy changes, reservation requests, cancellation requests, and availability reporting.

## File inventory

- `tb_ev_charging_controller.v` — simulation testbench. It instantiates `ev_charging_controller`, drives the inputs, maintains a reference model, compares expected and actual outputs, and writes a VCD waveform for GTKWave inspection.

## RTL simulation: compile and run

Run these commands from the repository root:

```bash
mkdir -p build
iverilog -g2012 -o build/ev_rtl_sim \
  01_RTL_Design/ev_charging_controller.v \
  02_Verification/tb_ev_charging_controller.v
vvp build/ev_rtl_sim
```

If you run from this folder instead, adjust the relative paths accordingly. The testbench's `$dumpfile` statement determines the VCD filename and the simulator's current working directory determines where it is written.

## What the testbench checks

The supplied testbench contains a reference-model approach and comparison helpers. Inspect the testbench itself for the complete set of scenarios and exact expected results. At a high level, review these categories:

| Test category | What to verify |
|---|---|
| Reset | State and status outputs return to their specified reset values |
| Occupancy update | Sensor inputs are reflected in the registered slot status at the expected time |
| Availability | `available_count`, `any_available`, and `station_full` are consistent with the state |
| Reservation accepted | A valid request selects an eligible slot and raises the expected grant indication |
| Reservation rejected | An unavailable or invalid request is rejected as defined by the RTL |
| Cancellation | A valid cancellation updates reservation state and indicates completion |
| Occupied-slot behavior | Cancellation/allocation does not violate the RTL's occupancy and reservation rules |
| Timing of outputs | Outputs update on the intended clock edge and do not change unexpectedly between edges |
| Randomized activity | Reference-model comparisons catch unexpected state combinations across varied inputs |

This table describes verification targets, not a claim that every possible combination has been exhaustively proven. Use the testbench output and error count as the evidence for the executed run.

## GTKWave: inspect the RTL waveform

```bash
gtkwave ev_charging_demo.vcd
```

Use the actual VCD filename printed or declared in the testbench. Add the clock and reset first, then the occupancy/reservation buses and request/response signals. Zoom into individual transactions to see the input request, state update, and response in sequence. For buses, use a radix that makes slot IDs and counts easy to read (binary or unsigned decimal).

Screenshots are in `../04_Evidence/01_RTL_and_Verification/`:

- `rtl_syntax_and_simulation.png`
- `rtl_waveform_demo.png`
- `testbench_waveforms.png`
- `controller_waveforms_extended.png`

## Gate-level simulation (GLS)

GLS is a separate check performed on the **technology-mapped netlist**, not on the behavioral RTL. The mapped netlist is located at `../03_Synthesis_Physical_Design/mapped_ev_charging_controller.v`.

A GLS run requires:

1. The mapped netlist.
2. Functional Verilog models for the Sky130 standard cells instantiated by that netlist.
3. A compatible testbench with matching top-level connections.
4. A simulator command that compiles the cell models and netlist in the required order.

Example command template from the repository root (replace the placeholder with the actual PDK model path):

```bash
iverilog -g2012 -s tb_ev_charging_controller -o build/ev_gls_sim \
  <sky130_functional_cell_models.v> \
  03_Synthesis_Physical_Design/mapped_ev_charging_controller.v \
  02_Verification/tb_ev_charging_controller.v
vvp build/ev_gls_sim
```

The placeholder is intentional; the correct model filenames depend on the Sky130 PDK installation. For timing-annotated GLS, a suitable SDF file and simulator annotation support are also required. A functional GLS run without SDF does not validate timing delays.

After simulation, open the actual GLS VCD in GTKWave and compare its outputs with the RTL waveform. Keep the RTL and GLS waveform files clearly named so the evidence cannot be confused. The current evidence directory contains waveform screenshots; if a dedicated GLS VCD/log is not present, add it after reproducing and validating that run.

## Verification-to-physical-design handoff

Only proceed with a known-good RTL revision. Record the source revision and simulation result before synthesis. After synthesis, GLS can help identify behavioral mismatches introduced by mapping or model/interface issues. Physical implementation and STA are separate checks and do not replace functional verification.
