copy_block_with_params:
	ldy #5
copy_block_params:
	lda (COPY_PARAMS), y
	sta SRC_ADDR, y
	dey
	bpl copy_block_params

copy_block:
	ldy #0
copy_block_short:
	lda (SRC_ADDR), y
	sta (DST_ADDR), y
	iny
	cpy SIZE
	bne copy_block_short
	inc SRC_ADDR+1
	inc DST_ADDR+1
copy_skip_short:
	lda SIZE+1
	beq copy_block_end
	dec SIZE+1
	jmp copy_block_short
copy_block_end
	rts

mem_set_bytes:
	ldy #0
	ldx SIZE+1
	beq mem_set_bytes_short
mem_set_bytes_page:
	sta (DST_ADDR), y
	iny
	bne mem_set_bytes_page
	inc DST_ADDR+1
	dex
	bne mem_set_bytes_page

	ldx SIZE
	beq mem_set_bytes_end
mem_set_bytes_short:
	sta (DST_ADDR), y
	iny
	dex
	bne mem_set_bytes_short
mem_set_bytes_end:
	rts

; vram = (page << 8 << 6 + (addr-VRAM)) / 2 => page << 8 << 5 + (addr-VRAM)/2
; in : RAM_TO_VRAM with CPU address
;      VRAM_PAGE 16K Page in VRAM
;
; out: VRAM_TO_RAM with Chroni address (in words)

ram2vram:
   sbw RAM_TO_VRAM #VRAM
   lda RAM_TO_VRAM+1
   lsr
   sta VRAM_TO_RAM+1
   lda RAM_TO_VRAM
   ror
   sta VRAM_TO_RAM

   lda VRAM_PAGE
   asl
   asl
   asl
   asl
   asl
   ora VRAM_TO_RAM+1
   sta VRAM_TO_RAM+1
   rts

; page = (vram & 0xE000) >> 5 >> 8
; addr = (vram & 0x1FFF) * 2 + VRAM
; in: VRAM_TO_RAM with Chroni address (in words)
; out: RAM_TO_VRAM with CPU address
;      VRAM_PAGE with 16K Page in VRAM

vram2ram:
   lda VRAM_TO_RAM+1
   and #$E0
   lsr
   lsr
   lsr
   lsr
   lsr
   sta VRAM_PAGE

   adw VRAM_TO_RAM #VRAM RAM_TO_VRAM
   rts
