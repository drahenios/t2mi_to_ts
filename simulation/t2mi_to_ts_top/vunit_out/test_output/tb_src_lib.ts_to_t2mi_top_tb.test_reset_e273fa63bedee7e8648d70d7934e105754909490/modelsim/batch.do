onerror {quit -code 1}
source "/home/diefre/TFM/projects/DVB-T/scripts/t2mi_analyzer/test_bench/simulacion/ts_to_t2mi_top/vunit_out/test_output/tb_src_lib.ts_to_t2mi_top_tb.test_reset_e273fa63bedee7e8648d70d7934e105754909490/modelsim/common.do"
set failed [vunit_load]
if {$failed} {quit -code 1}
set failed [vunit_run]
if {$failed} {quit -code 1}
quit -code 0
