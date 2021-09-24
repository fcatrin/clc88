
   icl 'symbols.asm'
   
	org $FFFA

	.word nmi
	.word boot
	.word irq

   
BG_COLOR = $29AC   
FG_COLOR = $F75B
BORDER_COLOR = $2167
   
   org $f800
nmi:
	rti
irq:
	rti   
boot:
   lda #0
   sta VCHARSET

   sta VPAL_INDEX
   ldx #0
set_palette:   
   lda palette_dark, x
   STA VPAL_VALUE
   inx
   bne set_palette

   mwa #BORDER_COLOR VBORDER
   
// copy 16*256 bytes from $e000 to VRAM $00000

   mwa #$0000 VADDR
   mwa #$e000 SRC_ADDR
   
   ldx #0
   ldy #0
copy:   
   lda (SRC_ADDR), y
   sta VDATA
   iny
   bne copy
   inc SRC_ADDR+1
   inx
   cpx #16
   bne copy

   ldx #0
load5:
   lda display_list, x
   sta dlist_in_ram, x
   inx
   bne load5
   
dlist_addr    = $1d00
dlist_in_vram = dlist_addr / 2
dlist_in_ram  = dlist_addr + $a000

   mwa #dlist_in_vram VDLIST
   
   mwa #text_location DISPLAY_START
   mwa #attr_location ATTRIB_START
   lda #$01
   jsr clear_screen
         
   mwa #test_string SRC_ADDR
   ldy #0
   ldx #0
load6:
   lda (SRC_ADDR), y
   beq enable_chroni
   jsr put_char
   iny
   bne load6
   inc SRC_ADDR+1
   inx
   cpx #10
   bne load6
   
enable_chroni:
   
   lda VSTATUS
   ora #VSTATUS_ENABLE
   sta VSTATUS
   
main_loop:   
   lda #0
   sta R0
wait_press:
   lda BUTTONS
   beq wait_press
   
   inc R0
   lda R0
   cmp #4
   bne not_wrap
   lda #0
   sta R0
not_wrap:
   sta VCHARSET
wait_release:   
   lda BUTTONS
   bne wait_release   
   jmp wait_press

text_location = $1e00
attr_location = text_location + 80*30 

display_list:
   .byte $42
   .word text_location 
   .byte 0
   .word attr_location
   .byte 0
.rept 29 
   .byte 02
.endr 
   .byte $41

palette_dark:
   .word $2104
   .word $9C0A
   .word $BC0E
   .word $43B5

test_string:
   .byte 'This is Compy CLC-88 testing VRAM port access and attributes! '
   .byte $F0, $02
   .byte 'Now in color '
   .byte $F0, $01
   .byte 'and '
   .byte $F0, $03
   .byte 'another color', 0
   
   icl 'screen.asm'
   