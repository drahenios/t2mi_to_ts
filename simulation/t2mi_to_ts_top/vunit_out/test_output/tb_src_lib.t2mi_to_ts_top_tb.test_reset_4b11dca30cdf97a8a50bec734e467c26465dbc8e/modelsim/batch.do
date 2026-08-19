onerror {quit -code 1}
source "/home/diefre/TFM/projects/t2mi_to_ts/simulation/t2mi_to_ts_top/vunit_out/test_output/tb_src_lib.t2mi_to_ts_top_tb.test_reset_4b11dca30cdf97a8a50bec734e467c26465dbc8e/modelsim/common.do"
set failed [vunit_load]
if {$failed} {quit -code 1}
set failed [vunit_run]
if {$failed} {quit -code 1}
quit -code 0
