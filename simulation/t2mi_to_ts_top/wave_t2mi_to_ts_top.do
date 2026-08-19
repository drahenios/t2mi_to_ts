onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group t2mi_to_ts_top -color Magenta /t2mi_to_ts_top_tb/dut/s_t2mi_run
add wave -noupdate -expand -group t2mi_to_ts_top -color Magenta /t2mi_to_ts_top_tb/dut/s_t2mi_send_error
add wave -noupdate -expand -group t2mi_to_ts_top -color Magenta /t2mi_to_ts_top_tb/dut/s_t2mi_receive_skip
add wave -noupdate -expand -group t2mi_to_ts_top -color Magenta /t2mi_to_ts_top_tb/dut/s_t2mi_receive_error
add wave -noupdate -expand -group ts_parser_inst -color Cyan /t2mi_to_ts_top_tb/dut/ts_parser_inst/s_state
add wave -noupdate -expand -group ts_parser_inst -color Cyan /t2mi_to_ts_top_tb/dut/ts_parser_inst/s_init
add wave -noupdate -expand -group ts_parser_inst -color Cyan -radix unsigned /t2mi_to_ts_top_tb/dut/ts_parser_inst/s_cnt_tsp_byte
add wave -noupdate -expand -group ts_parser_inst -color Cyan /t2mi_to_ts_top_tb/dut/ts_parser_inst/s_pusi
add wave -noupdate -expand -group ts_parser_inst -color Cyan /t2mi_to_ts_top_tb/dut/ts_parser_inst/s_pid
add wave -noupdate -expand -group ts_parser_inst -color Cyan /t2mi_to_ts_top_tb/dut/ts_parser_inst/s_cc_next
add wave -noupdate -expand -group ts_parser_inst -color Cyan -radix unsigned /t2mi_to_ts_top_tb/dut/ts_parser_inst/s_cnt_adaptation_length
add wave -noupdate -expand -group ts_parser_inst -color Cyan -radix unsigned /t2mi_to_ts_top_tb/dut/ts_parser_inst/s_cnt_pointer_field
add wave -noupdate -expand -group ts_parser_inst -color Cyan /t2mi_to_ts_top_tb/dut/ts_parser_inst/s_ts_clk_reg1
add wave -noupdate -expand -group ts_parser_inst -color Cyan /t2mi_to_ts_top_tb/dut/ts_parser_inst/s_ts_clk_reg2
add wave -noupdate -expand -group ts_parser_inst -color Cyan /t2mi_to_ts_top_tb/dut/ts_parser_inst/s_ts_sync_reg1
add wave -noupdate -expand -group ts_parser_inst -color Cyan /t2mi_to_ts_top_tb/dut/ts_parser_inst/s_ts_valid_reg1
add wave -noupdate -expand -group ts_parser_inst -color Cyan /t2mi_to_ts_top_tb/dut/ts_parser_inst/s_ts_data_reg1
add wave -noupdate -expand -group ts_parser_inst -color Cyan /t2mi_to_ts_top_tb/dut/ts_parser_inst/s_ts_target_pid_reg1
add wave -noupdate -expand -group t2mi_parser_inst -color {Medium Spring Green} /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/clk_i
add wave -noupdate -expand -group t2mi_parser_inst -color {Medium Spring Green} /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/rst_i
add wave -noupdate -expand -group t2mi_parser_inst -color {Medium Spring Green} /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/ts_valid_i
add wave -noupdate -expand -group t2mi_parser_inst -color {Medium Spring Green} /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/ts_clk_i
add wave -noupdate -expand -group t2mi_parser_inst -color {Medium Spring Green} /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/ts_data_i
add wave -noupdate -expand -group t2mi_parser_inst -color {Medium Spring Green} /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/tsp_run_i
add wave -noupdate -expand -group t2mi_parser_inst -color {Medium Spring Green} /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/tsp_receive_error_i
add wave -noupdate -expand -group t2mi_parser_inst -color {Green Yellow} /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/tsp_send_skip_o
add wave -noupdate -expand -group t2mi_parser_inst -color {Green Yellow} /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/tsp_send_error_o
add wave -noupdate -expand -group t2mi_parser_inst -color {Green Yellow} /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/tsup_clk_o
add wave -noupdate -expand -group t2mi_parser_inst -color {Green Yellow} /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/tsup_sync_o
add wave -noupdate -expand -group t2mi_parser_inst -color {Green Yellow} /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/tsup_valid_o
add wave -noupdate -expand -group t2mi_parser_inst -color {Green Yellow} /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/tsup_data_o
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_state
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_init
add wave -noupdate -expand -group t2mi_parser_inst -radix unsigned /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_hdr_index
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_byte
add wave -noupdate -expand -group t2mi_parser_inst -radix unsigned /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_cnt_payload_len_bytes
add wave -noupdate -expand -group t2mi_parser_inst -radix unsigned /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_cnt_dfl_bytes
add wave -noupdate -expand -group t2mi_parser_inst -radix unsigned /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_cnt_syncd_bytes
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_crc8
add wave -noupdate -expand -group t2mi_parser_inst -radix unsigned /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_cnt_bbpadding_bytes
add wave -noupdate -expand -group t2mi_parser_inst -radix unsigned /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_cnt_crc32_bytes
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_ts_clk_reg1
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_ts_clk_reg2
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_ts_valid_reg1
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_ts_data_reg1
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_tsp_run_reg1
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_ram_data
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_ram_q
add wave -noupdate -expand -group t2mi_parser_inst -radix unsigned /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_ram_wraddress
add wave -noupdate -expand -group t2mi_parser_inst -radix unsigned /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_ram_rdaddress
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_ram_wren
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_ram_rden
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_flag_ram_space_inc
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_flag_ram_space_dec
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_cnt_ram_space
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_cnt_wr_pck
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_state_ram_rd
add wave -noupdate -expand -group t2mi_parser_inst -radix unsigned /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_cnt_rd_pck
add wave -noupdate -expand -group t2mi_parser_inst -radix unsigned /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_cnt_null_pck_payload
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/ts_clk_rate_out_i
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/ts_clk_rate_out_reg_1
add wave -noupdate -expand -group t2mi_parser_inst /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/ts_clk_rate_out_reg_2
add wave -noupdate -expand -group t2mi_parser_inst -radix unsigned /t2mi_to_ts_top_tb/dut/t2mi_parser_inst/s_ram_wraddress_upl
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {409868 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 565
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {297828 ps} {959686 ps}
