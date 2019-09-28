	icl '../os/symbols.asm'

; this test is a direct read from storage, without BIOS support
	
	org BOOTADDR
	
	lda #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL
   
   sta ST_WRITE_RESET
   
   mwa DISPLAY_START VRAM_TO_RAM
   jsr lib_vram_to_ram
   
; Call command to open file   
   mwa #filename SRC_ADDR
   lda #ST_MODE_READ
   ldx #OS_FILE_OPEN
   jsr OS_CALL
   
   sta file_handle
   
read_next_block:
   mwa #buffer DST_ADDR
   mwa #$100 SIZE
   ldx #OS_FILE_READ_BLOCK
   lda file_handle
   jsr OS_CALL
   bne eof

   ldy #0
copy_block
   lda buffer, y
   cmp #32
   bcc skip
   jsr screen_putc
skip:   
   iny
   cpy SIZE
   bne copy_block   
   jmp read_next_block
   
eof:
   ldx #OS_FILE_CLOSE
   lda file_handle
   jsr OS_CALL
   jmp end

end_with_error:
   ldx #0
@:   
   lda message_not_found, x
   beq print_filename
   jsr screen_putc
   inx
   bne @-
   
print_filename:   
   ldx #0
@:   
   lda filename, x
   beq end
   jsr screen_putc
   inx
   bne @-
   
end: 
   jmp end
      
  
.proc screen_putc
   sty R0
   ldy #0
   sta (RAM_TO_VRAM), y
   inw RAM_TO_VRAM
   ldy R0
   rts
.endp  
   
file_handle:
   .byte 0
   
buffer:
   .rept 256
   .byte 0
   .endr
   
filename:
   .by "../asm/6502/test/storage_block.asm", 0
   
message_not_found:
   .by "Cannot open file: ", 0   
	
   icl '../os/stdlib.asm'
