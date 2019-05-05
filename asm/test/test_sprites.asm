	icl '../os/symbols.asm'
	
	org BOOTADDR
	
	lda #0
	ldx #OS_SET_VIDEO_MODE
	jsr OS_CALL
	
	lda #<(sprites - VRAM)
	sta VSPRITES
	lda #>(sprites - VRAM)
	sta VSPRITES+1
	
	lda #$0F
	sta VCOLOR0
	
end:
   jmp end	
	


   org $C000
sprites:
   
   .byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
   .byte $F0, $00, $00, $00, $00, $00, $00, $0F
   .byte $0F, $00, $11, $22, $22, $11, $00, $F0
   .byte $00, $F0, $00, $11, $11, $00, $0F, $00
   .byte $00, $0F, $00, $22, $22, $00, $F0, $00
   .byte $11, $22, $23, $33, $33, $32, $22, $11
   .byte $11, $22, $23, $33, $33, $32, $22, $11
   .byte $11, $22, $23, $33, $33, $32, $22, $11
   .byte $44, $45, $55, $56, $66, $00, $00, $00
   .byte $44, $45, $55, $56, $66, $00, $00, $00
   .byte $77, $78, $88, $89, $99, $90, $00, $00
   .byte $77, $78, $88, $89, $99, $90, $00, $00
   .byte $00, $F0, $00, $11, $11, $00, $0F, $00
   .byte $0F, $00, $11, $22, $22, $11, $00, $F0
   .byte $F0, $00, $00, $00, $00, $00, $00, $0F
   .byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF

   .byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
   .byte $FF, $AA, $AA, $BB, $BB, $AA, $AA, $FF
   .byte $FF, $AA, $AA, $BB, $BB, $AA, $AA, $FF
   .byte $FF, $AA, $AA, $BB, $BB, $AA, $AA, $FF
   .byte $FF, $AA, $AA, $BB, $BB, $AA, $AA, $FF
   .byte $FF, $AA, $AA, $BB, $BB, $AA, $AA, $FF
   .byte $FF, $AA, $AA, $BB, $BB, $AA, $AA, $FF
   .byte $FF, $AA, $AA, $BB, $BB, $AA, $AA, $FF
   .byte $FF, $AA, $AA, $BB, $BB, $AA, $AA, $FF
   .byte $FF, $AA, $AA, $BB, $BB, $AA, $AA, $FF
   .byte $FF, $AA, $AA, $BB, $BB, $AA, $AA, $FF
   .byte $FF, $AA, $AA, $BB, $BB, $AA, $AA, $FF
   .byte $FF, $AA, $AA, $BB, $BB, $AA, $AA, $FF
   .byte $FF, $AA, $AA, $BB, $BB, $AA, $AA, $FF
   .byte $FF, $AA, $AA, $BB, $BB, $AA, $AA, $FF
   .byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
   
   org $D000
   .word $0019, $001E
   
   org $D040
   .word $0011, $0011
   
   org $D080
   .word $0011, $0010
   
   org $D0C0
   .byte $00, $06, $08, $0C, $16, $18, $1A, $1B, $26, $28, $2A, $2C, $2F, $34, $36, $38
   .byte $00, $66, $68, $6C, $76, $78, $7A, $7B, $86, $88, $8A, $8C, $8F, $94, $96, $98
   
   