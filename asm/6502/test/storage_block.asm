	icl '../os/include/symbols.asm'

; this test is a direct read from storage, without BIOS support
	
	org BOOTADDR
	
   lda #1
   sta ROS7
   lda #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL
   
   sta ST_WRITE_RESET
   
   mwa DISPLAY_START VADDRW
   
; Call command to open file   
   mwa #filename SRC_ADDR
   jsr file_open_read
   
read_next_block:
   mwa #buffer DST_ADDR
   mwa #$100 SIZE
   jsr file_read_block
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
   sta VDATA
   rts
.endp  
   
 
buffer:
   .rept 256
   .byte 0
   .endr
   
filename:
   .by "../asm/6502/test/storage_block.asm", 0
   
message_not_found:
   .by "Cannot open file: ", 0   
	
   icl '../os/libs/stdlib.asm'
