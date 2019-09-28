; Max 256 entries 
DIR_ENTRIES       = $6000 ; pointer to names
DIR_ENTRIES_TYPES = $6200 ; type of each file, $FF marks end
DIR_ENTRIES_NAMES = $6300 ; starting addres for names

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

/*
   mwa DISPLAY_START VRAM_TO_RAM
   jsr lib_vram_to_ram
   
   adw RAM_TO_VRAM #40+2

   cmp #ST_TYPE_FILE
   beq copy_name
   
   lda #'['
   sta (RAM_TO_VRAM), y
   iny


*/

.proc list_files
   mwa #0 file_index
   mwa #DIR_ENTRIES_NAMES file_name
   
   mwa #dirname SRC_ADDR
   lda #0
   ldx #OS_DIR_OPEN
   jsr OS_CALL
   
   lda ST_DIR_HANDLE
   cmp #$FF
   beq list_end
   
   mwa #0 ST_DIR_INDEX
   
read_next_entry:
   ldx #OS_DIR_READ
   jsr OS_CALL

   ldx file_index
   lda ST_FILE_TYPE
   sta DIR_ENTRIES_TYPES, x

   cmp #$FF      
   beq list_end

   txa
   asl
   tax
   mwa file_name DIR_ENTRIES,x
   mwa file_name DST_ADDR

   ldx #0
   ldy #0   
copy_name:
   lda ST_FILE_NAME, x
   sta (DST_ADDR), y
   inw DST_ADDR
   
   lda ST_FILE_NAME, x
   beq name_ends

   inx
   bne copy_name
name_ends:
   mwa DST_ADDR file_name
   inc file_index
   bne read_next_entry
list_end:
      
   rts

file_index .byte 0
file_name  .word 0

.endp

.proc display_files
   sta file_index
   mva #0 line
   
   mwa DISPLAY_START VRAM_TO_RAM
   jsr lib_vram_to_ram
   
   adw RAM_TO_VRAM #40+2
   
copy_loop:   
   lda file_index
   tax
   
   lda DIR_ENTRIES_TYPES,x
   sta file_type
   cmp #$FF
   beq display_end
   
   txa
   asl
   tax
   
   mwa DIR_ENTRIES,x SRC_ADDR
   mwa RAM_TO_VRAM DST_ADDR
   
   ldy #0
   
   lda file_type
   cmp #ST_TYPE_FILE
   beq copy_name
   
   lda #'['
   sta (DST_ADDR), y
   inw DST_ADDR
   
copy_name:
   lda (SRC_ADDR), y
   beq copy_name_done
   sta (DST_ADDR), y
   iny
   bne copy_name
   
copy_name_done:
   lda file_type
   cmp #ST_TYPE_FILE
   beq next_line
   
   iny
   lda #']'
   sta (DST_ADDR), y
   
next_line:
   inc file_index
   inc line
   lda line
   cmp #20
   beq display_end
   
   adw RAM_TO_VRAM #40
   jmp copy_loop
   
display_end:
   rts
   
line       .byte 0
file_index .byte 0
file_type  .word 0
.endp

.proc display_file_row
   pha
   mwa ATTRIB_START VRAM_TO_RAM
   jsr lib_vram_to_ram
   adw RAM_TO_VRAM #40

   ldx last_row
   cpx #$FF
   beq no_erase_row
   
no_erase_row:
   pla
   sta last_row
   tax
   jsr line_to_offset
   
   adw RAM_TO_VRAM line_offset
   
   ldy #2
   lda #$34
next_attrib:   
   sta (RAM_TO_VRAM), y
   iny
   cpy #38
   bne next_attrib
   rts
.endp

.proc line_to_offset
   mwa #0 line_offset
   jmp while
next_mul:   
   adw line_offset #40 ; forgive me lord!
while:
   dex   
   cpx #$FF
   bne next_mul
   rts
.endp

.proc file_name_get
   txa
   asl
   tax
   mwa DIR_ENTRIES,x SRC_ADDR
   rts
.endp

line_offset .word 0
last_row    .byte 0   

dirname:
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
