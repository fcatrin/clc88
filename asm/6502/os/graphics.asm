VMODE_0_LINES       = 24
VMODE_0_SCREEN_SIZE = 40*VMODE_0_LINES
VMODE_0_ATTRIB_SIZE = 40*VMODE_0_LINES
VMODE_0_SUBPAL_SIZE = 16

VMODE_1_LINES       = 24
VMODE_1_SCREEN_SIZE = 20*VMODE_1_LINES
VMODE_1_ATTRIB_SIZE = 20*VMODE_1_LINES
VMODE_1_SUBPAL_SIZE = 16

VMODE_2_LINES       = 12
VMODE_2_SCREEN_SIZE = 20*VMODE_2_LINES
VMODE_2_ATTRIB_SIZE = 20*VMODE_2_LINES
VMODE_2_SUBPAL_SIZE = 16

VMODE_3_LINES       = 192
VMODE_3_SCREEN_SIZE = 40*VMODE_3_LINES
VMODE_3_ATTRIB_SIZE = 40*VMODE_3_LINES
VMODE_3_SUBPAL_SIZE = 16*4

VMODE_4_LINES       = 96
VMODE_4_SCREEN_SIZE = 40*VMODE_4_LINES
VMODE_4_ATTRIB_SIZE = 40*VMODE_4_LINES
VMODE_4_SUBPAL_SIZE = 16*4

VMODE_5_LINES       = 192
VMODE_5_SCREEN_SIZE = 80*VMODE_5_LINES
VMODE_5_ATTRIB_SIZE = 80*VMODE_5_LINES
VMODE_5_SUBPAL_SIZE = 16*16

VMODE_6_LINES       = 96
VMODE_6_SCREEN_SIZE = 80*VMODE_6_LINES
VMODE_6_ATTRIB_SIZE = 80*VMODE_6_LINES
VMODE_6_SUBPAL_SIZE = 16*16

VMODE_7_LINES       = 192
VMODE_7_SCREEN_SIZE = 40*VMODE_7_LINES
VMODE_7_ATTRIB_SIZE = 40*VMODE_7_LINES
VMODE_7_SUBPAL_SIZE = 2*2

VMODE_8_LINES       = 192
VMODE_8_SCREEN_SIZE = 80*VMODE_8_LINES
VMODE_8_ATTRIB_SIZE = 80*VMODE_8_LINES
VMODE_8_SUBPAL_SIZE = 4*4

VMODE_9_LINES       = 192
VMODE_9_SCREEN_SIZE = 160*VMODE_9_LINES
VMODE_9_ATTRIB_SIZE = 160*VMODE_9_LINES
VMODE_9_SUBPAL_SIZE = 16*16

VMODE_A_LINES       = 24
VMODE_A_SCREEN_SIZE = 40*VMODE_A_LINES
VMODE_A_ATTRIB_SIZE = 40*VMODE_A_LINES
VMODE_A_SUBPAL_SIZE = 4*8

VMODE_B_LINES       = 12
VMODE_B_SCREEN_SIZE = 10*VMODE_B_LINES
VMODE_B_ATTRIB_SIZE = 10*VMODE_B_LINES
VMODE_B_SUBPAL_SIZE = 16*8

VMODE_C_LINES       = 12
VMODE_C_SCREEN_SIZE = 20*VMODE_C_LINES
VMODE_C_ATTRIB_SIZE = 20*VMODE_C_LINES
VMODE_C_SUBPAL_SIZE = 16*8

set_video_mode_std:
   pha
   asl
   tax
   mwa video_mode_params,x COPY_SRC_ADDR
   pla
   clc
   adc #2
   tay
   jsr set_video_mode_screen
   jsr set_video_mode_dl

   lda ROS8 ; palette type
   bne use_spectrum_palette
   
   mwa #VRAM_PAL_ATARI RAM_TO_VRAM
   jmp set_video_mode_finish
   
