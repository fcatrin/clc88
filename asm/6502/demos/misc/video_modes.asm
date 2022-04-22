   icl '../../os/include/symbols.asm'

BORDER_COLOR = $2167
   
   org USERADDR
   
demo:

   lda #0
   jsr gfx_set_video_mode
      
   mwa #palette_dark SRC_ADDR
   jsr gfx_upload_palette

   mwa #BORDER_COLOR VBORDER

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
   .byte 'and back to normal', 0
   
   icl '../../os/graphics.asm'
   icl '../../os/ram_vram.asm'
   icl '../../os/text.asm'
   icl '../../os/libs/stdlib.asm'
   
    org EXECADDR
    .word demo