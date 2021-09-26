VMODE_0_LINES       = 24
VMODE_0_SCREEN_SIZE = 80*VMODE_0_LINES
VMODE_0_ATTRIB_SIZE = 80*VMODE_0_LINES
VMODE_0_SUBPAL_SIZE = 16

VMODE_1_LINES       = 24
VMODE_1_SCREEN_SIZE = 40*VMODE_1_LINES
VMODE_1_ATTRIB_SIZE = 40*VMODE_1_LINES
VMODE_1_SUBPAL_SIZE = 16

VMODE_2_LINES       = 24
VMODE_2_SCREEN_SIZE = 20*VMODE_2_LINES
VMODE_2_ATTRIB_SIZE = 20*VMODE_2_LINES
VMODE_2_SUBPAL_SIZE = 16

VMODE_3_LINES       = 12
VMODE_3_SCREEN_SIZE = 20*VMODE_3_LINES
VMODE_3_ATTRIB_SIZE = 20*VMODE_3_LINES
VMODE_3_SUBPAL_SIZE = 16

VMODE_4_LINES       = 192
VMODE_4_SCREEN_SIZE = 40*VMODE_4_LINES
VMODE_4_ATTRIB_SIZE = 40*VMODE_4_LINES
VMODE_4_SUBPAL_SIZE = 16*4

VMODE_5_LINES       = 96
VMODE_5_SCREEN_SIZE = 40*VMODE_5_LINES
VMODE_5_ATTRIB_SIZE = 40*VMODE_5_LINES
VMODE_5_SUBPAL_SIZE = 16*4

VMODE_6_LINES       = 192
VMODE_6_SCREEN_SIZE = 80*VMODE_6_LINES
VMODE_6_ATTRIB_SIZE = 80*VMODE_6_LINES
VMODE_6_SUBPAL_SIZE = 16*16

VMODE_7_LINES       = 96
VMODE_7_SCREEN_SIZE = 80*VMODE_7_LINES
VMODE_7_ATTRIB_SIZE = 80*VMODE_7_LINES
VMODE_7_SUBPAL_SIZE = 16*16

VMODE_8_LINES       = 192
VMODE_8_SCREEN_SIZE = 40*VMODE_8_LINES
VMODE_8_ATTRIB_SIZE = 40*VMODE_8_LINES
VMODE_8_SUBPAL_SIZE = 2*2

VMODE_9_LINES       = 192
VMODE_9_SCREEN_SIZE = 80*VMODE_9_LINES
VMODE_9_ATTRIB_SIZE = 80*VMODE_9_LINES
VMODE_9_SUBPAL_SIZE = 4*4

VMODE_A_LINES       = 192
VMODE_A_SCREEN_SIZE = 160*VMODE_A_LINES
VMODE_A_ATTRIB_SIZE = 160*VMODE_A_LINES
VMODE_A_SUBPAL_SIZE = 16*16

VMODE_B_LINES       = 24
VMODE_B_SCREEN_SIZE = 40*VMODE_B_LINES
VMODE_B_ATTRIB_SIZE = 40*VMODE_B_LINES
VMODE_B_SUBPAL_SIZE = 4*8

VMODE_C_LINES       = 12
VMODE_C_SCREEN_SIZE = 10*VMODE_C_LINES
VMODE_C_ATTRIB_SIZE = 10*VMODE_C_LINES
VMODE_C_SUBPAL_SIZE = 16*8

VMODE_D_LINES       = 12
VMODE_D_SCREEN_SIZE = 20*VMODE_D_LINES
VMODE_D_ATTRIB_SIZE = 20*VMODE_D_LINES
VMODE_D_SUBPAL_SIZE = 16*8

set_video_mode_std:
   pha
   asl
   tax
   mwa video_mode_params,x SRC_ADDR
   pla
   clc
   adc #2
   tay
   jsr set_video_mode_screen
   jsr set_video_mode_dl

   lda ROS7 ; palette type
   bne use_spectrum_palette
   
   mwa #palette_atari SRC_ADDR
   jmp set_video_mode_finish
   