use_spectrum_palette:
   mwa #VRAM_PAL_ZX RAM_TO_VRAM
   
set_video_mode_finish:
   jsr set_video_palette
   jmp set_video_enabled
 
 
 set_video_palette:
   lda #0
   sta VRAM_PAGE
   jsr ram2vram
   mwa VRAM_TO_RAM VPALETTE
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
   lda #0
   sta VRAM_PAGE
   mwa #VRAM_SCREEN RAM_TO_VRAM
   jsr ram2vram
   lda VRAM_TO_RAM
   sta DLIST
   sta VDLIST
   lda VRAM_TO_RAM+1
   sta DLIST+1
   sta VDLIST+1
   rts

set_video_mode_screen:
   tya
   pha
   
   mwa #11 COPY_SIZE
   mwa #SCREEN_LINES COPY_DST_ADDR
   jsr copy_block

   pla
   tay
   lda #112
   sta VRAM_SCREEN
   sta VRAM_SCREEN+1
   sta VRAM_SCREEN+2
   tya
   ora #$40
   sta VRAM_SCREEN+3

   tya
   ldx #1
vmode_set_lines:   
   sta VRAM_SCREEN+9, x ; take LMS part as already done
   inx
   cpx SCREEN_LINES
   bne vmode_set_lines
   lda #$41
   sta VRAM_SCREEN+9, x ; End of Screen
   
; calculate display, attribs and subpal adresses
   clc
   lda #<(VRAM_SCREEN + 3 + 7 + 1 + 1) ; 3 blank scans + 7 bytes LMS + 1 byte End of screen
   adc SCREEN_LINES
   and #$fe
   sta RAM_TO_VRAM
   
   lda #>(VRAM_SCREEN + 3 + 7 + 1 + 1)
   adc SCREEN_LINES+1
   sta RAM_TO_VRAM+1

   lda #0
   sta VRAM_PAGE
   
   jsr ram2vram
   
   mwa VRAM_TO_RAM DISPLAY_START
   
   lda SCREEN_SIZE
   ldx SCREEN_SIZE+1
   jsr word_div2
   
   adw DISPLAY_START ROS1 ATTRIB_START
   
   lda ATTRIB_SIZE
   ldx ATTRIB_SIZE+1
   jsr word_div2
   
   adw ATTRIB_START ROS1 SUBPAL_START

   lda SUBPAL_SIZE
   ldx SUBPAL_SIZE+1
   jsr word_div2
   
   adw SUBPAL_START ROS1 VRAM_FREE

; set values on LMS command
   mwa DISPLAY_START VRAM_SCREEN+4
   mwa ATTRIB_START  VRAM_SCREEN+6
   mwa SUBPAL_START  VRAM_SCREEN+8
   
   mwa DISPLAY_START VRAM_TO_RAM
   mwa SCREEN_SIZE COPY_SIZE
   
   jsr vram_clear
   
   mwa ATTRIB_START VRAM_TO_RAM
   mwa ATTRIB_SIZE COPY_SIZE
   lda ATTRIB_DEFAULT
   jsr vram_clear_to

   mwa SUBPAL_START VRAM_TO_RAM
   mwa SUBPAL_SIZE  COPY_SIZE
   mwa SUBPAL_ADDR  COPY_SRC_ADDR
   jmp vram_copy
   
vram_clear:
   lda #$00

vram_clear_to:
   pha
   jsr vram2ram
   mwa RAM_TO_VRAM COPY_DST_ADDR
   mva VRAM_PAGE   VPAGE
   pla
   jmp vram_set_bytes

   
vram_copy:
   jsr vram2ram
   mwa RAM_TO_VRAM COPY_DST_ADDR
   mva VRAM_PAGE   VPAGE
   jmp ram_vram_copy
   
; naive and slow implementation for now
; it will carefully walk through memory until the end of the current bank
vram_set_bytes:
   sta R1
   lda VPAGE
   sta R2
   
   ldy #0
   lda R1
