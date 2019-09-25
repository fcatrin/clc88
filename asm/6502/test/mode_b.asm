	icl '../os/symbols.asm'
	
	org BOOTADDR

   lda #0
   sta ROS7
   lda #$0B
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL

   mwa VRAM_FREE VTILESET_BIG

   mwa VRAM_FREE VRAM_TO_RAM
   jsr lib_vram_to_ram

   adw RAM_TO_VRAM #128

   ldy #0
copy_tile:
   lda tile, y
   sta (RAM_TO_VRAM), y
   iny
   cpy #128
   bne copy_tile


   mwa DISPLAY_START VRAM_TO_RAM
   jsr lib_vram_to_ram
	
	ldy #0
copy:
	lda message, y
	cmp #255
	beq stop
	sta (RAM_TO_VRAM), y
	iny
	bne copy

stop:
	jmp stop
	
message:
	.byte 0, 1, 1, 0, 1, 255

tile:
   .byte $13, $00, $00, $07, $70, $00, $00, $21
   .byte $21, $30, $00, $07, $70, $00, $02, $13
   .byte $02, $13, $00, $07, $70, $00, $21, $30
   .byte $00, $21, $30, $07, $70, $02, $13, $00
   .byte $00, $02, $13, $07, $70, $21, $30, $00
   .byte $00, $00, $21, $37, $72, $13, $00, $00
   .byte $44, $40, $02, $13, $21, $30, $04, $44
   .byte $55, $50, $00, $21, $13, $00, $05, $55
   .byte $44, $40, $00, $31, $12, $00, $04, $44
   .byte $00, $00, $03, $12, $31, $20, $00, $00
   .byte $00, $00, $31, $26, $63, $12, $00, $00
   .byte $00, $03, $12, $06, $60, $31, $20, $00
   .byte $00, $31, $20, $06, $60, $03, $12, $00
   .byte $03, $12, $00, $06, $60, $00, $31, $20
   .byte $31, $20, $00, $06, $60, $00, $03, $12
   .byte $12, $00, $00, $06, $60, $00, $00, $31
   

   icl '../os/stdlib.asm'
