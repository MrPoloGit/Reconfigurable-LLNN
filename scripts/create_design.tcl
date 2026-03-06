set top        [lindex $argv 0]
set part       [lindex $argv 1]
set build_dir  [lindex $argv 2]
set board_repo [lindex $argv 3]
set sources    [lrange $argv 4 end]

# Normalize incoming paths
set build_dir  [string map {\\ /} $build_dir]
set board_repo [string map {\\ /} $board_repo]

# Resolve repo root from this script location
set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file dirname $script_dir]

# Fixed repo-local constraints
set constraints [file normalize [file join $repo_root constraints "PYNQ-Z2 v1.0.xdc"]]
set constraints [string map {\\ /} $constraints]

# Project / BD naming
set proj_name "llnn_wrapper_bd"
set bd_name   "design_1"
set wrapper_module "llnn_wrapper_bd"

puts "Project top       : $top"
puts "Project part      : $part"
puts "Project build dir : $build_dir"
puts "Board repo        : $board_repo"
puts "Constraints       : $constraints"
puts "Project name      : $proj_name"
puts "BD name           : $bd_name"
puts "Wrapper module    : $wrapper_module"

if {![file exists $constraints]} {
    error "Constraint file not found: $constraints"
}

# Register local board repo
set_param board.repoPaths [list $board_repo]

# Create project
create_project $proj_name $build_dir -part $part -force
set_property board_part tul.com.tw:pynq-z2:part0:1.0 [current_project]

# Add HDL sources
set norm_sources {}
foreach f $sources {
    set nf [file normalize $f]
    set nf [string map {\\ /} $nf]
    if {![file exists $nf]} {
        error "Source file not found: $nf"
    }
    puts "Adding source: $nf"
    lappend norm_sources $nf
}

if {[llength $norm_sources] > 0} {
    add_files -fileset sources_1 $norm_sources
}

# Add constraints
add_files -fileset constrs_1 -norecurse [list $constraints]

# Set HDL top before BD creation so module reference is discoverable
set_property top $top [get_filesets sources_1]
update_compile_order -fileset sources_1

# ------------------------------------------------------------------------------
# Create Block Design
# ------------------------------------------------------------------------------
create_bd_design $bd_name
current_bd_design $bd_name

# Zynq Processing System
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7 processing_system7_0

# Apply board preset if available
catch {
    apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
        -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
        [get_bd_cells processing_system7_0]
}

# Force-enable GP0 master and FCLK reset/clock usage
# set_property -dict [list \
#     CONFIG.PCW_USE_M_AXI_GP0 {1} \
#     CONFIG.PCW_EN_CLK0_PORT {1} \
#     CONFIG.PCW_FCLK0_PERIPHERAL_CLKSRC {IO PLL} \
#     CONFIG.PCW_M_AXI_GP0_ENABLE_STATIC_REMAP {0} \
# ] [get_bd_cells processing_system7_0]

set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_EN_CLK0_PORT {1} \
    CONFIG.PCW_FCLK0_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {25.000000} \
    CONFIG.PCW_M_AXI_GP0_FREQMHZ {25} \
    CONFIG.PCW_M_AXI_GP0_ENABLE_STATIC_REMAP {0} \
] [get_bd_cells processing_system7_0]

# Module reference to your RTL wrapper
create_bd_cell -type module -reference $wrapper_module llnn_wrapper_bd_0

# Processor reset block
# create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_ps7_0_100M
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_ps7_0_25M

# ------------------------------------------------------------------------------
# Clock / reset wiring
# ------------------------------------------------------------------------------
# PS clock drives:
#   - proc_sys_reset slowest_sync_clk
#   - GP0 ACLK
#   - wrapper clk
connect_bd_net \
    [get_bd_pins processing_system7_0/FCLK_CLK0] \
    [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK]

connect_bd_net \
    [get_bd_pins processing_system7_0/FCLK_CLK0] \
    [get_bd_pins rst_ps7_0_25M/slowest_sync_clk]

# [get_bd_pins rst_ps7_0_100M/slowest_sync_clk]

connect_bd_net \
    [get_bd_pins processing_system7_0/FCLK_CLK0] \
    [get_bd_pins llnn_wrapper_bd_0/clk]

# PS reset into proc_sys_reset
connect_bd_net \
    [get_bd_pins processing_system7_0/FCLK_RESET0_N] \
    [get_bd_pins rst_ps7_0_25M/ext_reset_in]

# [get_bd_pins rst_ps7_0_100M/ext_reset_in]

# IMPORTANT: from your working log, rst_n must connect to peripheral_aresetn
connect_bd_net \
    [get_bd_pins rst_ps7_0_25M/peripheral_aresetn] \
    [get_bd_pins llnn_wrapper_bd_0/rst_n]

