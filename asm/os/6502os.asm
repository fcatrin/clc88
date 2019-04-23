VCHARSET = $D000
VDLI     = $D002
VPALETTE = $D004
VCOLOR0  = $D010
VCOLOR1  = $D011
VCOLOR2  = $D012

	org $FFFC

	jmp boot

	org $F000
boot:
	lda #<charset
	sta VCHARSET
	lda #>charset
	sta VCHARSET+1
	
	lda #<dli
	sta VDLI
	lda #>dli
	sta VDLI+1
	
	lda #<palette
	sta VPALETTE
	lda #>palette
	sta VPALETTE+1
	
	lda #0
	sta VCOLOR0
	lda #1
	sta VCOLOR1
	lda #2
	sta VCOLOR2
	
	lda #65
	sta screen
	lda #66
	sta screen+1
stop:
	jmp stop

	org $a000
	
dli: 
	.byte 112, 112, 112, 66
	.word screen
	.byte 2, 2, 2, 2, 2, 2, 2
	.byte 2, 2, 2, 2, 2, 2, 2
	.byte 112
	.byte 65
	.word dli
screen:
	.rept 40*24
	.byte 0
	.endr

charset:
	ins '../../res/charset.bin'
palette:
	.byte 0, 0, 0
	.byte 0xa0, 0xa0, 0xff
	.byte 0xff, 0xff, 0xff
	
	