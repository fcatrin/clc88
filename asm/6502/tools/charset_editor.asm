   icl '../os/symbols.asm'
	
CHARSET_EDIT = $4000	

CHARSET_POS_X = 4
CHARSET_POS_Y = 19
	
   org BOOTADDR

   lda #0
   ldy #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL

   jsr set_scanline_interrupt

   mwa VRAM_FREE VRAM_TO_RAM
   mwa VRAM_FREE charset_edit_start_vram
   jsr lib_vram_to_ram
   mwa RAM_TO_VRAM charset_edit_start

   mwa CHARSET_START VRAM_TO_RAM
   jsr lib_vram_to_ram

   mwa RAM_TO_VRAM        SRC_ADDR
   mwa charset_edit_start DST_ADDR
   mwa #$400 SIZE
   jsr memcpy
   
   jsr prepare_editor_charset
   jsr draw_char_editor_borders
   jsr display_charset
   
   jsr draw_char_editor
   
   jsr charset_char_update
   
main_loop 

   jsr keyb_read
   cmp last_key
   beq no_key_pressed
   sta last_key

   jsr charset_char_onkey
   
no_key_pressed:
   jmp main_loop
   
.proc display_charset
   ldx #CHARSET_POS_X
   ldy #CHARSET_POS_Y
   jsr screen_position

   ldx #0
next_row
   ldy #0
next_char
   txa
   sta (RAM_TO_VRAM), y
   inx
   iny
   cpy #32
   bne next_char
   adw RAM_TO_VRAM #40
   cpx #$80
   bne next_row
   rts
.endp

.proc prepare_editor_charset
   mwa CHARSET_START VRAM_TO_RAM
   jsr lib_vram_to_ram
   adw RAM_TO_VRAM #8
   
   mwa #block_chars SRC_ADDR
   mwa RAM_TO_VRAM DST_ADDR
   mwa #5*8 SIZE
   jmp memcpy      
.endp

.proc draw_char_editor_borders
   ldx #2
   ldy #2
   jsr screen_position
   
   lda #1
   ldy #0
   sta (RAM_TO_VRAM), y
   iny
   lda #2
border_top
   sta (RAM_TO_VRAM), y
   iny
   cpy #9
   bne border_top
   
   ldy #0
   ldx #8
border_left
   adw RAM_TO_VRAM #40
   lda #3
   sta (RAM_TO_VRAM), y
   dex
   bne border_left
   rts
.endp

.proc draw_char_editor
   mwa #0 SRC_ADDR
   lda charset_char_index
   asl
   rol SRC_ADDR+1
   asl
   rol SRC_ADDR+1
   asl
   rol SRC_ADDR+1
   sta SRC_ADDR
   
   adw SRC_ADDR charset_edit_start
   
   ldx #3
   ldy #3
   jsr screen_position
   
   mva #0 charset_index
   
   ldy #0
next_row
   lda (SRC_ADDR), y
   ldy #0
next_bit
   asl
   sta R0
   lda #4
   scc
   lda #5
   sta (RAM_TO_VRAM), y
   lda R0
   iny
   cpy #8
   bne next_bit
   
   adw RAM_TO_VRAM #40
   inc charset_index
   ldy charset_index
   cpy #8
   bne next_row
   rts
   
charset_index .byte 0
.endp

.proc set_scanline_interrupt
   lda VSTATUS
   and #(255 - VSTATUS_EN_INTS)
   sta VSTATUS
      
   mwa #dli    HBLANK_VECTOR_USER
   mwa #vblank VBLANK_VECTOR_USER
   
   lda #20*8
   sta VLINEINT

   lda VSTATUS
   ora #VSTATUS_EN_INTS
   sta VSTATUS
   rts
.endp

.proc dli
   pha
   lda #$66
   sta WSYNC
   sta VCOLOR0
   mwa charset_edit_start_vram VCHARSET
   pla
   rts
.endp

.proc vblank
   pha
   lda #0
   sta VCOLOR0
   mwa #0 VCHARSET
   pla
   rts
.endp   

.proc charset_char_onkey
   cmp #16
   jeq charset_char_select_up
   cmp #17
   jeq charset_char_select_down
   cmp #14
   jeq charset_char_select_left
   cmp #15
   jeq charset_char_select_right
   rts
.endp

.proc charset_char_select_left
   dec charset_char_x
   spl
   mva #31 charset_char_x
   jmp charset_char_highlight
.endp

.proc charset_char_select_right
   inc charset_char_x
   lda charset_char_x
   cmp #32
   sne
   mva #0 charset_char_x
   jmp charset_char_highlight
.endp

.proc charset_char_select_up
   dec charset_char_y
   spl
   mva #3 charset_char_y
   jmp charset_char_highlight
.endp

.proc charset_char_select_down
   inc charset_char_y
   lda charset_char_y
   cmp #4
   sne
   mva #0 charset_char_y
   jmp charset_char_highlight
.endp

.proc charset_char_highlight
   jsr charset_char_update
   lda charset_char_y
   asl
   asl
   asl
   asl
   asl
   clc
   adc charset_char_x
   sta charset_char_index
   jmp draw_char_editor
.endp


.proc charset_char_update
   mwa charset_char_attrib_last RAM_TO_VRAM
   lda RAM_TO_VRAM
   ora RAM_TO_VRAM+1
   beq not_reset_attrib
   
   ldy #0
   mva #$10 (RAM_TO_VRAM),y
   
not_reset_attrib
   adb charset_char_x #CHARSET_POS_X screen_pos_x
   adb charset_char_y #CHARSET_POS_Y screen_pos_y
   ldx screen_pos_x
   ldy screen_pos_y
   jsr screen_position_attrib
   
   mwa RAM_TO_VRAM charset_char_attrib_last
   
   ldy #0
   mva #$23 (RAM_TO_VRAM),y
   rts
.endp   

charset_edit_start .word 0
charset_edit_start_vram .word 0

charset_char_x .byte 0
charset_char_y .byte 0
charset_char_index .byte 0
charset_char_attrib_last .word 0

last_key .byte 0

block_chars:
	.byte 0, 0, 0, 0, 0, 0, 0, 1
	.byte 0, 0, 0, 0, 0, 0, 0, 255
	.byte 1, 1, 1, 1, 1, 1, 1, 1
	.byte 1, 1, 1, 1, 1, 1, 1, 255
	.byte 255, 255, 255, 255, 255, 255, 255 ,255


   icl '../os/stdlib.asm'
