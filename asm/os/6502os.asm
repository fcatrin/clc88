VDLI     = $9000
VCHARSET = $9002
VPALETTE = $9004
VCOUNT   = $9007
VCOLOR0  = $9010
VCOLOR1  = $9011
VCOLOR2  = $9012

VRAM     = $A000

	org $FFFC

	.word boot

	org $F000
boot:
	lda #<(charset - VRAM)
	sta VCHARSET
	lda #>(charset - VRAM)
	sta VCHARSET+1
	
	lda #<(dli - VRAM)
	sta VDLI
	lda #>(dli - VRAM)
	sta VDLI+1
	
	lda #<(palette - VRAM)
	sta VPALETTE
	lda #>(palette - VRAM)
	sta VPALETTE+1
	
	lda #0
	sta VCOLOR0
	lda #$94
	sta VCOLOR1
	lda #$9A
	sta VCOLOR2
	
	ldx #0
copy:
	lda message, x
	cmp #255
	beq stop
	sta screen, x
	inx
	bne copy
	ldy #0
stop:
	lda VCOUNT
	clc
	adc #16
	sta VCOLOR0
	iny
	sty VCOLOR1
	jmp stop
	
message:
	.byte 40, 101, 108, 108, 111, 0, 55, 111, 114, 108, 100, 1, 1, 1, 1, 255

	org $a000
	
dli: 
	.byte 112, 112, 112, 66
	.word screen - vram
	.rept 23
	.byte 2
	.endr
	.byte 112, 112, 112
	.byte 65
	.word dli - vram
screen:
	.rept 40*24
	.byte 0
	.endr

	org $a400
charset:
	ins '../../res/charset.bin'

palette:
   icl 'palette_atari_ntsc.asm'
	
	