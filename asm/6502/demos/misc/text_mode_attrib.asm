   icl '../../os/include/symbols.asm'

COLS = 80
ROWS = 30

THIS_SCREEN_SIZE = COLS*ROWS

BORDER_COLOR = $2167
DLIST_ADDR = $0200

text_location = $0400
attr_location = text_location + THIS_SCREEN_SIZE/2 
   
   org USERADDR
   
start:   
   mwa #BORDER_COLOR VBORDER

   mwa #dlist_addr VDLIST   
   mwa #dlist_addr VADDR
   
   ldx #0
copy_dl:
   lda display_list, x
   sta VDATA
   inx
   bne copy_dl
   
    mwa #text_location DISPLAY_START
    mwa #attr_location ATTRIB_START
    mwa #THIS_SCREEN_SIZE SCREEN_SIZE

    jsr text_test

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
   .word $1104
   .word text_location 
   .word attr_location
   .word $0150
   .word text_location
   .word attr_location
   .word $0f00

   icl '../../test/include/text_test.asm'
   icl '../../os/graphics.asm'
   icl '../../os/ram_vram.asm'
   icl '../../os/text.asm'
   icl '../../os/libs/stdlib.asm'
   
   org EXECADDR
   .word start 
   