	icl '../os/symbols.asm'
	
	org BOOTADDR
	
	lda #1
	ldx #OS_SET_VIDEO_MODE
	jsr OS_CALL
	
	mwa #sprites_base RAM_TO_VRAM
	jsr lib_ram_to_vram
	mwa VRAM_TO_RAM VSPRITES
	
	lda #$0F
	sta VBORDER
	
	adw DISPLAY_START #22 VADDRW
	
	ldy #0
copy:
	lda message, y
	cmp #255
	beq set_chars_full
	sta VDATA
	iny
	bne copy
	
set_chars_full:

	adw DISPLAY_START #(20*4)+2 VADDRW
	adw ATTRIB_START  #(20*4)+2 VADDRW_AUX
	
	lda #$2F
	sta R1
	jsr write_charset
	
	lda #$F2
	sta R1
   adw DISPLAY_START #(20*10)+2 VADDRW
   adw ATTRIB_START  #(20*10)+2 VADDRW_AUX
	
	jsr write_charset
	
end:
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
   
write_charset:
   mwa VADDRW R4
   mwa VADDRW_AUX R6
   ldx #0
   stx R0
set_chars_line:
   ldy #0
set_chars:   
   lda R0
   sta VDATA
   lda R1
   sta VDATA_AUX
   inc R0
   iny
   cpy #32
   bne set_chars
   adw R4 #20
   adw R6 #20
   mwa R4 VADDRW
   mwa R6 VADDRW_AUX
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
   
   