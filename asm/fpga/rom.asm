
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
   lda #1
   ldx #2
   ldy #3
   txa
   tya
   lda #4
   tax
   lda #5
   tay
   
   lda #0
   clc
   adc #20
   adc #20
   sec
   adc #20
   clc
   adc #200
   
   
   lda #30
   pha
   lda #40
   pla
   
   lda #$ff
   asl
   lda #$7f
   asl

   jmp demo
   
   // icl 'demos/text_mode_attrib.asm'
   icl 'demos/video_modes.asm'
   