
   icl 'symbols.asm'
   
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
   jmp demo
   
   icl 'demos/text_mode_attrib.asm'
   