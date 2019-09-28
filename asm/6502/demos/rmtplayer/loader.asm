.proc load_song
   jsr file_open_read
   cmp #$FF
   bne read_xex_header
   lda #$4F ; bright border on error
   sta VCOLOR0
halt: jmp halt

read_xex_header:
   jsr file_read_byte           ; read start address skipping $FFFF values
   bne eof
   sta xex_start
   jsr file_read_byte
   bne eof
   sta xex_start+1
   and xex_start
   cmp #$FF
   beq read_xex_header
   
   jsr file_read_byte
   bne eof
   sta xex_end
   jsr file_read_byte
   bne eof
   sta xex_end+1
   
   mwa xex_start song_text
   mwa xex_start DST_ADDR
   
   mwa xex_end SIZE
   sbw SIZE xex_start
   inw SIZE
   
   jsr file_read_block
   beq read_xex_header
   
eof:
   jmp file_close 
   
xex_start:
   .word 0
xex_end:
   .word 0
   
.endp
