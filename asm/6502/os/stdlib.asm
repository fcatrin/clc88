lib_vram_to_ram:
   ldx #OS_VRAM_TO_RAM
   jsr OS_CALL
   lda VRAM_PAGE
   sta VPAGE
   rts
   
lib_ram_to_vram:
   ldx #OS_RAM_TO_VRAM
   jmp OS_CALL
   

lib_vram_set_bytes:
   ldx #OS_VRAM_SET_BYTES
   jmp OS_CALL
   
   
.proc file_open_read
   lda #ST_MODE_READ
   ldx #OS_FILE_OPEN
   jsr OS_CALL
   sta file_handle
   rts
.endp 
  
.proc file_read_byte
   ldx #OS_FILE_READ_BYTE
   lda file_handle
   jmp OS_CALL
.endp

.proc file_read_block
   ldx #OS_FILE_READ_BLOCK
   lda file_handle
   jmp OS_CALL
.endp

.proc file_close
   lda file_handle
   ldx #OS_FILE_CLOSE
   jmp OS_CALL
.endp

file_handle: .byte 0