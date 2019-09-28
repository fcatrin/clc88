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
   jsr file_open_read
   
read_next_byte:   
   jsr file_read_byte
   bne eof
   
   cmp #32
   bcc read_next_byte
   jsr screen_putc
   jmp read_next_byte
eof:
   jsr file_close
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
   
filename:
   .by "../asm/6502/test/storage.asm", 0
   
message_not_found:
   .by "Cannot open file: ", 0   
	
   icl '../os/stdlib.asm'
