set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports reset]
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk]

set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS33} [get_ports sbus_rx_line]
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports pc_tx_line]