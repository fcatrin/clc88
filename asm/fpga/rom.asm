
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

   lda #$7F
   adc #$02  // result should be $81
   adc #$8A  // result should be $0B, flag_c = 1
   adc #$01  // result should be $0D
   adc #$23  // result should be $30, flag_c = 0, flag_v = 0
   adc #$70  // result should be $A0, flag_c = 0, flag_v = 1
   jmp demo
   
   // icl 'demos/text_mode_attrib.asm'
   icl 'demos/video_modes.asm'
   