vram_set_bytes_loop:   
   sta (COPY_DST_ADDR), y
   inc COPY_DST_ADDR
   bne vram_set_bytes_next
   ldx COPY_DST_ADDR+1
   inx
   cpx #$e0
   bne vram_set_bytes_next_page
   
   ldx #$a0
   inc VPAGE
   lda R1    ; restore byte to be written
   
vram_set_bytes_next_page:
   stx COPY_DST_ADDR+1
      
vram_set_bytes_next:
   dec COPY_SIZE
   bne vram_set_bytes_loop
   dec COPY_SIZE+1
   ldx COPY_SIZE+1
   cpx #$ff
   bne vram_set_bytes_loop
   
   lda R2
   sta VPAGE
   rts

; naive and slow implementation for now
; it will carefully copy from ram to vram until the end of the current bank

ram_vram_copy:
   lda VPAGE
   sta R1
   
   ldy #0
ram_vram_copy_loop:
   lda (COPY_SRC_ADDR), y   
   sta (COPY_DST_ADDR), y
   inc COPY_DST_ADDR
   bne ram_vram_copy_next
   ldx COPY_DST_ADDR+1
   inx
   cpx #$e0
   bne ram_vram_copy_next_page
   
   ldx #$a0
   inc VPAGE
   
ram_vram_copy_next_page:
   stx COPY_DST_ADDR+1
      
ram_vram_copy_next:
   inc COPY_SRC_ADDR
   bne ram_vram_copy_no_src_page
   inc COPY_SRC_ADDR+1
   
ram_vram_copy_no_src_page:
   dec COPY_SIZE
   bne ram_vram_copy_loop
   dec COPY_SIZE+1
   ldx COPY_SIZE+1
   cpx #$ff
   bne ram_vram_copy_loop
   
   lda R1
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
; out: ROS2 = in / 2

word_div2:
   stx ROS2
   lsr ROS2
   ror
   sta ROS1
   rts
   
word_mul2:
   stx ROS2
   asl
   sta ROS1
   rol ROS2
   rts

video_mode_params_0:
   .word VMODE_0_LINES, VMODE_0_SCREEN_SIZE, VMODE_0_ATTRIB_SIZE, VMODE_0_SUBPAL_SIZE, video_mode_subpal_0, $10
video_mode_params_1:
   .word VMODE_1_LINES, VMODE_1_SCREEN_SIZE, VMODE_1_ATTRIB_SIZE, VMODE_1_SUBPAL_SIZE, video_mode_subpal_0, $10
video_mode_params_2:
   .word VMODE_2_LINES, VMODE_2_SCREEN_SIZE, VMODE_2_ATTRIB_SIZE, VMODE_2_SUBPAL_SIZE, video_mode_subpal_0, $10
video_mode_params_3:
   .word VMODE_3_LINES, VMODE_3_SCREEN_SIZE, VMODE_3_ATTRIB_SIZE, VMODE_3_SUBPAL_SIZE, video_mode_subpal_3, $00
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
   .word VMODE_A_LINES, VMODE_A_SCREEN_SIZE, VMODE_A_ATTRIB_SIZE, VMODE_A_SUBPAL_SIZE, video_mode_subpal_0, $00
video_mode_params_b:
   .word VMODE_B_LINES, VMODE_B_SCREEN_SIZE, VMODE_B_ATTRIB_SIZE, VMODE_B_SUBPAL_SIZE, video_mode_subpal_3, $00
video_mode_params_c:
   .word VMODE_C_LINES, VMODE_C_SCREEN_SIZE, VMODE_C_ATTRIB_SIZE, VMODE_C_SUBPAL_SIZE, video_mode_subpal_3, $00


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
   
video_mode_subpal_0
   .byte 0x94, 0x0C, 0x00, 0x00
   .byte 0x00, 0x00, 0x00, 0x00
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
   
   