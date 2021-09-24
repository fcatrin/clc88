	icl '../os/symbols.asm'
	
	org BOOTADDR
	
	lda #0
	ldx #OS_SET_VIDEO_MODE
	jsr OS_CALL
	
	mwa #sprites_base RAM_TO_VRAM
	jsr lib_ram_to_vram
	mwa VRAM_TO_RAM VSPRITES
	
	lda #$0F
	sta VBORDER
	
	mwa DISPLAY_START VRAM_TO_RAM
	jsr lib_vram_to_ram
	
	adw RAM_TO_VRAM #48+4
	
	ldy #0
copy:
	lda message, y
	cmp #255
	beq set_chars_full
	sta (RAM_TO_VRAM), y
	iny
	bne copy
	
set_chars_full:

	adw RAM_TO_VRAM #(48*3) R4
	
	mwa ATTRIB_START VRAM_TO_RAM
	jsr lib_vram_to_ram
	adw RAM_TO_VRAM #(48*4)+4 R6
	
	lda #$32
	sta R1
	jsr write_charset
	
	lda #$43
	sta R1
	adw R4 #(48*3)
	adw R6 #(48*3)
	
	jsr write_charset
	
end:

   mwa DLIST VRAM_TO_RAM
   jsr lib_vram_to_ram
   ldy #3
   lda (RAM_TO_VRAM), y
   ora #$30
   sta (RAM_TO_VRAM), y

   lda VSTATUS
   and #(255 - VSTATUS_EN_INTS)
   sta VSTATUS
      
   mwa #vblank VBLANK_VECTOR_USER

   lda VSTATUS
   ora #VSTATUS_EN_INTS
   sta VSTATUS

	lda VSTATUS
	ora #VSTATUS_EN_SPRITES
	sta VSTATUS
	
loop:
   lda FRAMECOUNT
   clc
   ror
   sta sprites_x
   sta sprites_y
   clc
   ror
   adc #50
   sta sprites_x+2
   sta sprites_y+2
   
   lda VCOUNT
   asl
   sta WSYNC
   sta VBORDER
   jmp loop
   
vblank:
   pha
   lda FRAMECOUNT
   and #$1
   bne no_scroll
   inc VSCROLL
   inc HSCROLL
no_scroll:   
   pla
   rts   
   
write_charset:
   ldx #0
   stx R0
set_chars_line:
   ldy #0
set_chars:   
   lda R0
   sta (R4), y
   lda R1
   sta (R6), y
   inc R0
   iny
   cpy #32
   bne set_chars
   adw R4 #48
   adw R6 #48
   inx
   cpx #4
   bne set_chars_line
   rts
   
message:
	.by "Hello world!! This is Chroni!", 255
   
   icl '../os/stdlib.asm'   

   org $C000
sprite_0:
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

sprite_1:
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

   org $C100
 sprites_base:
   .word [sprite_0 - VRAM] / 2
   .word [sprite_1 - VRAM] / 2
   
   org $C140
 sprites_x:
   .word $0019, $001E
   
   org $C180
 sprites_y:
   .word $0014, $0011
   
   org $C1C0
sprites_attr:   
   .word $0011, $0010
   
sprites_colors:   
   org $C200
   .byte $00, $06, $08, $0C, $16, $18, $1A, $1B, $26, $28, $2A, $2C, $2F, $34, $36, $38
   .byte $00, $66, $68, $6C, $76, $78, $7A, $7B, $86, $88, $8A, $8C, $8F, $94, $96, $98
   
   