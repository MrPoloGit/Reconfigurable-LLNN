# =============================================================================
# build_overlay.tcl — Vivado Tcl script for the LLNN Reconfigurable Overlay
#
# Targets: PYNQ-Z2 (xc7z020clg400-1)
# Usage:   vivado -mode batch -source build_overlay.tcl -tclargs <overlay_dir>
#
# Example: vivado -mode batch -source hdl/build_overlay.tcl -tclargs data/overlay/simple_lutnn
# =============================================================================

# --- Parse arguments ---------------------------------------------------------
if {$argc < 1} {
    puts "ERROR: Usage: vivado -mode batch -source build_overlay.tcl -tclargs <overlay_dir>"
    exit 1
}
set overlay_dir [lindex $argv 0]
set project_name "llnn_overlay"
set project_dir "${overlay_dir}/vivado_project"
set part "xc7z020clg400-1"

puts "============================================="
puts " LLNN Overlay Build"
puts " Source dir : $overlay_dir"
puts " Project dir: $project_dir"
puts " Part       : $part"
puts "============================================="

# --- Create project -----------------------------------------------------------
create_project $project_name $project_dir -part $part -force

# --- Add source files ---------------------------------------------------------
add_files [glob ${overlay_dir}/*.sv]
set_property file_type SystemVerilog [get_files *.sv]

# Mark Globals.sv as a header
set_property IS_GLOBAL_INCLUDE true [get_files Globals.sv]

update_compile_order -fileset sources_1

# --- Create block design with Zynq PS ----------------------------------------
create_bd_design "llnn_bd"

# Add Zynq Processing System
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7

# Apply PYNQ-Z2 board preset (if board files are installed)
# If not available, we configure manually below
if {[catch {
    set_property -dict [list \
        CONFIG.preset {PYNQ-Z2} \
    ] [get_bd_cells ps7]
}]} {
    puts "WARN: PYNQ-Z2 preset not found, configuring PS manually..."
    set_property -dict [list \
        CONFIG.PCW_USE_M_AXI_GP0 {1} \
        CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
        CONFIG.PCW_USE_FABRIC_INTERRUPT {0} \
    ] [get_bd_cells ps7]
}

# Enable M_AXI_GP0
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 {1}] [get_bd_cells ps7]

# Add our overlay top module as a Module Reference
create_bd_cell -type module -reference top llnn_top

# Add AXI Interconnect
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_intercon
set_property -dict [list CONFIG.NUM_MI {1} CONFIG.NUM_SI {1}] [get_bd_cells axi_intercon]

# --- Connections --------------------------------------------------------------
# Clock and reset
connect_bd_net [get_bd_pins ps7/FCLK_CLK0]      [get_bd_pins llnn_top/clk]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0]      [get_bd_pins axi_intercon/ACLK]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0]      [get_bd_pins axi_intercon/S00_ACLK]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0]      [get_bd_pins axi_intercon/M00_ACLK]

connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N]  [get_bd_pins llnn_top/rst_n]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N]  [get_bd_pins axi_intercon/ARESETN]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N]  [get_bd_pins axi_intercon/S00_ARESETN]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N]  [get_bd_pins axi_intercon/M00_ARESETN]

# PS GP0 → Interconnect → overlay
connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0]           [get_bd_intf_pins axi_intercon/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_intercon/M00_AXI]    [get_bd_intf_pins llnn_top/S_AXI]

# Assign address space: 16KB at 0x43C0_0000
assign_bd_address
set_property range 16K [get_bd_addr_segs {ps7/Data/SEG_llnn_top_*}]

# --- Validate & generate wrapper ---------------------------------------------
validate_bd_design
save_bd_design

make_wrapper -files [get_files ${project_dir}/${project_name}.srcs/sources_1/bd/llnn_bd/llnn_bd.bd] -top
add_files -norecurse [glob ${project_dir}/${project_name}.gen/sources_1/bd/llnn_bd/hdl/llnn_bd_wrapper.v]
update_compile_order -fileset sources_1
set_property top llnn_bd_wrapper [current_fileset]

# --- Synthesis ----------------------------------------------------------------
puts ">>> Running Synthesis..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

# --- Implementation -----------------------------------------------------------
puts ">>> Running Implementation..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
    puts "ERROR: Implementation failed!"
    exit 1
}

# --- Export -------------------------------------------------------------------
set bit_file [glob ${project_dir}/${project_name}.runs/impl_1/*.bit]
set hwh_file [glob ${project_dir}/${project_name}.gen/sources_1/bd/llnn_bd/hw_handoff/*.hwh]

file copy -force $bit_file ${overlay_dir}/llnn_overlay.bit
file copy -force $hwh_file ${overlay_dir}/llnn_overlay.hwh

puts "============================================="
puts " ✅ BUILD COMPLETE"
puts " Bitstream: ${overlay_dir}/llnn_overlay.bit"
puts " HW Handoff: ${overlay_dir}/llnn_overlay.hwh"
puts "============================================="

close_project
exit 0