use_spectrum_palette:
   mwa #palette_spectrum SRC_ADDR
   
set_video_mode_finish:
   jsr set_video_palette
   jmp set_video_enabled
 
 
set_video_palette:
   lda #0
   sta VPAL_INDEX
   ldx #2
   ldy #0
   
upload_palette   
   lda (SRC_ADDR), y
   sta VPAL_VALUE
   iny
   bne upload_palette
   inc SRC_ADDR + 1
   dex
   bne upload_palette
   rts
  
set_video_enabled:
   lda #1
   sta CHRONI_ENABLED
   lda VSTATUS
   ora #VSTATUS_EN_INTS
   sta VSTATUS
   rts
   
set_video_disabled:
   lda #0
   sta CHRONI_ENABLED
   lda VSTATUS
   and #($ff - VSTATUS_ENABLE)
   sta VSTATUS
   rts
   
set_video_mode_dl:
   lda #<VRAM_ADDR_SCREEN
   sta DLIST
   sta VDLIST
   lda #<VRAM_ADDR_SCREEN+1
   sta DLIST+1
   sta VDLIST+1
   rts

set_video_mode_screen:
   tya
   pha
   
   mwa #11 SIZE
   mwa #SCREEN_LINES DST_ADDR
   jsr copy_block

   mwa #VRAM_ADDR_SCREEN VADDR

   pla
   tay
   lda #112
   sta VDATA
   sta VDATA
   sta VDATA
   tya
   ora #$40
   sta VDATA
   lda #0
   
   sta VDATA // this will be overwritten later with LMS and ATTR pointers
   sta VDATA
   sta VDATA
   sta VDATA
   sta VDATA
   sta VDATA

   tya
   ldx #1
vmode_set_lines:
   sta VDATA   
   inx
   cpx SCREEN_LINES
   bne vmode_set_lines
   lda #$41
   sta VDATA ; End of Screen
   
; calculate display, attribs and free addresses
   mwa VADDR DISPLAY_START 
   adw SCREEN_SIZE DISPLAY_START ATTRIB_START
   adw ATTRIB_SIZE ATTRIB_START VRAM_FREE

; set addresses for LMS and Atrribs on display list
   mwa #VRAM_ADDR_SCREEN+4 VADDR
   lda DISPLAY_START
   sta VDATA
   lda DISPLAY_START+1
   sta VDATA
   
   mwa #VRAM_ADDR_SCREEN+7 VADDR
   lda ATTRIB_START
   sta VDATA
   lda ATTRIB_START+1
   sta VDATA
   
; initialize display and attrib data
   lda #0
   sta VADDR+2
   
   mwa DISPLAY_START VADDR
   mwa SCREEN_SIZE SIZE
   jsr vram_clear
   
   mwa ATTRIB_START VADDR
   mwa SCREEN_SIZE SIZE
   lda ATTRIB_DEFAULT
   jmp vram_set

   
vram_copy:
   jsr vram2ram
   mwa RAM_TO_VRAM DST_ADDR
   mva VRAM_PAGE   VPAGE
   jmp ram_vram_copy

vram_clear:
   lda #$00
   
; naive and slow implementation for now
; it will carefully walk through memory until the end of the current bank
vram_set:
   sta VDATA
   dec SIZE
   bne vram_set
   dec SIZE+1
   ldx SIZE+1
   cpx #$ff
   bne vram_set
   rts
   
.proc vram_set_charset
   ldy #0
   ldx #4
next:   
   lda (SRC_ADDR), y
   sta VDATA
   iny
   bne next
   inc SRC_ADDR+1
   dex
   bne next
   rts
.endp

; naive and slow implementation for now
; it will carefully copy from ram to vram until the end of the current bank

ram_vram_copy:
   lda VPAGE
   sta R0
   
   ldy #0
