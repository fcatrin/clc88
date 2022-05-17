VMODE_DEF_SIZE = 6

VMODE_0_LINES       = 30
VMODE_0_SCREEN_SIZE = 80*VMODE_0_LINES
VMODE_0_ATTRIB_SIZE = 80*VMODE_0_LINES

VMODE_1_LINES       = 30
VMODE_1_SCREEN_SIZE = 40*VMODE_1_LINES
VMODE_1_ATTRIB_SIZE = 40*VMODE_1_LINES

VMODE_2_LINES       = 30
VMODE_2_SCREEN_SIZE = 40*VMODE_2_LINES
VMODE_2_ATTRIB_SIZE = 40*VMODE_2_LINES

VMODE_3_LINES       = 15
VMODE_3_SCREEN_SIZE = 40*VMODE_2_LINES
VMODE_3_ATTRIB_SIZE = 40*VMODE_2_LINES

CHARSET_SIZE      = $400
VRAM_ADDR_CHARSET = 0
VRAM_ADDR_SCREEN  = VRAM_ADDR_CHARSET + CHARSET_SIZE

.proc gfx_upload_palette
   lda #0
   sta VPAL_INDEX
   ldx #2
   ldy #0
set_palette:   
   lda (SRC_ADDR), y
   sta VPAL_VALUE
   iny
   bne set_palette
   dex
   bne set_palette
   rts
.endp   

.proc gfx_upload_font
   ldx #4
   ldy #0
upload_next:   
   lda (SRC_ADDR), y
   sta VDATA
   iny
   bne upload_next
   inc SRC_ADDR+1
   dex
   bne upload_next
   rts
.endp

.proc gfx_set_video_mode
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
   jmp gfx_set_video_enabled
   
set_video_mode_screen:
   tya
   pha
   
   mwa #VMODE_DEF_SIZE   SIZE
   mwa #SCREEN_LINES     DST_ADDR
   jsr copy_block

   mwa #VRAM_ADDR_SCREEN VADDR

   pla
   tay
   
   ora #$40
   sta VDATA
   lda #0
   
   sta VDATA // this will be overwritten later with LMS and ATTR pointers
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
   
; calculate display, attribs and free addresses in words
; DISPLAY_START = current word address
; ATTRIB_START  = DISPLAY_START + SCREEN_SIZE / 2
   mwa VADDRW DISPLAY_START
   mwa SCREEN_SIZE VADDR ; use VADDR->VADDRW for simple division by 2
   adw VADDRW DISPLAY_START ATTRIB_START
   
   mwa ATTRIB_SIZE VADDR
   adw VADDRW ATTRIB_START VRAM_FREE

; set addresses for LMS and Atrribs on display list
   mwa #VRAM_ADDR_SCREEN+1 VADDR
   lda DISPLAY_START
   sta VDATA
   lda DISPLAY_START+1
   sta VDATA
   
   mwa #VRAM_ADDR_SCREEN+3 VADDR
   lda ATTRIB_START
   sta VDATA
   lda ATTRIB_START+1
   sta VDATA
   
; initialize display and attrib data
   lda #0
   sta VADDR+2

   jsr gfx_display_clear
   jmp gfx_attrib_clear
   
set_video_mode_dl:
   lda #<(VRAM_ADDR_SCREEN/2)
   sta DLIST
   sta VDLIST
   lda #>(VRAM_ADDR_SCREEN/2)
   sta DLIST+1
   sta VDLIST+1
   rts
   
.endp   

gfx_display_clear:
   mwa DISPLAY_START VADDRW
   mwa SCREEN_SIZE SIZE
   jmp gfx_vram_clear

gfx_attrib_clear:
   mwa ATTRIB_START VADDRW
   mwa SCREEN_SIZE SIZE
   lda ATTRIB_DEFAULT
   jmp gfx_vram_set

gfx_vram_clear:
   lda #$00
   
; naive and slow implementation for now
; it will carefully walk through memory until the end of the current bank
gfx_vram_set:
   sta VDATA
   dec SIZE
   bne gfx_vram_set
   dec SIZE+1
   ldx SIZE+1
   cpx #$ff
   bne gfx_vram_set
   rts
   
gfx_set_video_enabled:
   lda #1
   sta CHRONI_ENABLED
   lda VSTATUS
   ora #VSTATUS_EN_INTS
   sta VSTATUS
   rts
   
gfx_set_video_disabled:
   lda #0
   sta CHRONI_ENABLED
   lda VSTATUS
   and #($ff - VSTATUS_ENABLE)
   sta VSTATUS
   rts
   

video_mode_params_0:
   .word VMODE_0_LINES, VMODE_0_SCREEN_SIZE, VMODE_0_ATTRIB_SIZE, $9F
video_mode_params_1:
   .word VMODE_1_LINES, VMODE_1_SCREEN_SIZE, VMODE_1_ATTRIB_SIZE, $9F
video_mode_params_2:
   .word VMODE_2_LINES, VMODE_2_SCREEN_SIZE, VMODE_2_ATTRIB_SIZE, $9F
video_mode_params_3:
   .word VMODE_3_LINES, VMODE_3_SCREEN_SIZE, VMODE_3_ATTRIB_SIZE, $9F

video_mode_params:
   .word video_mode_params_0
   .word video_mode_params_1
   .word video_mode_params_2
   .word video_mode_params_3
