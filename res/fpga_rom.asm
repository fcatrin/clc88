SRC_ADDR      = $00
DST_ADDR      = $02
SIZE          = $04

VDLIST     = $9000
VCHARSET   = $9002
VPAL_INDEX = $9004
VPAL_VALUE = $9005
VADDR      = $9006
VDATA      = $9009
VBORDER    = $900c

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

   
   org $fffc
   .word START

BG_COLOR = $29AC   
FG_COLOR = $F75B
BORDER_COLOR = $2167
   
   org $fe00
START:

   lda #0
   sta VCHARSET

   sta VPAL_INDEX
   ldx #0
set_palette:   
   lda palette_dark, x
   STA VPAL_VALUE
   inx
   bne set_palette

   mwa #BORDER_COLOR VBORDER
   
// copy 16*256 bytes from $e000 to VRAM $00000

   mwa #$0000 VADDR
   mwa #$e000 SRC_ADDR
   
   ldx #0
   ldy #0
copy:   
   lda (SRC_ADDR), y
   sta VDATA
   iny
   bne copy
   inc SRC_ADDR+1
   inx
   cpx #16
   bne copy

   ldx #0
load5:
   lda display_list, x
   sta dlist_in_ram, x
   inx
   bne load5
   
dlist_addr    = $1d00
dlist_in_vram = dlist_addr / 2
dlist_in_ram  = dlist_addr + $a000

   mwa #dlist_in_vram VDLIST
   mwa #text_location VADDR
      
load6:
   lda test_string, x
   beq load_attr
   sta VDATA
   inx
   bne load6
   
load_attr:
   mwa #attr_location VADDR

   ldx #0
load7:
   LDA test_attrs, x
   beq main_loop
   sta VDATA
   inx
   bne load7
   
main_loop:   
   lda #0
   sta R0
wait_press:
   lda BUTTONS
   beq wait_press
   
   inc R0
   lda R0
   cmp #4
   bne not_wrap
   lda #0
   sta R0
not_wrap:
   sta VCHARSET
wait_release:   
   lda BUTTONS
   bne wait_release   
   jmp wait_press

text_location = $1e00
attr_location = $1e80

display_list:
   .byte $42
   .word text_location 
   .byte 0
   .word attr_location
   .byte 0
   .byte $02, $02, $02, $41

palette_dark:
   .word $2104
   .word $9C0A
   .word $AC0E
   .word $43B5

test_string:
   .byte 'This is Compy CLC-88 testing VRAM port access and attributes!', 0
   
test_attrs:
   .byte $01, $01, $01, $01, $01, $01, $01, $01, $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $02
   .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
   .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
   .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
   