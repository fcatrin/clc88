	icl '../../os/include/symbols.asm'

	org USERADDR

start:
    lda #0
    ldx #OS_SET_VIDEO_MODE
    jsr OS_CALL

    jsr text_test

    lda VSTATUS
    and #(255 - VSTATUS_EN_INTS)
    sta VSTATUS

    mwa #vblank VBLANK_VECTOR_USER
    mwa #dli    HBLANK_VECTOR_USER

    lda #1
    sta VLINEINT

    lda VSTATUS
    ora #VSTATUS_EN_INTS
    sta VSTATUS

rainbow:
    clc
	lda VCOUNT
	adc FRAMECOUNT
	sta WSYNC
	sta VBORDER
	jmp rainbow
	
dli:
   pha
   lda #$66
   ; sta WSYNC
   ; sta VBORDER
   pla
   rts

vblank:
   pha
   lda #$BF
   ; sta VBORDER
   pla
   rts

    icl '../../test/include/text_test.asm'
    icl '../../os/graphics.asm'
    icl '../../os/ram_vram.asm'
    icl '../../os/text.asm'
    icl '../../os/libs/stdlib.asm'

    org EXECADDR
    .word start