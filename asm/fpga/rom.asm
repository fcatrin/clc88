
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

   lda #0
   php
   lda #$80
   php
   clc
   php
   sec
   php
   clc
   plp
   plp
   plp
   plp

halt
   jmp halt   

   jmp demo
   // icl 'demos/text_mode_attrib.asm'
   icl 'demos/video_modes.asm'
   