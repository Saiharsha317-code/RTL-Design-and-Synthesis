set corner_name $::env(CORNER_NAME)
set pdk_root $::env(PDK_ROOT)
set lib_file "$pdk_root/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__${corner_name}.lib"
set netlist  "openlane/runs/ev_run_v1/results/synthesis/ev_charging_controller.synthesis_preroute.v"
set spef     "results/ev_charging_controller.spef"

read_liberty $lib_file
read_verilog $netlist
link_design ev_charging_controller
create_clock -name clk -period 20 [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]
read_spef $spef

puts "--- SETUP ---"
report_worst_slack -max
puts "--- HOLD ---"
report_worst_slack -min
exit
