   icl '../../os/symbols.asm'
   
   org BOOTADDR

   lda #1
   ldy #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL
   
   lda VSTATUS
   and #(255 - VSTATUS_EN_INTS)
   sta VSTATUS
      
   mwa #vblank VBLANK_VECTOR_USER
   mwa #dli    HBLANK_VECTOR_USER
   
   lda #1
   sta VLINEINT

   lda VSTATUS
   ora #VSTATUS_EN_INTS
   sta VSTATUS
   
   mwa DISPLAY_START VADDRW
   
   ldy #0
copy:
   lda message, y
   cmp #255
   beq rainbow
   sta VDATA
   iny
   bne copy
   ldx #0
rainbow:
   clc
   lda VCOUNT
   adc FRAMECOUNT
   sta WSYNC
   sta VBORDER
   jmp rainbow
   
dli:
   pha
   lda #$66
   sta WSYNC
   sta VBORDER
   pla
   rts

vblank:
   pha
   lda #$BF
   sta VBORDER
   pla
   rts
   
message:
   .by "Hello world!!!!", 96, 255

   icl '../../os/stdlib.asm'
