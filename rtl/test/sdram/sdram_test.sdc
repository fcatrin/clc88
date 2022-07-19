## Generated SDC file "compy.out.sdc"

## Copyright (C) 2018  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel FPGA IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Intel and sold by Intel or its authorized distributors.  Please
## refer to the applicable agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 18.1.0 Build 625 09/12/2018 SJ Lite Edition"

## DATE    "Sun May 30 01:19:19 2021"

##
## DEVICE  "EP4CE55F23C8"
##


#**************************************************************
# Time Information
#**************************************************************
set_time_format -unit ns -decimal_places 3


#**************************************************************
# Create Clock
#**************************************************************
# create_clock -name {altera_reserved_tck} -period 100.000 -waveform { 0.000 50.000 } [get_ports {altera_reserved_tck}]
create_clock -name {clk50} -period 20.000 -waveform { 0.000 10.000 } [get_ports {clk50}]


#**************************************************************
# Create Generated Clock
#**************************************************************
derive_pll_clocks -create_base_clocks
derive_clock_uncertainty


#**************************************************************
# Set Clock Latency
#**************************************************************


#**************************************************************
# Set Clock Uncertainty
#**************************************************************


#**************************************************************
# Set Input Delay
#**************************************************************

#**************************************************************
# Set Output Delay
#**************************************************************

#**************************************************************
# Set Clock Groups
#**************************************************************


#**************************************************************
# Set False Path
#**************************************************************
# set_false_path -from [get_ports altera_reserved_*]
# set_false_path -to   [get_ports altera_reserved_*]
set_false_path -from [get_ports key_reset]
set_false_path -from [get_ports key_start]
set_false_path -from [get_ports S_*]
set_false_path -to   [get_ports S_*]

#**************************************************************
# Set Multicycle Path
#**************************************************************
set_multicycle_path -setup -from user_reset   -to *sdram_test* 2
set_multicycle_path -hold  -from user_reset   -to *sdram_test* 1
set_multicycle_path -setup -from boot_reset   -to *sdram_test* 2
set_multicycle_path -hold  -from boot_reset   -to *sdram_test* 1

#**************************************************************
# Set Maximum Delay
#**************************************************************


#**************************************************************
# Set Minimum Delay
#**************************************************************


#**************************************************************
# Set Input Transition
#**************************************************************

