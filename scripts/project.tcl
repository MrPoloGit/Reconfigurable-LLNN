set top [lindex $argv 0]
set part [lindex $argv 1]
set build_dir [lindex $argv 2]

set constraints [lindex $argv end-1]
set board_repo [lindex $argv end]

set sv_files [lrange $argv 3 end-2]

set_param board.repoPaths $board_repo

create_project $top $build_dir -part $part -force

foreach f $sv_files {
    set f [string map {\\ /} $f]
    puts "Adding source: $f"
    add_files $f
}

set constraints [string map {\\ /} $constraints]
add_files -fileset constrs_1 $constraints

set_property top $top [current_fileset]

update_compile_order -fileset sources_1

close_project
exit