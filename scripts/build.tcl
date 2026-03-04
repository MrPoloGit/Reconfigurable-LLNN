set top [lindex $argv 0]
set build_dir [lindex $argv 1]

open_project $build_dir/$top.xpr

launch_runs synth_1
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

exit