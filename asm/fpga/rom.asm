
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

   lda #$0A
   sbc #$02 // result should be 7, flag_c = 1
   sbc #$03 // result should be 4, flag_c = 1 
   jmp demo
   
   // icl 'demos/text_mode_attrib.asm'
   icl 'demos/video_modes.asm'
   