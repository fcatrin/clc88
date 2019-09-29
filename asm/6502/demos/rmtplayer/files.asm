; Max 256 entries 
DIR_ENTRIES       = $8000 ; pointer to names
DIR_ENTRIES_TYPES = $8200 ; type of each file, $FF marks end
DIR_ENTRIES_NAMES = $8300 ; starting addres for names

.proc build_path
   mwa #path DST_ADDR
   
   ldy #0
copy_dirname:   
   lda dirname, y
   beq add_filename
   sta (DST_ADDR),y
   iny
   bne copy_dirname
   
add_filename:   
   lda #'/'
   sta (DST_ADDR), y
   iny
   
   tya
   clc
   adc DST_ADDR
   sta DST_ADDR
   scc
   inc DST_ADDR+1
   
   ldy #0
copy_filename:
   lda filename,y
   sta (DST_ADDR),y
   beq copy_done
   iny
   cpy #128
   bne copy_filename
copy_done:

   ldx #OS_DIR_CLOSE
   jsr OS_CALL
   rts
.endp

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
   mva file_index files_read
   rts

file_index .byte 0
file_name  .word 0

.endp

.proc display_files
   mva #0  file_index
   mva #17 line

   ldx #1
   ldy #1
   jsr screen_position   
   
copy_loop:   
   ldx file_index
   jsr files_print_one

   inc file_index
   lda file_index
   cmp files_read
   beq display_end
   
   adw RAM_TO_VRAM #40
   dec line
   bne copy_loop
   
display_end:
   rts
line       .byte 0
file_index .byte 0
.endp

.proc files_print_one
   lda DIR_ENTRIES_TYPES,x
   sta file_type
   cmp #$FF
   beq print_end
   
   txa
   asl
   tax
   
   mwa DIR_ENTRIES,x SRC_ADDR
   mwa RAM_TO_VRAM   DST_ADDR
   
   lda #23
   sta col
   
   ldy #0
   
   lda file_type
   cmp #ST_TYPE_FILE
   beq copy_name
   
   lda #'['
   sta (DST_ADDR), y
   inw DST_ADDR
   inc col
   
copy_name:
   lda (SRC_ADDR), y
   beq copy_name_done
   sta (DST_ADDR), y
   iny
   dec col
   bne copy_name
   
copy_name_done:
   lda file_type
   cmp #ST_TYPE_FILE
   beq print_end
   
   dec col  
   beq print_end
   
   lda #']'
   sta (DST_ADDR), y

print_end
   rts   

col        .byte 0
file_type  .word 0
   
.endp

.proc display_file_row
   pha

   ldx last_row
   cpx #$FF
   beq no_erase_row

   lda #$10
   jsr paint_file_row
  
no_erase_row:

   pla
   sta last_row
   tax
   
   lda #$34
   jmp paint_file_row
.endp

.proc paint_file_row
   sta R0
   
   inx
   stx screen_margin_top
   inx
   stx screen_margin_bottom
   mva #1  screen_margin_left
   mva #24 screen_margin_right
   
   lda R0
   jmp screen_fill_attrib
.endp

.proc file_name_get
   txa
   asl
   tax
   mwa DIR_ENTRIES,x SRC_ADDR
   
   ldy #0
copy_filename   
   lda (SRC_ADDR), y
   sta filename, y
   beq eos
   iny
   bne copy_filename
eos
   jsr build_path
   mwa #path SRC_ADDR
   rts
.endp

.proc files_change_folder
   txa
   asl
   tax
   mwa DIR_ENTRIES,x SRC_ADDR
   
   ; check if ".."
   lda #1
   sta is_parent
   mwa #parent_dir_name DST_ADDR
   jsr string_cmp
   beq parent_confirmed
   lda #0
   sta is_parent

parent_confirmed
   ldx #0
look_for_tail   
   lda dirname, x
   beq tail_found
   inx
   bne look_for_tail

tail_found   
   lda is_parent
   bne chdir_parent
   
   ldy #0
copy_dir_name:   
   lda (SRC_ADDR), y
   sta dirname, x
   beq eos
   iny
   inx
   bne copy_dir_name
eos:   
   rts
   
chdir_parent:
   lda dirname, x
   tay
   lda #0
   sta dirname, x
   cpy #'/'
   beq eos
   dex
   cpx #$FF
   bne chdir_parent
   rts
   
is_parent .byte 0
   
.endp

.proc set_files_area_margins
   mva #1  screen_margin_left
   mva #1  screen_margin_top
   mva #24 screen_margin_right
   mva #18 screen_margin_bottom
   rts
.endp

.proc files_scroll_up
   jsr set_files_area_margins
   jmp screen_scroll_up
.endp

.proc files_scroll_down
   jsr set_files_area_margins
   jmp screen_scroll_down
.endp

.proc files_display_clear
   jsr set_files_area_margins
   jmp screen_clear
.endp
   
parent_dir_name .byte '..', 0

line_offset .word 0
last_row    .byte 0

files_read .byte 0  

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
