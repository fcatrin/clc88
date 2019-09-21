	icl '../os/symbols.asm'

; this test is a direct read from storage, without BIOS support
	
	org BOOTADDR
	
	lda #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL
   
   sta ST_WRITE_RESET
   
   mwa DISPLAY_START VRAM_TO_RAM
   jsr lib_vram_to_ram
   
; Call command to open dir   
   lda #ST_CMD_DIR_OPEN
   jsr storage_write
   
   ldx #0
send_dirname:   
   lda dirname, x
   beq @+ 
   jsr storage_write
   inx
   bne send_dirname
@: 
   lda #0
   jsr storage_write
   
; Proceed with command  
   
   jsr storage_proceed
   
   jsr storage_read ; length of response. Ignored in this example
   jsr storage_read ; result of the operation
   cmp #ST_RET_SUCCESS
   jne end_with_error
   
   jsr storage_read ; dir handle
   sta dir_handle
   
   jsr storage_read ; dir length
   sta dir_length
   jsr storage_read
   sta dir_length+1
   
read_next_entry:   
   lda #ST_CMD_DIR_READ
   jsr storage_write
   
   lda dir_handle
   jsr storage_write
   
   lda dir_index
   jsr storage_write
   lda dir_index+1
   jsr storage_write
   
   jsr storage_proceed
   jsr storage_read ; length of response. Ignored in this example
   jsr storage_read
   cmp #ST_RET_SUCCESS
   bne end_of_dir

   ldy #0

   jsr storage_read ; is_dir
.rept 4
   jsr storage_read ; size
.endr

copy_date:
   jsr storage_read ; date
   sta (RAM_TO_VRAM), y
   iny
   cpy #08
   bne copy_date
   iny

copy_time:
   jsr storage_read ; time
   sta (RAM_TO_VRAM), y
   iny
   cpy #13
   bne copy_time
   iny
   jsr storage_read ; time
   jsr storage_read ; time

copy_name:   
   jsr storage_read
   cmp #0
   beq name_ends
   sta (RAM_TO_VRAM), y

   iny
   cpy #40
   bne copy_name
name_ends:
   adw RAM_TO_VRAM #40
   inw dir_index
   lda dir_index
   cmp #24
   jne read_next_entry

end_of_dir:
   lda #ST_CMD_DIR_CLOSE
   jsr storage_write
   lda dir_handle
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
   lda dirname, x
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

dir_handle:
   .byte 0
dir_length:
	.word 0
dir_index:
	.word 0
	
dirname:
   .by "./", 0
   
message_not_found:
   .by "Cannot open dir: ", 0   
	
   icl '../os/stdlib.asm'
