.proc build_path
   ldx #0
copy_dirname:   
   lda dirname, x
   beq add_filename
   sta path,x
   inx
   bne copy_dirname
   
add_filename:   
   lda #'/'
   sta path,x
   inx
   
   txa
   clc
   adc #<path
   sta DST_ADDR
   lda #>path
   adc #0
   sta DST_ADDR+1
   
   ldx #0
copy_filename:
   lda filename,x
   sta path,x
   beq copy_done
   inx
   cpx #128
   bne copy_filename
copy_done:

   ldx #OS_DIR_CLOSE
   jsr OS_CALL
   rts
.endp

.proc list_files
   mwa DISPLAY_START VRAM_TO_RAM
   jsr lib_vram_to_ram
   
   adw RAM_TO_VRAM #40+2

   mwa #dirname SRC_ADDR
   lda #0
   ldx #OS_DIR_OPEN
   jsr OS_CALL
   
   lda ST_DIR_HANDLE
   cmp #$FF
   beq display_end
   
   mwa #0 ST_DIR_INDEX
   
read_next_entry:
   ldx #OS_DIR_READ
   jsr OS_CALL

   lda ST_FILE_TYPE
   cmp #$FF      
   beq display_end

   ldy #0
   ldx #0
   
   cmp #ST_TYPE_FILE
   beq copy_name
   
   lda #'['
   sta (RAM_TO_VRAM), y
   iny
   
copy_name:   
   lda ST_FILE_NAME, x
   cmp #0
   beq name_ends
   sta (RAM_TO_VRAM), y
   inx
   iny
   cpy #40
   bne copy_name
name_ends:
   lda ST_FILE_TYPE
   cmp ST_TYPE_FILE
   beq next_file
   
   lda #']'
   sta (RAM_TO_VRAM), y
   
next_file:
   adw RAM_TO_VRAM #40
   lda ST_DIR_INDEX
   cmp #20
   bcc read_next_entry
display_end:      
   rts

.endp

dirname:
   .byte '/home/fcatrin', 0
   .rept 256
   .byte 0
   .endr
filename:
   .rept 128
   .byte 0
   .endr
path:
   .rept 128+256
   .byte 0
   .endr
   
test_path:
   .byte '/home/fcatrin/git/clc88/asm/6502/demos/rmt/songs/commando.rmt', 0
