	icl 'symbols.asm'

CHARSET_SIZE  = $0400
PALETTE_SIZE  = $0200

VRAM_CHARSET   = VRAM
VRAM_PAL_ATARI = VRAM + CHARSET_SIZE
VRAM_PAL_ZX    = VRAM_PAL_ATARI + PALETTE_SIZE

VRAM_SCREEN    = VRAM_PAL_ZX + PALETTE_SIZE

TEXT_SCREEN_SIZE       = 40*24
TEXT_SCREEN_SIZE_WIDE  = 20*24
TEXT_SCREEN_SIZE_BLOCK = 20*12
TEXT_SCREEN_DLIST_SIZE = 32


	org $FFFA

   .word nmi
	.word boot
	.word irq

	org OS_CALL
	
	pha
	txa
	asl
	tax
	lda os_vector_table, x
	sta OS_VECTOR
	lda os_vector_table+1,x
	sta OS_VECTOR+1
	pla
	jmp (OS_VECTOR)
	
boot:
   lda #0
   sta VSTATUS
   sta CHRONI_ENABLED

; init interrupt vectors
   
   ldx #0
copy_vector:
   lda interrupt_vectors, x
   sta NMI_VECTOR, x
   inx
   cpx #$08
   bne copy_vector
	
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
	
	lda #<VRAM_CHARSET
	sta VRCHARSET
	lda #>VRAM_CHARSET
	sta VRCHARSET+1
	
	lda #$ff
	jsr set_video_mode

	lda #0
	sta VCOLOR0
	lda #$94
	sta VCOLOR1
	lda #$9A
	sta VCOLOR2
	
	lda #1
	sta CHRONI_ENABLED
	lda VSTATUS
	ora #VSTATUS_EN_INTS
	sta VSTATUS
	
	jmp BOOTADDR

interrupt_vectors:
   .word nmi_os
   .word irq_os
   .word vblank_os
   .word hblank_os

nmi_os:
   cld
   pha
   lda VSTATUS
   ror
   bcc nmi_check_hblank
   pla
   jmp (VBLANK_VECTOR)
nmi_check_hblank:
   ror
   bcc nmi_done
   pla
   jmp (HBLANK_VECTOR)
nmi_done:
   pla
   rti

irq_os:
   rti

hblank_os:
   rti

vblank_os:
   pha
   lda FRAMECOUNT
   adc #1
   sta FRAMECOUNT
   lda FRAMECOUNT+1
   adc #0
   sta FRAMECOUNT+1
   
   lda CHRONI_ENABLED
   beq set_chroni_disabled
   lda VSTATUS
   ora #VSTATUS_ENABLE
   sta VSTATUS
   bne chroni_enabled_set
set_chroni_disabled:
   lda VSTATUS
   and #($FF - VSTATUS_ENABLE)
   sta VSTATUS
chroni_enabled_set:   
   
   pla
   rti   
    
set_video_mode:
   pha
   lda #0
   sta CHRONI_ENABLED
   lda VSTATUS
   and #($ff - VSTATUS_ENABLE)
   sta VSTATUS
   pla
	cmp #$00
	beq set_video_mode_0
	cmp #$01
	beq set_video_mode_1
	cmp #$02
	beq set_video_mode_2
	cmp #$03
	beq set_video_mode_3
   cmp #$04
   bne not_video_mode_4
   jmp set_video_mode_4
not_video_mode_4:   
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

	lda #<TEXT_SCREEN_SIZE
	sta COPY_SIZE
	lda #>TEXT_SCREEN_SIZE
	sta COPY_SIZE+1
	jsr clear_text_screen
	
	lda #<VRAM_PAL_ATARI
	sta VRPALETTE
	lda #>VRAM_PAL_ATARI
	sta VRPALETTE+1
	rts

set_video_mode_1:
	ldy #3
	jsr set_video_mode_text

	lda #<TEXT_SCREEN_SIZE
	sta COPY_SIZE
	lda #>TEXT_SCREEN_SIZE
	sta COPY_SIZE+1
	
	jsr clear_text_screen
	jsr init_attributes

	lda #<VRAM_PAL_ZX
	sta VRPALETTE
	lda #>VRAM_PAL_ZX
	sta VRPALETTE+1
	rts