ram_vram_copy_loop:
   lda (SRC_ADDR), y   
   sta (DST_ADDR), y
   inc DST_ADDR
   bne ram_vram_copy_next
   ldx DST_ADDR+1
   inx
   cpx #$e0
   bne ram_vram_copy_next_page
   
   ldx #$a0
   inc VPAGE
   
ram_vram_copy_next_page:
   stx DST_ADDR+1
      
ram_vram_copy_next:
   inc SRC_ADDR
   bne ram_vram_copy_no_src_page
   inc SRC_ADDR+1
   
ram_vram_copy_no_src_page:
   dec SIZE
   bne ram_vram_copy_loop
   dec SIZE+1
   ldx SIZE+1
   cpx #$ff
   bne ram_vram_copy_loop
   
   lda R0
   sta VPAGE
   rts

; vram = (page << 8 << 6 + (addr-VRAM)) / 2 => page << 8 << 5 + (addr-VRAM)/2
; in : RAM_TO_VRAM with CPU address
;      VRAM_PAGE 16K Page in VRAM
;
; out: VRAM_TO_RAM with Chroni address (in words)

ram2vram:
   sbw RAM_TO_VRAM #VRAM
   lda RAM_TO_VRAM+1
   lsr
   sta VRAM_TO_RAM+1
   lda RAM_TO_VRAM
   ror
   sta VRAM_TO_RAM
   
   lda VRAM_PAGE
   asl
   asl
   asl
   asl
   asl
   ora VRAM_TO_RAM+1
   sta VRAM_TO_RAM+1
   rts

; page = (vram & 0xE000) >> 5 >> 8
; addr = (vram & 0x1FFF) * 2 + VRAM 
; in: VRAM_TO_RAM with Chroni address (in words)
; out: RAM_TO_VRAM with CPU address
;      VRAM_PAGE with 16K Page in VRAM

vram2ram:
   lda VRAM_TO_RAM+1
   and #$E0
   lsr
   lsr
   lsr
   lsr
   lsr
   sta VRAM_PAGE
   
   lda VRAM_TO_RAM+1
   and #$1F
   sta VRAM_TO_RAM+1
   
   lda VRAM_TO_RAM
   asl
   sta VRAM_TO_RAM
   rol VRAM_TO_RAM+1
   
   adw VRAM_TO_RAM #VRAM RAM_TO_VRAM
   rts

; in: a = low byte
;     x = high byte
; out: ROS1 = in / 2

word_div2:
   stx ROS1
   lsr ROS1
   ror
   sta ROS0
   rts
   
word_mul2:
   stx ROS1
   asl
   sta ROS0
   rol ROS1 
   rts

video_mode_params_0:
   .word VMODE_0_LINES, VMODE_0_SCREEN_SIZE, VMODE_0_ATTRIB_SIZE, VMODE_0_SUBPAL_SIZE, video_mode_subpal_0, $10
video_mode_params_1:
   .word VMODE_1_LINES, VMODE_1_SCREEN_SIZE, VMODE_1_ATTRIB_SIZE, VMODE_1_SUBPAL_SIZE, video_mode_subpal_0, $10
video_mode_params_2:
   .word VMODE_2_LINES, VMODE_2_SCREEN_SIZE, VMODE_2_ATTRIB_SIZE, VMODE_2_SUBPAL_SIZE, video_mode_subpal_0, $10
video_mode_params_3:
   .word VMODE_3_LINES, VMODE_3_SCREEN_SIZE, VMODE_3_ATTRIB_SIZE, VMODE_3_SUBPAL_SIZE, video_mode_subpal_0, $10
video_mode_params_4:
   .word VMODE_4_LINES, VMODE_4_SCREEN_SIZE, VMODE_4_ATTRIB_SIZE, VMODE_4_SUBPAL_SIZE, video_mode_subpal_3, $00
