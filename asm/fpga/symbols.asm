// These symbols should be merged with asm/6502/os/symbols.asm after
// the emulator gets updated to the changes driven by the FPGA implementation

SRC_ADDR      = $00
DST_ADDR      = $02
SIZE          = $04

DISPLAY_START = $08
ATTRIB_START  = $0B


VDLIST     = $9000
VCHARSET   = $9002
VPAL_INDEX = $9004
VPAL_VALUE = $9005
VADDR      = $9006
VDATA      = $9009
VADDR_AUX  = $900a
VDATA_AUX  = $900d
VBORDER    = $900e

BUTTONS  = $9200

R0            = $C0
R1            = $C1
R2            = $C2
R3            = $C3
R4            = $C4
R5            = $C5
R6            = $C6
R7            = $C7
ROS0          = $C8
ROS1          = $C9
ROS2          = $CA
ROS3          = $CB
ROS4          = $CC
ROS5          = $CD
ROS6          = $CE
ROS7          = $CF
