set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports {reset}];
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports {clk}];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {clk}];

set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports {sbus_rx_line}];
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {failsafe_active}];

set_property -dict { PACKAGE_PIN D14 IOSTANDARD LVCMOS33 } [get_ports {servo_pwm_out[0]}];
set_property -dict { PACKAGE_PIN F16 IOSTANDARD LVCMOS33 } [get_ports {servo_pwm_out[1]}];
set_property -dict { PACKAGE_PIN G16 IOSTANDARD LVCMOS33 } [get_ports {servo_pwm_out[2]}];
set_property -dict { PACKAGE_PIN H14 IOSTANDARD LVCMOS33 } [get_ports {servo_pwm_out[3]}];
set_property -dict { PACKAGE_PIN E16 IOSTANDARD LVCMOS33 } [get_ports {servo_pwm_out[4]}];
set_property -dict { PACKAGE_PIN F13 IOSTANDARD LVCMOS33 } [get_ports {servo_pwm_out[5]}];
set_property -dict { PACKAGE_PIN G13 IOSTANDARD LVCMOS33 } [get_ports {servo_pwm_out[6]}];
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports {servo_pwm_out[7]}];
