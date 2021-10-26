
COLS = 80
ROWS = 30

THIS_SCREEN_SIZE = COLS*ROWS

FONT_ROM_ADDR = $e000
BORDER_COLOR = $2167
DLIST_ADDR = $0200

text_location = $0400
attr_location = text_location + THIS_SCREEN_SIZE/2 
   
   org $f000
   
demo:   
   mwa #palette_dark SRC_ADDR
   jsr gfx_upload_palette

   mwa #BORDER_COLOR VBORDER
   
   mwa #$0000 VADDRW
   mwa #FONT_ROM_ADDR SRC_ADDR
   jsr gfx_upload_font

   mwa #dlist_addr VDLIST   
   mwa #dlist_addr VADDRW
   
   ldx #0
copy_dl:
   lda display_list, x
   sta VDATA
   inx
   bne copy_dl
   
   mwa #text_location DISPLAY_START
   mwa #attr_location ATTRIB_START
   mwa #THIS_SCREEN_SIZE SCREEN_SIZE
   lda #$01
   jsr txt_clear_screen
         
   mwa #test_string SRC_ADDR
   ldy #0
   ldx #0
print:
   lda (SRC_ADDR), y
   beq enable_chroni
   jsr txt_put_char
   iny
   bne print
   inc SRC_ADDR+1
   inx
   cpx #10
   bne print
   
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

display_list:
   .byte $42
   .word text_location 
   .word attr_location
.rept (ROWS-1)/2
   .byte $02
   .byte $02
.endr 
   .byte $02
   .byte $41

palette_dark:
   .word $2104
   .word $9C0A
   .word $BC0E
   .word $43B5

test_string:
   .byte 'This is Compy CLC-88 testing VRAM port access and attributes! '
   .byte $F0, $02
   .byte 'Now in color'
   .byte $F0, $01
   .byte ', then '
   .byte $F0, $03
   .byte 'another color '
   .byte $F0, $01
   .byte 'and back to normal... '
   .byte 'This is Compy CLC-88 testing VRAM port access and attributes! '
   .byte $F0, $02
   .byte 'Now in color'
   .byte $F0, $01
   .byte ', then '
   .byte $F0, $03
   .byte 'another color '
   .byte $F0, $01
   .byte 'and back to normal. Font by Ascrnet.', 0
   
   icl '../graphics.asm'
   icl '../text.asm'
   icl '../stdlib.asm'
   
   // org FONT_ROM_ADDR
   // ins '../../../res/fonts/charset_atari.bin'
   