video_mode_params_5:
   .word VMODE_5_LINES, VMODE_5_SCREEN_SIZE, VMODE_5_ATTRIB_SIZE, VMODE_5_SUBPAL_SIZE, video_mode_subpal_3, $00
video_mode_params_6:
   .word VMODE_6_LINES, VMODE_6_SCREEN_SIZE, VMODE_6_ATTRIB_SIZE, VMODE_6_SUBPAL_SIZE, video_mode_subpal_3, $00
video_mode_params_7:
   .word VMODE_7_LINES, VMODE_7_SCREEN_SIZE, VMODE_7_ATTRIB_SIZE, VMODE_7_SUBPAL_SIZE, video_mode_subpal_3, $00
video_mode_params_8:
   .word VMODE_8_LINES, VMODE_8_SCREEN_SIZE, VMODE_8_ATTRIB_SIZE, VMODE_8_SUBPAL_SIZE, video_mode_subpal_3, $00
video_mode_params_9:
   .word VMODE_9_LINES, VMODE_9_SCREEN_SIZE, VMODE_9_ATTRIB_SIZE, VMODE_9_SUBPAL_SIZE, video_mode_subpal_3, $00
video_mode_params_a:
   .word VMODE_A_LINES, VMODE_A_SCREEN_SIZE, VMODE_A_ATTRIB_SIZE, VMODE_A_SUBPAL_SIZE, video_mode_subpal_3, $00
video_mode_params_b:
   .word VMODE_B_LINES, VMODE_B_SCREEN_SIZE, VMODE_B_ATTRIB_SIZE, VMODE_B_SUBPAL_SIZE, video_mode_subpal_0, $00
video_mode_params_c:
   .word VMODE_C_LINES, VMODE_C_SCREEN_SIZE, VMODE_C_ATTRIB_SIZE, VMODE_C_SUBPAL_SIZE, video_mode_subpal_3, $00
video_mode_params_d:
   .word VMODE_D_LINES, VMODE_D_SCREEN_SIZE, VMODE_D_ATTRIB_SIZE, VMODE_D_SUBPAL_SIZE, video_mode_subpal_3, $00


video_mode_params:
   .word video_mode_params_0
   .word video_mode_params_1
   .word video_mode_params_2
   .word video_mode_params_3
   .word video_mode_params_4
   .word video_mode_params_5
   .word video_mode_params_6
   .word video_mode_params_7
   .word video_mode_params_8
   .word video_mode_params_9
   .word video_mode_params_a
   .word video_mode_params_b
   .word video_mode_params_c
   .word video_mode_params_d
   
video_mode_subpal_0
   .byte 0x94, 0x0C, 0xE6, 0x00
   .byte 0x2C, 0x0F, 0x00, 0x00
   .byte 0x00, 0x00, 0x00, 0x00
   .byte 0x00, 0x00, 0x00, 0x00

video_mode_subpal_3:
   .byte 0x94, 0x0f, 0x94, 0x9a
   .byte 0x10, 0x1f, 0xa4, 0xaa
   .byte 0x20, 0x2f, 0xb4, 0xba
   .byte 0x30, 0x3f, 0xc4, 0xca
   .byte 0x40, 0x4f, 0xd4, 0xda
   .byte 0x50, 0x5f, 0xe4, 0xea
   .byte 0x60, 0x6f, 0xf4, 0xfa
   .byte 0x70, 0x7f, 0x04, 0x0a
   .byte 0x80, 0x8f, 0x14, 0x1a
   .byte 0x90, 0x9f, 0x24, 0x2a
   .byte 0xa0, 0xaf, 0x34, 0x3a
   .byte 0xb0, 0xbf, 0x44, 0x4a
   .byte 0xc0, 0xcf, 0x54, 0x5a
   .byte 0xd0, 0xdf, 0x64, 0x6a
   .byte 0xe0, 0xef, 0x74, 0x7a
   .byte 0xf0, 0xff, 0x84, 0x8a
   
   