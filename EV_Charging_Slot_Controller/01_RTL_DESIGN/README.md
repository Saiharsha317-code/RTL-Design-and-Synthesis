# 01 — RTL Design

This folder contains the synthesizable Verilog RTL for the **EV Charging Slot Availability and Smart Allocation Controller**. The design controls four logical charging slots and provides availability, reservation, cancellation, and request-status signals.

## Purpose of the RTL stage

RTL describes what the hardware must do on clock edges, without specifying the final placement of standard cells. This is the functional source used by the simulator and the synthesis tool. The source file in this folder should be treated as the design's behavioral and structural reference; do not edit the mapped netlist to make a functional change. Make changes in RTL, re-run verification, and then re-run synthesis and physical design.

## File inventory

- `ev_charging_controller.v` — controller module and synthesizable logic.

## Main interface

| Signal | Direction | Width | Description |
|---|---|---:|---|
| `clk` | Input | 1 | Clock |
| `rst` | Input | 1 | Reset |
| `slot_sensor` | Input | 4 | Occupancy observations for four slots |
| `reserve_req` | Input | 1 | Reservation request |
| `cancel_req` | Input | 1 | Cancellation request |
| `cancel_slot_id` | Input | 2 | Slot ID requested for cancellation |
| `slot_status` | Output | 4 | Registered occupancy status |
| `reserved_status` | Output | 4 | Per-slot reservation status |
| `sensor_valid` | Output | 1 | Sensor/status validity indicator |
| `available_count` | Output | 3 | Number of available slots, from 0 to 4 |
| `any_available` | Output | 1 | At least one slot is available |
| `station_full` | Output | 1 | No slot is available |
| `assigned_slot_id` | Output | 2 | ID of selected slot |
| `grant` | Output | 1 | Request accepted |
| `reject` | Output | 1 | Request rejected |
| `cancel_done` | Output | 1 | Cancellation acknowledgement |

Check the module declaration and comments in the Verilog source for exact signal semantics and event priority. The interface table is a quick reference, not a substitute for reading the RTL.

## Functional design goals

1. Track the occupancy of four charging slots.
2. Maintain reservation state independently from occupancy.
3. Calculate availability and station-full status.
4. Allocate an eligible slot when a reservation is accepted.
5. Reject invalid or unavailable requests according to the implemented rules.
6. Process valid cancellation requests and indicate completion.
7. Use synthesizable constructs supported by the target synthesis flow.

## RTL verification workflow

From the repository root:

```bash
mkdir -p build
iverilog -g2012 -o build/ev_rtl_sim \
  01_RTL_Design/ev_charging_controller.v \
  02_Verification/tb_ev_charging_controller.v
vvp build/ev_rtl_sim
```

Check the simulation transcript for the testbench's final status and error count. A simulation that runs to completion is not enough by itself; verify that the self-checking testbench reports no mismatches.

## GTKWave inspection

The testbench writes a VCD waveform using its `$dumpfile` statement. Open the actual generated filename:

```bash
gtkwave ev_charging_demo.vcd
```

Useful signals to inspect together include `clk`, `rst`, `slot_sensor`, `slot_status`, `reserved_status`, `available_count`, `reserve_req`, `grant`, `assigned_slot_id`, `cancel_req`, `cancel_slot_id`, `cancel_done`, `reject`, and `station_full`. Compare the waveform against the testbench's expected transactions.

Evidence is stored in `../04_Evidence/01_RTL_and_Verification/`.

## RTL-to-GDSII relationship

The RTL is the starting point for the full flow:

**RTL → RTL simulation/GTKWave → Yosys synthesis → technology-mapped netlist → gate-level simulation → floorplan/power planning → placement → CTS → routing → parasitic extraction → STA → physical checks → GDSII.**

If the RTL changes, the old mapped netlist, layout, GDSII, and timing reports may no longer correspond to the current source. Re-run downstream stages after a functional change.
