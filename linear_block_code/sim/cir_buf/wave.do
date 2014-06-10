onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_circular_buff/clk
add wave -noupdate /tb_circular_buff/rstn
add wave -noupdate /tb_circular_buff/full
add wave -noupdate /tb_circular_buff/empty
add wave -noupdate /tb_circular_buff/data_o
add wave -noupdate -expand /tb_circular_buff/push
add wave -noupdate /tb_circular_buff/pop
add wave -noupdate /tb_circular_buff/buff/read_write/v_push
add wave -noupdate /tb_circular_buff/buff/s_buffer
add wave -noupdate /tb_circular_buff/buff/read_write/v_new
add wave -noupdate /tb_circular_buff/buff/s_write
add wave -noupdate /tb_circular_buff/buff/read_write/v_write
add wave -noupdate /tb_circular_buff/buff/read_write/v_read
add wave -noupdate /tb_circular_buff/buff/read_write/v_buf_idx
add wave -noupdate /tb_circular_buff/buff/read_write/v_zero_idx
add wave -noupdate /tb_circular_buff/buff/read_write/v_low_idx
add wave -noupdate /tb_circular_buff/buff/read_write/v_new_idx
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1067537 ps} 0}
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 8
configure wave -gridperiod 8
configure wave -griddelta 40
configure wave -timeline 1
configure wave -timelineunits ns
update
WaveRestoreZoom {448065 ps} {515366 ps}
