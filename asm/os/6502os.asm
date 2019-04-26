VDLI     = $9000
VCHARSET = $9002
VPALETTE = $9004
VCOUNT   = $9007
WSYNC    = $9008
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
	
	lda #<(dl_attr - VRAM)
	sta VDLI
	lda #>(dl_attr - VRAM)
	sta VDLI+1
	
	lda #<(spectrum_palette - VRAM)
	sta VPALETTE
	lda #>(spectrum_palette - VRAM)
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
	sta screen_attr, x
	inx
	bne copy
stop:
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

dl_attr:
	.byte 112, 112, 112, 67
	.word screen_attr - vram
	.word attr - vram
	.rept 23
	.byte 3
	.endr
	.byte 112, 112, 112
	.byte 65
	.word dl_attr - vram
screen_attr:
	.rept 40*24
	.byte 0
	.endr
attr:
	.rept 40
	.byte 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17
	.endr

	org $b000
charset:
	ins '../../res/charset.bin'

   icl 'palette_atari_ntsc.asm'

   icl 'palette_spectrum.asm'
	
	