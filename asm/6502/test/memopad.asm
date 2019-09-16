   icl '../os/symbols.asm'

POS_BASE = 22*40+11
POS_SHIFT = POS_BASE 
POS_CTRL  = POS_SHIFT + 7
POS_ALT   = POS_CTRL  + 6


	org BOOTADDR

   lda #0
   ldy #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL
   
   jsr calc_screen_offset
   
next_frame:
	lda FRAMECOUNT
wait:
   cmp FRAMECOUNT
   beq wait

   ldx #OS_KEYB_POLL
   jsr OS_CALL
   
   lda KEY_PRESSED
   cmp last_key_pressed
   beq ignore_key
   sta last_key_pressed
   jsr cursor_off
   jsr print_key
   
ignore_key:
   jsr cursor_on
	jsr keybprint
	jmp next_frame
	
keybprint:
   lda #$FF
   sta R5
	lda KEY_META
	and #KEY_META_SHIFT
	beq no_shift
	lda #$DF
	sta R5
no_shift:
	jsr print_shift
   lda #$FF
   sta R5
	lda KEY_META
	and #KEY_META_CTRL
	beq no_ctrl
	lda #$DF
	sta R5
no_ctrl:
	jsr print_ctrl
   lda #$FF
   sta R5
	lda KEY_META
	and #KEY_META_ALT
	beq no_alt
	lda #$DF
	sta R5
no_alt:
	jmp print_alt
	

print_shift:
	mwa #key_shift R1
	mwa #POS_SHIFT R3
	jmp print

print_ctrl:
	mwa #key_ctrl R1
	mwa #POS_CTRL R3
	jmp print

print_alt:
	mwa #key_alt R1
	mwa #POS_alt R3
	jmp print

print:
   mwa DISPLAY_START VRAM_TO_RAM
   jsr lib_vram_to_ram
	adw RAM_TO_VRAM R3

	ldy #0
print_c:
	lda (R1), y
	beq end_print
	and R5
	sta (RAM_TO_VRAM), y
	iny
	bne print_c
end_print:
	rts

print_key:
   lda last_key_pressed
   
   cmp #46
   jeq line_feed
   cmp #14
   jeq cursor_left
   cmp #15
   jeq cursor_right
   cmp #16
   jeq cursor_up
   cmp #17
   jeq cursor_down
   cmp #32
   jeq backspace

   mwa DISPLAY_START VRAM_TO_RAM
   jsr lib_vram_to_ram

   jsr calc_screen_offset
   adw RAM_TO_VRAM pos_offset

   mwa #key_conversion_shift R1
   lda KEY_META
   and #KEY_META_SHIFT
   bne search_key_start
   
   MWA #key_conversion_alt R1
   lda KEY_META
   and #KEY_META_ALT
   bne search_key_start
   
   MWA #key_conversion_normal R1
   
search_key_start:
   ldy #0
search_key:   
   lda (R1), y
   beq end_print_key
   cmp last_key_pressed
   bne next_char
   iny
   lda (R1), y
   ldy #0
   sta (RAM_TO_VRAM), y
   inc pos_x
   lda pos_x
   cmp #40
   jeq line_feed
   rts
next_char:   
   iny
   iny
   bne search_key
end_print_key:
   rts   

calc_screen_offset:
   mwa #0 pos_offset
     
   // pos_offset = y*32
   lda pos_y
   asl
   rol pos_offset+1
   asl
   rol pos_offset+1
   asl
   rol pos_offset+1
   asl
   rol pos_offset+1
   asl
   rol pos_offset +1
   sta pos_offset
   
   // pos_offset += y*8   => pos_offset = y*40
   lda pos_y
   asl
   asl
   asl
   clc
   adc pos_offset
   sta pos_offset
   lda #0
   adc pos_offset+1
   sta pos_offset+1

   // add x
   clc
   lda pos_x
   adc pos_offset
   sta pos_offset
   lda #0
   adc pos_offset+1
   sta pos_offset+1
   rts

backspace:
   lda pos_x
   cmp #0
   beq backspace_wrap_left
   dec pos_x
   jmp backspace_del
backspace_wrap_left:
   lda pos_y
   cmp #0
   beq backspace_abort
   lda #39
   sta pos_x
   dec pos_y
backspace_del:
   mwa DISPLAY_START VRAM_TO_RAM
   jsr lib_vram_to_ram

   jsr calc_screen_offset
   adw RAM_TO_VRAM pos_offset
   lda #' '
   ldy #0
   sta (RAM_TO_VRAM), y
backspace_abort:   
   rts
   
line_feed:
   lda pos_y
   cmp #24
   beq line_feed_end
   lda #0
   sta pos_x
   inc pos_y
line_feed_end
   rts   

cursor_left:
   lda pos_x
   cmp #0
   beq cursor_wrap_left
   dec pos_x
   jmp calc_screen_offset
cursor_wrap_left:   
   lda #39
   sta pos_x
   jmp calc_screen_offset
   
cursor_right:
   lda pos_x
   cmp #39
   beq cursor_wrap_right
   inc pos_x
   jmp calc_screen_offset
cursor_wrap_right:   
   lda #0
   sta pos_x
   jmp calc_screen_offset

cursor_up:
   lda pos_y
   cmp #0
   beq cursor_wrap_up
   dec pos_y
   jmp calc_screen_offset
cursor_wrap_up:   
   lda #20
   sta pos_y
   jmp calc_screen_offset

cursor_down:
   lda pos_y
   cmp #20
   beq cursor_wrap_down
   inc pos_y
   jmp calc_screen_offset
cursor_wrap_down:   
   lda #0
   sta pos_y
   jmp calc_screen_offset

cursor_on:
   lda #1
   sta is_cursor_on
   lda #$01
   jmp change_cursor_attr

cursor_off:
   lda #0
   sta is_cursor_on
   
   lda #$10
   
change_cursor_attr:
      
   pha
   mwa ATTRIB_START VRAM_TO_RAM
   jsr lib_vram_to_ram

   jsr calc_screen_offset
   adw RAM_TO_VRAM pos_offset
   pla
   ldy #0
   sta (RAM_TO_VRAM), y
   rts
   


last_key_pressed:
   .byte 0
   
is_cursor_on: .byte 0
   
pos_x:  .byte 0
pos_y:  .byte 0
pos_offset: .word 0

key_shift:
	.byte 'shift', 0
key_ctrl:
	.byte 'ctrl', 0
key_alt:
	.byte 'alt', 0

   icl '../os/keyboard.asm'
   icl '../os/stdlib.asm'
