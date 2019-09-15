	icl '../os/symbols.asm'

POS_BASE = 20*40
POS_SHIFT = POS_BASE  + 2
POS_CTRL  = POS_SHIFT + 6
POS_ALT   = POS_CTRL  + 5


	org BOOTADDR

   lda #0
   ldy #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL
   
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
   jsr print_key
   
ignore_key:
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
    mwa DISPLAY_START VRAM_TO_RAM
    jsr lib_vram_to_ram

   jsr calc_screen_offset
   adw RAM_TO_VRAM pos_offset

   ldx #0
search_key:   
   lda key_conversion_normal, x
   beq end_print_key
   cmp last_key_pressed
   bne next_char
   ldy #0
   inx
   lda key_conversion_normal, x
   sta (RAM_TO_VRAM), y
   inc pos_x
   lda pos_x
   cmp #40
   bne no_line_feed
   lda #2
   sta pos_x
   inc pos_y
no_line_feed   
   rts
next_char:   
   inx
   inx
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

last_key_pressed:
   .byte 0
   
pos_x:  .byte 2
pos_y:  .byte 0
pos_offset: .word 0

key_shift:
	.byte 'shift', 0
key_ctrl:
	.byte 'ctrl', 0
key_alt:
	.byte 'alt', 0

key_conversion_normal:
   .by 19, '1',
   .by 20, '2',
   .by 21, '3',
   .by 22, '4',
   .by 23, '5',
   .by 24, '6',
   .by 25, '7',
   .by 26, '8',
   .by 27, '9',
   .by 28, '0',
	.by 0
	
   icl '../os/stdlib.asm'
