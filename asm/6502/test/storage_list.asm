	icl '../os/symbols.asm'

; this test is a direct read from storage, without BIOS support
	
	org BOOTADDR
	
   lda #1
   sta ROS7
   lda #0
   ldx #OS_SET_VIDEO_MODE
   jsr OS_CALL

   
   sta ST_WRITE_RESET
   
   mwa #dirname SRC_ADDR
   lda #0
   ldx #OS_DIR_OPEN
   jsr OS_CALL

   lda ST_DIR_HANDLE
   cmp #$FF
   jeq end_with_error

   mwa DISPLAY_START DST_ADDR
   
read_next_entry:
   ldx #OS_DIR_READ
   jsr OS_CALL

   lda ST_FILE_TYPE
   cmp #$FF      
   beq end_of_dir

   mwa DST_ADDR VADDR
   mwa #ST_FILE_DATE SRC_ADDR
   mwa #8 SIZE
   jsr print
   
   lda #0
   sta VDATA
   
   mwa #ST_FILE_TIME SRC_ADDR
   mwa #4 SIZE
   jsr print

   lda #0
   sta VDATA

   mwa #ST_FILE_NAME SRC_ADDR
   jsr printz

   adw DST_ADDR #80
   
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
   sta VDATA
   rts
.endp  

.proc print
   ldy #0
next   
   lda (SRC_ADDR), y
   sta VDATA
   iny
   cpy SIZE
   bne next
   rts
.endp   

.proc printz
   ldy #0
next   
   lda (SRC_ADDR), y
   beq done
   sta VDATA
   iny
   bne next
done:
   rts
.endp   
      
dirname:
   .by  0
   
message_not_found:
   .by "Cannot open dir: ", 0   
	
   icl '../os/stdlib.asm'
