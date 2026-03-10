# =============================================================================
# build_overlay.tcl — Vivado Tcl script for LLNN overlay build
#
# Usage:
#   vivado -mode batch -source scripts/build_overlay.tcl \
#     -tclargs <overlay_dir> <project_dir> <bd_name> <jobs> <model_dir>
#
# Example:
#   vivado -mode batch -source scripts/build_overlay.tcl \
#     -tclargs hdl/overlay build/model1/overlay llnn_bd 4 data/sv/model1
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

set part       "xc7z020clg400-1"
set board_part "tul.com.tw:pynq-z2:part0:1.0"
set axi_range  "64K"

set module_ref "llnn_wrapper_bd"
set instance   "llnn_wrapper_bd_0"

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------

if {$argc < 1} {
    puts "Usage:"
    puts "  vivado -mode batch -source scripts/build_overlay.tcl \\"
    puts "    -tclargs <overlay_dir> [project_dir] [bd_name] [jobs] [model_dir]"
    exit 1
}

set overlay_dir [file normalize [lindex $argv 0]]
set project_dir [expr {$argc > 1 ? [file normalize [lindex $argv 1]] : [file normalize "./build/overlay"]}]
set bd_name     [expr {$argc > 2 ? [lindex $argv 2] : "llnn_bd"}]
set jobs        [expr {$argc > 3 ? [lindex $argv 3] : 4}]
set model_dir   [expr {$argc > 4 ? [file normalize [lindex $argv 4]] : ""}]

set project_name "llnn_wrapper_bd"

puts ""
puts "============================================="
puts "LLNN Overlay Build"
puts "Overlay dir : $overlay_dir"
puts "Model dir   : $model_dir"
puts "Project dir : $project_dir"
puts "BD name     : $bd_name"
puts "Part        : $part"
puts "Jobs        : $jobs"
puts "============================================="

# -----------------------------------------------------------------------------
# Helper procs
# -----------------------------------------------------------------------------

proc append_if_exists {var_name path} {
    upvar 1 $var_name dst
    if {[file exists $path]} {
        lappend dst $path
    } else {
        puts "WARNING: expected source not found: $path"
    }
}

proc connect_bd_pin_if_needed {src_pin_name dst_pin_name} {
    set src_pin [get_bd_pins -quiet $src_pin_name]
    set dst_pin [get_bd_pins -quiet $dst_pin_name]

    if {[llength $src_pin] == 0 || [llength $dst_pin] == 0} {
        return
    }

    # If the source pin is already on a net, avoid re-connecting.
    set src_nets [get_bd_nets -quiet -of_objects $src_pin]
    if {[llength $src_nets] > 0} {
        puts "Skipping reset connect: $src_pin_name already connected."
        return
    }

    connect_bd_net $src_pin $dst_pin
}

# -----------------------------------------------------------------------------
# Register board repository
# -----------------------------------------------------------------------------

set board_repo [file normalize "boards"]
if {[file exists $board_repo]} {
    puts "Registering board repo: $board_repo"
    set_param board.repoPaths [list $board_repo]
}

# -----------------------------------------------------------------------------
# Create project
# -----------------------------------------------------------------------------

create_project $project_name $project_dir -part $part -force

if {[catch {set_property board_part $board_part [current_project]} err]} {
    puts "WARNING: Could not set board_part to $board_part"
    puts "WARNING: $err"
    puts "WARNING: Continuing with part-only flow."
}

# -----------------------------------------------------------------------------
# Collect sources
# -----------------------------------------------------------------------------

set model_dir_norm [string map {\\ /} $model_dir]
set is_reconfig 0
if {$model_dir_norm ne "" && [string match "*/data/overlay/*" $model_dir_norm]} {
    set is_reconfig 1
}

set overlay_v {}
set overlay_sv {}

if {$is_reconfig} {
    puts "Build flow  : reconfigurable"
    append_if_exists overlay_v  [file join $overlay_dir "llnn_wrapper_bd.v"]
    append_if_exists overlay_sv [file join $overlay_dir "llnn_wrapper.sv"]
    append_if_exists overlay_sv [file join $overlay_dir "axi_lut_ctrl.sv"]
    append_if_exists overlay_sv [file join $overlay_dir "SoftLUT5.sv"]
    # Optional primitive variant (not instantiated by default)
    append_if_exists overlay_sv [file join $overlay_dir "SoftLUT5_primitive.sv"]
} else {
    puts "Build flow  : static/hard"
    append_if_exists overlay_v  [file join $overlay_dir "llnn_wrapper_hard_bd.v"]
    append_if_exists overlay_sv [file join $overlay_dir "llnn_wrapper_hard.sv"]
    append_if_exists overlay_sv [file join $overlay_dir "axi_lut_ctrl_hard.sv"]
}

