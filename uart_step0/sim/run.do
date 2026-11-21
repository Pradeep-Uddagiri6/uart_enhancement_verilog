# ModelSim: UART TX/RX path  -> from the sim directory:  do run.do
# batch:  vsim -c -do "do run.do; quit -f"
if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work
vlog -work work ../rtl/dut_uart_transmitter.v \
                ../tb/tb_uart_rx_model.v \
                ../tb/tb_uart_score_board.v \
                ../tb/tb_uart_stimulus_generator.v \
                ../tb/tb_top_uart.v
vsim -voptargs=+acc work.tb_top_uart
if {![batch_mode]} {
  add wave -divider clocking
  add wave /tb_top_uart/clk /tb_top_uart/rst
  add wave -divider stimulus
  add wave /tb_top_uart/en /tb_top_uart/wr /tb_top_uart/pen /tb_top_uart/pph /tb_top_uart/p
  add wave -radix hex /tb_top_uart/din
  add wave -divider transmitter
  add wave /tb_top_uart/txd /tb_top_uart/done
  add wave -radix unsigned /tb_top_uart/u0/present_state
  add wave -divider receiver
  add wave /tb_top_uart/read /tb_top_uart/frame_err
  add wave -radix hex /tb_top_uart/temp
  add wave -radix unsigned /tb_top_uart/rx0/present_state
}
run -all
