# # from VIVADO
# create_project project_2 C:/Users/m2106/Documents/Projects/project_2 -part xc7z020clg400-1
# INFO: [IP_Flow 19-234] Refreshing IP repositories
# INFO: [IP_Flow 19-1704] No user IP repositories specified
# INFO: [IP_Flow 19-2313] Loaded Vivado IP repository 'C:/Xilinx/Vivado/2024.1/data/ip'.
# create_project: Time (s): cpu = 00:00:13 ; elapsed = 00:00:06 . Memory (MB): peak = 1299.027 ; gain = 23.867
# set_property board_part tul.com.tw:pynq-z2:part0:1.0 [current_project]
# add_files {C:/Users/m2106/Documents/Projects/LiveLLNN/hdl/overlay/llnn_wrapper.sv C:/Users/m2106/Documents/Projects/LiveLLNN/hdl/overlay/axi_lut_ctrl.sv C:/Users/m2106/Documents/Projects/LiveLLNN/hdl/overlay/axi_lut_ctrl_hard.sv C:/Users/m2106/Documents/Projects/LiveLLNN/hdl/tb_NET.vhd C:/Users/m2106/Documents/Projects/LiveLLNN/hdl/tb_NET.sv C:/Users/m2106/Documents/Projects/LiveLLNN/hdl/overlay/SoftLUT5.sv}
# update_compile_order -fileset sources_1
# update_compile_order -fileset sources_1
# add_files -fileset constrs_1 -norecurse C:/Users/m2106/Documents/Projects/LiveLLNN/constraints/PYNQ-Z2.xdc
# create_bd_design "design_1"
# Wrote  : <C:\Users\m2106\Documents\Projects\project_2\project_2.srcs\sources_1\bd\design_1\design_1.bd> 
# create_bd_design: Time (s): cpu = 00:00:12 ; elapsed = 00:00:08 . Memory (MB): peak = 1450.781 ; gain = 111.855
# update_compile_order -fileset sources_1

set top        [lindex $argv 0]
set part       [lindex $argv 1]
set build_dir  [lindex $argv 2]
set board_repo [lindex $argv 3]
set sv_files   [lrange $argv 4 end]

# Normalize incoming paths
set build_dir  [string map {\\ /} $build_dir]
set board_repo [string map {\\ /} $board_repo]

# Resolve repo root from this script location
set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file dirname $script_dir]

# Constraint file kept with fixed name in repo
set constraints [file normalize [file join $repo_root constraints "PYNQ-Z2 v1.0.xdc"]]
set constraints [string map {\\ /} $constraints]

puts "Project top       : $top"
puts "Project part      : $part"
puts "Project build dir : $build_dir"
puts "Board repo        : $board_repo"
puts "Constraints       : $constraints"

if {![file exists $constraints]} {
    error "Constraint file not found: $constraints"
}

# Register local board repo
set_param board.repoPaths [list $board_repo]

# Create project
create_project $top $build_dir -part $part -force

# Match GUI flow: explicitly set board part
# Adjust this if your board vendor string differs
set_property board_part tul.com.tw:pynq-z2:part0:1.0 [current_project]

# Build a proper Tcl list of source files
set norm_sv_files {}
foreach f $sv_files {
    set nf [file normalize $f]
    set nf [string map {\\ /} $nf]
    if {![file exists $nf]} {
        error "Source file not found: $nf"
    }
    puts "Adding source: $nf"
    lappend norm_sv_files $nf
}

# Add all sources at once, like GUI Tcl
if {[llength $norm_sv_files] > 0} {
    add_files $norm_sv_files
}

update_compile_order -fileset sources_1

# Add constraints like GUI Tcl
add_files -fileset constrs_1 -norecurse [list $constraints]

# Set top module
set_property top $top [current_fileset]

update_compile_order -fileset sources_1

close_project
exit