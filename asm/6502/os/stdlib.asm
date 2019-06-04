lib_vram_to_ram:
   ldx #OS_VRAM_TO_RAM
   jsr OS_CALL
   lda VRAM_PAGE
   sta VPAGE
   rts

