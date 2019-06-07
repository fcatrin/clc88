lib_vram_to_ram:
   ldx #OS_VRAM_TO_RAM
   jsr OS_CALL
   lda VRAM_PAGE
   sta VPAGE
   rts
   
lib_ram_to_vram:
   ldx #OS_RAM_TO_VRAM
   jmp OS_CALL
   

