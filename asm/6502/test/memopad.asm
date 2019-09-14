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


key_shift:
	.byte 'shift', 0
key_ctrl:
	.byte 'ctrl', 0
key_alt:
	.byte 'alt', 0

	
   icl '../os/stdlib.asm'