set_video_mode_2:
	ldy #4
	jsr set_video_mode_text

	lda #<TEXT_SCREEN_SIZE_WIDE
	sta COPY_SIZE
	lda #>TEXT_SCREEN_SIZE_WIDE
	sta COPY_SIZE+1
	
	jsr clear_text_screen
	jsr init_attributes

	lda #<VRAM_PAL_ZX
	sta VRPALETTE
	lda #>VRAM_PAL_ZX
	sta VRPALETTE+1
	rts

set_video_mode_3:
	ldy #5
	jsr set_video_mode_text

	lda #<TEXT_SCREEN_SIZE_BLOCK
	sta COPY_SIZE
	lda #>TEXT_SCREEN_SIZE_BLOCK
	sta COPY_SIZE+1
	
	jsr clear_text_screen
	jsr init_attributes

	lda #<VRAM_PAL_ZX
	sta VRPALETTE
	lda #>VRAM_PAL_ZX
	sta VRPALETTE+1
	rts

clear_text_screen:
	lda TEXT_START
	sta COPY_DST_ADDR
	lda TEXT_START+1
	sta COPY_DST_ADDR+1
	
	lda #0
	jmp mem_set_bytes

init_attributes:
	clc
	lda TEXT_START
	adc COPY_SIZE
	sta COPY_DST_ADDR
	sta ATTRIB_START
	
	lda TEXT_START+1
	adc COPY_SIZE+1
	sta COPY_DST_ADDR+1
	sta ATTRIB_START+1
	
	lda #$F3
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
	lda #<((VRAM_SCREEN + TEXT_SCREEN_DLIST_SIZE - VRAM) / 2)
	sta VRAM_SCREEN+4
	lda #>(VRAM_SCREEN + TEXT_SCREEN_DLIST_SIZE)
	sta TEXT_START+1
	lda #>((VRAM_SCREEN + TEXT_SCREEN_DLIST_SIZE - VRAM) / 2)
	sta VRAM_SCREEN+5
	
	cpy #3
	beq with_attributes
	cpy #4
	beq with_attributes_wide
	cpy #5
	beq with_attributes_block

	ldx #0
	tya
create_dl_mode_0:	
	sta VRAM_SCREEN+6, x
	inx
	cpx #23
	bne create_dl_mode_0
	lda #$41
	sta VRAM_SCREEN+6, x
	ldx #23
	jmp set_video_mode_dl
	
with_attributes:
	clc
	lda VRAM_SCREEN+4
	adc #<(TEXT_SCREEN_SIZE / 2)
	sta VRAM_SCREEN+6
	lda VRAM_SCREEN+5
	adc #>(TEXT_SCREEN_SIZE / 2)
	sta VRAM_SCREEN+7
	ldx #23
	jmp create_dl_attributes
	
with_attributes_wide:
	clc
	lda VRAM_SCREEN+4
	adc #<(TEXT_SCREEN_SIZE_WIDE / 2)
	sta VRAM_SCREEN+6
	lda VRAM_SCREEN+5
	adc #>(TEXT_SCREEN_SIZE_WIDE / 2)
	sta VRAM_SCREEN+7
	ldx #23
	jmp create_dl_attributes

with_attributes_block:
	clc
	lda VRAM_SCREEN+4
	adc #<(TEXT_SCREEN_SIZE_BLOCK / 2)
	sta VRAM_SCREEN+6
	lda VRAM_SCREEN+5
	adc #>(TEXT_SCREEN_SIZE_BLOCK / 2)
	sta VRAM_SCREEN+7
	ldx #11
	jmp create_dl_attributes

create_dl_attributes:
	lda #$41
	sta VRAM_SCREEN+8, x
	dex
	tya
create_dl_mode_1:	
	sta VRAM_SCREEN+8, x
	dex
	bpl create_dl_mode_1
	jmp set_video_mode_dl
	
	
set_video_mode_dl:
	lda #<VRAM_SCREEN
	sta VRDLIST
	sta DLIST
	lda #>VRAM_SCREEN
	sta VRDLIST+1
	STA DLIST+1
	
	lda #1
   sta CHRONI_ENABLED
	rts

os_vector_table
	.word set_video_mode
	.word copy_block
	.word copy_block_with_params
	.word mem_set_bytes
	.word ram2vram
	.word vram2ram

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


nmi:
   jmp (NMI_VECTOR)
irq:
   jmp (IRQ_VECTOR)

   icl 'graphics.asm'
   
charset:
	ins '../../res/charset.bin'
	icl 'palette_atari_ntsc.asm'
	icl 'palette_spectrum.asm'
	
