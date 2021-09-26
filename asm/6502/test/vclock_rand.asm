   icl '../os/symbols.asm'
   
   org BOOTADDR
   
   mva #0 ROS7
   lda #9
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL
   
   mwa DISPLAY_START VRAM_TO_RAM
   jsr lib_vram_to_ram
   mwa RAM_TO_VRAM R0
   mwa VPAGE R3
   mwa #0 R4
   
next_frame:   
   mwa R0 RAM_TO_VRAM
   mwa R3 VPAGE
   
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
   sta (RAM_TO_VRAM), y
   iny
   cpy #160
   bne put_pixel
   
   adw RAM_TO_VRAM #160
   lda RAM_TO_VRAM+1
   cmp #$df
   bne no_page_flip
   inc VPAGE
   lda #$a0
   sta RAM_TO_VRAM+1
   
no_page_flip:   
   dex
   bne put_line
   
   lda FRAMECOUNT
wait:
   cmp FRAMECOUNT
   beq wait
   jmp next_frame
   
   icl '../os/stdlib.asm'