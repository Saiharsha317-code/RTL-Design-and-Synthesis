set pdk_root $::env(PDK_ROOT)
set lib_file "$pdk_root/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
set netlist  "openlane/runs/ev_run_v1/results/synthesis/ev_charging_controller.synthesis_preroute.v"
set spef     "results/ev_charging_controller.spef"

puts "=== LOADING DESIGN ==="
read_liberty $lib_file
read_verilog $netlist
link_design ev_charging_controller

puts "=== LOADING CONSTRAINTS ==="
create_clock -name clk -period 20 [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]

puts "=== LOADING PARASITICS (SPEF) ==="
read_spef $spef

puts "\n=================================================="
puts "                 SETUP ANALYSIS (MAX)             "
puts "=================================================="
report_checks -path_delay max -format summary -digits 4
puts "\n--- Setup WNS ---"
report_worst_slack -max
puts "--- Setup TNS ---"
report_tns

puts "\n=================================================="
puts "                 HOLD ANALYSIS (MIN)              "
puts "=================================================="
report_checks -path_delay min -format summary -digits 4
puts "\n--- Hold WNS ---"
report_worst_slack -min
puts "--- Hold TNS ---"
report_tns -min

exit
