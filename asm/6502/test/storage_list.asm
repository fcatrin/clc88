	icl '../os/symbols.asm'

; this test is a direct read from storage, without BIOS support
	
	org BOOTADDR
	
	lda #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL
   
   sta ST_WRITE_RESET
   
   mwa DISPLAY_START VRAM_TO_RAM
   jsr lib_vram_to_ram
   mwa RAM_TO_VRAM vram_line
   
   mwa #dirname SRC_ADDR
   lda #0
   ldx #OS_DIR_OPEN
   jsr OS_CALL

   lda ST_DIR_HANDLE
   cmp #$FF
   jeq end_with_error
   
read_next_entry:
   ldx #OS_DIR_READ
   jsr OS_CALL

   lda ST_FILE_TYPE
   cmp #$FF      
   beq end_of_dir

   mwa #ST_FILE_DATE SRC_ADDR
   mwa RAM_TO_VRAM  DST_ADDR
   mwa #8 SIZE
   ldx #OS_COPY_BLOCK
   jsr OS_CALL

   mwa #ST_FILE_TIME SRC_ADDR
   mwa RAM_TO_VRAM  DST_ADDR
   adw DST_ADDR #9
   mwa #4 SIZE
   ldx #OS_COPY_BLOCK
   jsr OS_CALL

   adw RAM_TO_VRAM #14

   ldy #0
copy_name:   
   lda ST_FILE_NAME, y
   cmp #0
   beq name_ends
   sta (RAM_TO_VRAM), y

   iny
   cpy #40 - 14
   bne copy_name
name_ends:
   adw RAM_TO_VRAM #(40 - 14)
   lda ST_DIR_INDEX
   cmp #24
   jne read_next_entry

end_of_dir:
   ldx #OS_DIR_CLOSE
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
   lda dirname, x
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

vram_line .word 0
      
dirname:
   .by  0
   
message_not_found:
   .by "Cannot open dir: ", 0   
	
   icl '../os/stdlib.asm'
