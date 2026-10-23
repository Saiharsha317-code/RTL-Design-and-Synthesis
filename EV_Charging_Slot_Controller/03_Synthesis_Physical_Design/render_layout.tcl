# Load a DEF and render to PNM
set def_file  [lindex $argv 0]
set top_cell  [lindex $argv 1]

puts "Loading: $def_file"
load $def_file $top_cell

puts "Fitting view..."
view

puts "Rendering to PNM..."
plot pnm

puts "Done"
quit -noprompt
