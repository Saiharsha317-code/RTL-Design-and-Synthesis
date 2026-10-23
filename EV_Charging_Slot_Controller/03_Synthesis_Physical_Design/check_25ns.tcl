read_liberty $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_n40C_1v28.lib
read_verilog openlane/runs/ev_run_v1/results/synthesis/ev_charging_controller.synthesis_preroute.v
link_design ev_charging_controller
create_clock -name clk -period 25 [get_ports clk]
read_spef results/ev_charging_controller.spef
report_worst_slack -max
exit
