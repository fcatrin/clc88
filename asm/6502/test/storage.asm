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
   lda #ST_CMD_OPEN
   jsr storage_write
   
   lda #ST_MODE_READ
   jsr storage_write
   
   ldx #0
send_filename:   
   lda filename, x
   beq @+ 
   jsr storage_write
   inx
   bne send_filename
   lda #0
   jsr storage_write
   
; Proceed with command  
   
@: 
   jsr storage_proceed
   
   jsr storage_read ; length of response. Ignored in this example
   jsr storage_read ; result of the operation
   cmp #ST_RET_SUCCESS
   bne end_with_error
   
   jsr storage_read ; file handle
   sta file_handle
   
read_next_byte:   
   lda #ST_CMD_READ_BYTE
   jsr storage_write
   lda file_handle
   jsr storage_write
   
   jsr storage_proceed
   jsr storage_read ; length of response. Ignored in this example
   jsr storage_read
   cmp #ST_RET_SUCCESS
   bne eof
   jsr storage_read
   cmp #32
   bcc read_next_byte
   jsr screen_putc
   jmp read_next_byte
eof:
   lda #ST_CMD_CLOSE
   jsr storage_write
   lda file_handle
   jsr storage_write
   jsr storage_proceed
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
      
	
	
.proc storage_write
   stx R0
   
@:
   ldx ST_WRITE_ENABLE
   bne @-
   sta ST_WRITE_DATA
   ldx #$FF
   stx ST_WRITE_ENABLE

   ldx R0   
   rts
.endp 

.proc storage_read
   stx R0
   
@:
   ldx ST_READ_ENABLE
   bne @-
   lda ST_READ_DATA
   ldx #$FF
   stx ST_READ_ENABLE
   ldx R0   
   rts
.endp

.proc storage_proceed
   sta ST_PROCEED
@:
   lda ST_STATUS
   cmp #ST_STATUS_DONE
   bne @-
   rts
.endp
   
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
   
filename:
   .by "../asm/6502/test/storage.asm", 0
   
message_not_found:
   .by "Cannot open file: ", 0   
	
   icl '../os/stdlib.asm'
