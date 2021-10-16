
   icl 'symbols.asm'
   
CHARSET_SIZE      = $0400
VRAM_ADDR_CHARSET = 0
VRAM_ADDR_SCREEN  = VRAM_ADDR_CHARSET + CHARSET_SIZE

	org $FFFA

	.word nmi
	.word boot
	.word irq
   
   org $ff80
nmi:
	rti
irq:
	rti   
boot:

   lda #$aa
   sta $20
   lda #2
   bit $20  ; z = 0, n = 1, v = 0

   lda #$55
   bit $20  ; z = 1, n = 1, v = 0

   lda #$f0
   sta $20
   lda #1
   bit $20  ; z = 1, n = 1, v = 1


halt:   
   jmp halt

   jmp demo
   // icl 'demos/text_mode_attrib.asm'
   icl 'demos/video_modes.asm'
   