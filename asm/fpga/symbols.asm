// These symbols should be merged with asm/6502/os/symbols.asm after
// the emulator gets updated to the changes driven by the FPGA implementation

SRC_ADDR      = $00
DST_ADDR      = $02
SIZE          = $04
COPY_PARAMS   = $06

DISPLAY_START = $08
ATTRIB_START  = $0A
VRAM_FREE     = $0C

DLIST         = $30

CHRONI_ENABLED = $200
SCREEN_LINES   = $204
SCREEN_SIZE    = $206
ATTRIB_SIZE    = $208
ATTRIB_DEFAULT = $20A

VDLIST     = $9000
VCHARSET   = $9002
VPAL_INDEX = $9004
VPAL_VALUE = $9005
VADDR      = $9006
VDATA      = $9009
VADDR_AUX  = $900a
VDATA_AUX  = $900d
VPAGE      = $900e
VCOUNT     = $9010
WSYNC      = $9011
VSTATUS    = $9012
VSPRITES   = $9014
VTILESET_SMALL = $9016
VTILESET_BIG   = $9018
VBORDER    = $901a
HSCROLL    = $9020
VSCROLL    = $9021
VLINEINT   = $9022
VCLOCK     = $9024
VRAND      = $9025
VADDRW     = $9026
VADDRW_AUX = $9028
VAUTOINC   = $902a

SYS_CPU_CLK   = $9300
SYS_TIMER_NDX = $9301
SYS_TIMER_VL  = $9302 ; write = set ticks / read = get current ticks
SYS_TIMER_VH  = $9303
SYS_TIMER_VM  = $9304
SYS_TIMER_WR_EN  = $9305
SYS_TIMER_EN  = $9306
SYS_TIMER_ACK = $9307 ; write 1 to clear IRQ state on selected timer
SYS_TIMER_IRQ = $9307 ; read all 8 timers irq flags

SYS_SERIAL_READY = $9308
SYS_SERIAL_IN    = $9309
SYS_SERIAL_OUT   = $9309

VSTATUS_VSYNC      = $80
VSTATUS_HSYNC      = $40
VSTATUS_EMULATOR   = $20
VSTATUS_EN_INTS    = $04
VSTATUS_EN_SPRITES = $08
VSTATUS_ENABLE     = $10

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