set model_sv {}
if {$model_dir ne ""} {
    set model_sv [lsort [glob -nocomplain ${model_dir}/*.sv]]
}

set xdc_files [lsort [glob -nocomplain constraints/*.xdc]]

puts ""
puts "Overlay Verilog:"
foreach f $overlay_v { puts "  $f" }

puts ""
puts "Overlay SystemVerilog:"
foreach f $overlay_sv { puts "  $f" }

puts ""
puts "Model SystemVerilog:"
foreach f $model_sv { puts "  $f" }

puts ""
puts "Constraints:"
foreach f $xdc_files { puts "  $f" }

# -----------------------------------------------------------------------------
# Add sources to project
# -----------------------------------------------------------------------------

set all_sources {}
foreach f $overlay_v  { lappend all_sources $f }
foreach f $overlay_sv { lappend all_sources $f }
foreach f $model_sv   { lappend all_sources $f }

puts ""
puts "Adding sources to sources_1:"
foreach f $all_sources {
    puts "  $f"
}

add_files -fileset sources_1 -norecurse $all_sources

if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 -norecurse $xdc_files
}

foreach f [get_files *.sv] {
    set_property file_type SystemVerilog $f
}

if {$model_dir ne ""} {
    set_property include_dirs [list $model_dir] [get_filesets sources_1]
}

set globals_matches [get_files -quiet */Globals.sv]
if {[llength $globals_matches] == 0} {
    set globals_matches [get_files -quiet Globals.sv]
}
foreach g $globals_matches {
    set_property IS_GLOBAL_INCLUDE true $g
}

update_compile_order -fileset sources_1

# -----------------------------------------------------------------------------
# Create block design
# -----------------------------------------------------------------------------

create_bd_design $bd_name

if {[llength [get_bd_cells -quiet processing_system7_0]] == 0} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
}
if {[llength [get_bd_cells -quiet $instance]] == 0} {
    create_bd_cell -type module -reference $module_ref $instance
}

apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
    [get_bd_cells processing_system7_0]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
    Clk_master {Auto}
    Clk_slave  {Auto}
    Clk_xbar   {Auto}
    Master     {/processing_system7_0/M_AXI_GP0}
    Slave      {/${instance}/S_AXI}
    ddr_seg    {Auto}
    intc_ip    {New AXI SmartConnect}
    master_apm {0}
} [get_bd_intf_pins ${instance}/S_AXI]

connect_bd_pin_if_needed "${instance}/rst_n" "rst_ps7_0_100M/peripheral_aresetn"

validate_bd_design
save_bd_design

generate_target all [get_files ${bd_name}.bd]

startgroup
if {[llength [get_bd_cells -quiet processing_system7_0]] == 0} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
}
endgroup

if {[llength [get_bd_cells -quiet $instance]] == 0} {
    create_bd_cell -type module -reference $module_ref $instance
}

# -----------------------------------------------------------------------------
# Add model and overlay RTL to the module-reference synth run
# -----------------------------------------------------------------------------

generate_target all [get_files ${bd_name}.bd]

set mod_runs [get_runs -quiet *${instance}*_synth_1]
puts ""
puts "Module-reference synth runs:"
foreach r $mod_runs { puts "  $r" }

foreach r $mod_runs {
    set fs [get_property SRCSET $r]
    puts "Adding RTL to fileset $fs for run $r"

    foreach f $overlay_v  { add_files -fileset $fs -norecurse $f }
    foreach f $overlay_sv { add_files -fileset $fs -norecurse $f }
    foreach f $model_sv   { add_files -fileset $fs -norecurse $f }

    foreach f [get_files -of_objects [get_filesets $fs] *.sv] {
        set_property file_type SystemVerilog $f
    }

    if {$model_dir ne ""} {
        set_property include_dirs [list $model_dir] [get_filesets $fs]
    }
}

apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
    [get_bd_cells processing_system7_0]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {
        Clk_master {/processing_system7_0/FCLK_CLK0 (100 MHz)}
        Clk_slave  {/processing_system7_0/FCLK_CLK0 (100 MHz)}
        Clk_xbar   {/processing_system7_0/FCLK_CLK0 (100 MHz)}
        Master     {/processing_system7_0/M_AXI_GP0}
        Slave      {/${instance}/S_AXI}
        ddr_seg    {Auto}
        intc_ip    {New AXI SmartConnect}
        master_apm {0}
    } \
    [get_bd_intf_pins ${instance}/S_AXI]

# Connect active-low reset exactly like the working reference
connect_bd_pin_if_needed "${instance}/rst_n" "rst_ps7_0_100M/peripheral_aresetn"

# Set address range
set addr_segs [get_bd_addr_segs -quiet "processing_system7_0/Data/SEG_${instance}_*"]
if {[llength $addr_segs] > 0} {
    set_property range $axi_range $addr_segs
    puts "Address segment:"
    puts "  Offset = [get_property offset $addr_segs]"
    puts "  Range  = $axi_range"
}

validate_bd_design -force
save_bd_design

# -----------------------------------------------------------------------------
# Generate BD wrapper and make it top
# -----------------------------------------------------------------------------

set bd_file [get_files ${bd_name}.bd]
make_wrapper -files $bd_file -top

set wrapper_file [glob ${project_dir}/${project_name}.gen/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v]
add_files -norecurse $wrapper_file

update_compile_order -fileset sources_1
set_property top ${bd_name}_wrapper [current_fileset]

puts ""
puts "Vivado compile order before build:"
foreach f [get_files -of_objects [get_filesets sources_1]] {
    puts "  [file tail $f]"
}

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------

puts ""
puts ">>> Launching implementation to bitstream"
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation status: $impl_status"

if {$impl_status ne "write_bitstream Complete!"} {
    error "Implementation failed. Check impl_1/synth_1 run logs."
}

# -----------------------------------------------------------------------------
# Export artifacts
# -----------------------------------------------------------------------------

set bit_file [glob ${project_dir}/${project_name}.runs/impl_1/*.bit]
set hwh_file [glob ${project_dir}/${project_name}.gen/sources_1/bd/${bd_name}/hw_handoff/*.hwh]

set model_name [expr {$model_dir ne "" ? [file tail $model_dir] : "model"}]
set out_dir [file normalize [file join build $model_name]]

file mkdir $out_dir
file copy -force $bit_file ${out_dir}/llnn.bit
file copy -force $hwh_file ${out_dir}/llnn.hwh

puts ""
puts "============================================="
puts "BUILD COMPLETE"
puts "Bitstream : ${out_dir}/llnn.bit"
puts "HWH       : ${out_dir}/llnn.hwh"
puts "============================================="

close_project
exit 0
