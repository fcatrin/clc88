	icl 'symbols.asm'

CHARSET_SIZE  = $0400
PALETTE_SIZE  = $0200

VRAM_CHARSET   = VRAM
VRAM_PAL_ATARI = VRAM + CHARSET_SIZE
VRAM_PAL_ZX    = VRAM_PAL_ATARI + PALETTE_SIZE

VRAM_SCREEN    = VRAM_PAL_ZX + PALETTE_SIZE

TEXT_SCREEN_SIZE = 40*24
TEXT_SCREEN_DLIST_SIZE = 32


	org $FFFC

	.word boot

	org OS_CALL
	
	pha
	txa
	asl
	tax
	lda OS_VECTORS, x
	sta OS_VECTOR
	lda OS_VECTORS+1,x
	sta OS_VECTOR+1
	pla
	jmp (OS_VECTOR)
	
boot:
	lda #<copy_params_vectors
	sta COPY_PARAMS
	lda #>copy_params_vectors
	sta COPY_PARAMS+1
	jsr copy_block_with_params
	
	lda #<copy_params_charset
	sta COPY_PARAMS
	lda #>copy_params_charset
	sta COPY_PARAMS+1
	jsr copy_block_with_params
	
	lda #<copy_params_pal_atari
	sta COPY_PARAMS
	lda #>copy_params_pal_atari
	sta COPY_PARAMS+1
	jsr copy_block_with_params
	
	lda #<copy_params_pal_spectrum
	sta COPY_PARAMS
	lda #>copy_params_pal_spectrum
	sta COPY_PARAMS+1
	jsr copy_block_with_params
	
	lda #<(VRAM_CHARSET - VRAM)
	sta VCHARSET
	lda #>(VRAM_CHARSET - VRAM)
	sta VCHARSET+1
	
	lda #$ff
	jsr set_video_mode

	lda #0
	sta VCOLOR0
	lda #$94
	sta VCOLOR1
	lda #$9A
	sta VCOLOR2
	
	jmp BOOTADDR

set_video_mode:
	cmp #$00
	beq set_video_mode_0
	cmp #$01
	beq set_video_mode_1
	cmp #$ff
	beq set_video_mode_off
	rts
	
set_video_mode_off:
	ldx #0
	lda #112
create_dl_mode_off:	
	sta VRAM_SCREEN, x
	inx
	cpx #24
	bne create_dl_mode_off
	lda #$41
	sta VRAM_SCREEN, x
	
	jmp set_video_mode_dl
	
set_video_mode_0:
	ldy #2
	jsr set_video_mode_text
	jsr clear_text_screen
	lda #<(VRAM_PAL_ATARI - VRAM)
	sta VPALETTE
	lda #>(VRAM_PAL_ATARI - VRAM)
	sta VPALETTE+1
	rts

set_video_mode_1:
	ldy #3
	jsr set_video_mode_text
	jsr clear_text_screen
	
	clc
	lda TEXT_START
	adc #<TEXT_SCREEN_SIZE
	sta COPY_DST_ADDR
	sta ATTRIB_START
	lda TEXT_START+1
	adc #>TEXT_SCREEN_SIZE
	sta COPY_DST_ADDR+1
	sta ATTRIB_START+1
	
	lda #<TEXT_SCREEN_SIZE
	sta COPY_SIZE
	lda #>TEXT_SCREEN_SIZE
	sta COPY_SIZE+1
	
	lda #$F2
	jsr mem_set_bytes
	
clear_text_screen:
	lda #<TEXT_SCREEN_SIZE
	sta COPY_SIZE
	lda #>TEXT_SCREEN_SIZE
	sta COPY_SIZE+1
	
	lda TEXT_START
	sta COPY_DST_ADDR
	lda TEXT_START+1
	sta COPY_DST_ADDR+1
	
	lda #1
	jmp mem_set_bytes

set_video_mode_text:
	lda #112
	sta VRAM_SCREEN
	sta VRAM_SCREEN+1
	sta VRAM_SCREEN+2
	tya
	ora #$40
	sta VRAM_SCREEN+3
	lda #<(VRAM_SCREEN + TEXT_SCREEN_DLIST_SIZE)
	sta TEXT_START
	lda #<(VRAM_SCREEN + TEXT_SCREEN_DLIST_SIZE - VRAM)
	sta VRAM_SCREEN+4
	lda #>(VRAM_SCREEN + TEXT_SCREEN_DLIST_SIZE)
	sta TEXT_START+1
	lda #>(VRAM_SCREEN + TEXT_SCREEN_DLIST_SIZE - VRAM)
	sta VRAM_SCREEN+5
	ldx #0
	tya
create_dl_mode_0:	
	sta VRAM_SCREEN+6, x
	inx
	cpx #23
	bne create_dl_mode_0
	lda #$41
	sta VRAM_SCREEN+6, x
	jmp set_video_mode_dl
	
set_video_mode_dl:
	lda #<(VRAM_SCREEN - VRAM)
	sta VDLIST
	lda #>(VRAM_SCREEN - VRAM)
	sta VDLIST+1
	rts

os_vector_table
	.word set_video_mode
	.word copy_block
	.word copy_block_with_params
	.word mem_set_bytes

copy_params_vectors:
	.word os_vector_table, OS_VECTORS, 4*2

copy_params_charset:
	.word charset, VRAM_CHARSET, CHARSET_SIZE
copy_params_pal_atari:
	.word atari_palette_ntsc, VRAM_PAL_ATARI, PALETTE_SIZE
copy_params_pal_spectrum:
	.word spectrum_palette,   VRAM_PAL_ZX, PALETTE_SIZE

copy_block_with_params:
	ldy #5
copy_block_params:
	lda (COPY_PARAMS), y
	sta COPY_SRC_ADDR, y
	dey
	bpl copy_block_params

copy_block:
	ldy #0
copy_block_short:
	lda (COPY_SRC_ADDR), y
	sta (COPY_DST_ADDR), y
	iny
	cpy COPY_SIZE
	bne copy_block_short
	inc COPY_SRC_ADDR+1
	inc COPY_DST_ADDR+1
copy_skip_short:
	lda COPY_SIZE+1
	beq copy_block_end
	dec COPY_SIZE+1
	jmp copy_block_short
copy_block_end
	rts

mem_set_bytes:
	ldy #0
	ldx COPY_SIZE+1
	beq mem_set_bytes_short
mem_set_bytes_page:
	sta (COPY_DST_ADDR), y
	iny
	bne mem_set_bytes_page
	inc COPY_DST_ADDR+1
	dex
	bne mem_set_bytes_page

	ldx COPY_SIZE
	beq mem_set_bytes_end
mem_set_bytes_short:
	sta (COPY_DST_ADDR), y
	iny
	dex
	bne mem_set_bytes_short
mem_set_bytes_end:
	rts


charset:
	ins '../../res/charset.bin'
	icl 'palette_atari_ntsc.asm'
	icl 'palette_spectrum.asm'
	
