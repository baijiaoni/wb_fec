onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_linear_block/clk_i
add wave -noupdate /tb_linear_block/reset_i
add wave -noupdate /tb_linear_block/load_i
add wave -noupdate /tb_linear_block/dec_stat
add wave -noupdate /tb_linear_block/testing/lc_dec_stat
add wave -noupdate -radix hexadecimal /tb_linear_block/data_i
add wave -noupdate -radix hexadecimal /tb_linear_block/testing/s_data
add wave -noupdate -radix hexadecimal /tb_linear_block/testing/s_deco_shovel
add wave -noupdate /tb_linear_block/testing/fsm_16to24
add wave -noupdate -expand /tb_linear_block/testing/s_done_dec
add wave -noupdate /tb_linear_block/testing/s_err_dec
add wave -noupdate -expand /tb_linear_block/testing/s_load
add wave -noupdate /tb_linear_block/testing/s_load_data
add wave -noupdate -radix hexadecimal /tb_linear_block/testing/s_buffer
add wave -noupdate -radix hexadecimal /tb_linear_block/testing/s_deco
add wave -noupdate -radix hexadecimal -childformat {{/tb_linear_block/testing/s_deco_block(1) -radix hexadecimal} {/tb_linear_block/testing/s_deco_block(0) -radix hexadecimal}} -expand -subitemconfig {/tb_linear_block/testing/s_deco_block(1) {-radix hexadecimal} /tb_linear_block/testing/s_deco_block(0) {-radix hexadecimal}} /tb_linear_block/testing/s_deco_block
add wave -noupdate -expand /tb_linear_block/testing/buf_idx
add wave -noupdate /tb_linear_block/testing/s_slot_free
add wave -noupdate /tb_linear_block/testing/s_slot_pre
add wave -noupdate /tb_linear_block/testing/s_deco_slot
add wave -noupdate /tb_linear_block/testing/s_cntr_deco_slot
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {34612 ps} 0}
configure wave -namecolwidth 152
configure wave -valuecolwidth 137
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 16
configure wave -gridperiod 16
configure wave -griddelta 50
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {104960 ps}
