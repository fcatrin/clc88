   icl '../os/include/symbols.asm'
   
   org BOOTADDR
   
   mva #0 ROS7
   lda #9
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL
   

   mwa #0 R4
   
next_frame:   
   mwa DISPLAY_START VADDRW
   
   lda R4
   and #$30
   lsr 
   lsr
   sta VBORDER
   lsr
   lsr
   sta VCLOCK

   inc R4
   
   ldx #192
put_line   
   ldy #0
put_pixel:
   lda VRAND
   sta VDATA
   iny
   cpy #160
   bne put_pixel

   dex
   bne put_line
   
   lda FRAMECOUNT
wait:
   cmp FRAMECOUNT
   beq wait
   jmp next_frame
   
   icl '../os/libs/stdlib.asm'