# [get_bd_pins rst_ps7_0_100M/peripheral_aresetn] \


# ------------------------------------------------------------------------------
# AXI connection
# ------------------------------------------------------------------------------
# Use BD automation to insert/interconnect SmartConnect automatically
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config { \
        Clk_master {/processing_system7_0/FCLK_CLK0} \
        Clk_slave {/processing_system7_0/FCLK_CLK0} \
        Clk_xbar {/processing_system7_0/FCLK_CLK0} \
        Master {/processing_system7_0/M_AXI_GP0} \
        Slave {/llnn_wrapper_bd_0/S_AXI} \
        ddr_seg {Auto} \
        intc_ip {New AXI Interconnect} \
        master_apm {0} \
    } \
    [get_bd_intf_pins llnn_wrapper_bd_0/S_AXI]

# Optional: lock GP0 clock frequency to 100 MHz to match common PYNQ flow
# catch {
#     set_property CONFIG.PCW_M_AXI_GP0_FREQMHZ {100} [get_bd_cells processing_system7_0]
# }
puts "FCLK_CLK0 target frequency set to 25 MHz"
puts "PS7 FPGA0 freq    : [get_property CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ [get_bd_cells processing_system7_0]]"
puts "M_AXI_GP0 freq    : [get_property CONFIG.PCW_M_AXI_GP0_FREQMHZ [get_bd_cells processing_system7_0]]"

# Auto-assign address map
assign_bd_address

# Save / validate BD
regenerate_bd_layout
validate_bd_design
save_bd_design

# ------------------------------------------------------------------------------
# Generate wrapper and build bitstream
# ------------------------------------------------------------------------------
set bd_file [get_files [file normalize [file join $build_dir "${proj_name}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd"]]]
if {[llength $bd_file] == 0} {
    # fallback if direct path query misses it
    set bd_file [get_files ${bd_name}.bd]
}
if {[llength $bd_file] == 0} {
    error "Could not find BD file for wrapper generation"
}

make_wrapper -files $bd_file -top

set wrapper_file [file normalize [file join $build_dir "${proj_name}.gen/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v"]]
set wrapper_file [string map {\\ /} $wrapper_file]

if {![file exists $wrapper_file]} {
    error "Wrapper file not found after make_wrapper: $wrapper_file"
}

add_files -norecurse $wrapper_file
set_property top ${bd_name}_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

# Clean rerun if needed
catch {reset_run synth_1}
catch {reset_run impl_1}

launch_runs impl_1 -to_step write_bitstream -jobs 16
wait_on_run impl_1

# ------------------------------------------------------------------------------
# Copy outputs to build/<model>
# ------------------------------------------------------------------------------
set impl_dir [file normalize [file join $build_dir "${proj_name}.runs/impl_1"]]
set impl_dir [string map {\\ /} $impl_dir]

set bit_src [file normalize [file join $impl_dir "${bd_name}_wrapper.bit"]]
set bit_src [string map {\\ /} $bit_src]

# Common HWH locations depending on Vivado flow/version
set hwh_candidates [list \
    [file normalize [file join $build_dir "${proj_name}.gen/sources_1/bd/${bd_name}/hw_handoff/${bd_name}.hwh"]] \
    [file normalize [file join $build_dir "${proj_name}.gen/sources_1/bd/${bd_name}/hw_handoff/${bd_name}_wrapper.hwh"]] \
    [file normalize [file join $impl_dir "${bd_name}_wrapper.hwh"]] \
    [file normalize [file join $impl_dir "${bd_name}.hwh"]] \
]

set hwh_src ""
foreach cand $hwh_candidates {
    set cand [string map {\\ /} $cand]
    if {[file exists $cand]} {
        set hwh_src $cand
        break
    }
}

if {![file exists $bit_src]} {
    error "Bitstream file not found: $bit_src"
}

if {$hwh_src eq ""} {
    error "HWH file not found in expected locations."
}

# Output names in build/<model>
set bit_dst [file normalize [file join $build_dir "${bd_name}_wrapper.bit"]]
set hwh_dst [file normalize [file join $build_dir "${bd_name}_wrapper.hwh"]]

set bit_dst [string map {\\ /} $bit_dst]
set hwh_dst [string map {\\ /} $hwh_dst]

file copy -force $bit_src $bit_dst
file copy -force $hwh_src $hwh_dst

# Final messages
puts "BD + wrapper flow completed."
puts "Project dir       : [get_property directory [current_project]]"
puts "Wrapper file      : $wrapper_file"
puts "Bitstream source  : $bit_src"
puts "HWH source        : $hwh_src"
puts "Bitstream output  : $bit_dst"
puts "HWH output        : $hwh_dst"

close_project
exit