# ==========================================
# Vivado Non-Project Flow Build Script
# Args:
#   0 = TOP module name
#   1 = PART
#   2 = BUILD_DIR
#   3 = SV files list
# ==========================================

set TOP      [lindex $argv 0]
set PART     [lindex $argv 1]
set BUILD    [lindex $argv 2]
set SV_FILES [lindex $argv 3]

puts "Top: $TOP"
puts "Part: $PART"
puts "Build Dir: $BUILD"

file mkdir $BUILD
cd $BUILD

# Create project
create_project -force llnn_proj . -part $PART

# Add SV files
foreach file [split $SV_FILES " "] {
    puts "Adding $file"
    add_files $file
}

set_property top $TOP [current_fileset]

# Synthesis
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# Implementation
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# Copy outputs
file copy -force llnn_proj.runs/impl_1/$TOP.bit .
file copy -force llnn_proj.runs/impl_1/$TOP.hwh .

puts "Bitstream generated successfully!"
exit
