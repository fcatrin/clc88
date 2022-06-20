lib_vram_to_ram:
   ldx #OS_VRAM_TO_RAM
   jsr OS_CALL
   lda VRAM_PAGE
   sta VPAGE
   rts
   
lib_vramw_to_ram
   mwa VRAM_TO_RAM VADDR  ; this will break crossing the 64KB boundary
   mwa VADDRB VRAM_TO_RAM ; just good enough for simple examples
   jmp lib_vram_to_ram   
   
lib_ram_to_vram:
   ldx #OS_RAM_TO_VRAM
   jmp OS_CALL
   

lib_vram_set:
   ldx #OS_VRAM_SET_BYTES
   jmp OS_CALL

.proc lib_copy_to_vram
   jsr lib_vram_to_ram
   mwa RAM_TO_VRAM DST_ADDR
   jmp memcpy
.endp

.proc memcpy
  ldx #OS_COPY_BLOCK
  jmp OS_CALL
.endp   

.proc string_cmp
   ldy #0
next_char:   
   lda (SRC_ADDR), y
   cmp (DST_ADDR), y
   bne eos
   
   lda (SRC_ADDR), y
   beq eos
   
   iny
   bne next_char
   
eos:
   rts   
.endp
   
.proc file_open_read
   lda #ST_MODE_READ
   ldx #OS_FILE_OPEN
   jsr OS_CALL
   sta file_handle
   rts
.endp 
  
.proc file_read_byte
   ldx #OS_FILE_READ_BYTE
   lda file_handle
   jmp OS_CALL
.endp

.proc file_read_block
   ldx #OS_FILE_READ_BLOCK
   lda file_handle
   jmp OS_CALL
.endp

.proc file_close
   lda file_handle
   ldx #OS_FILE_CLOSE
   jmp OS_CALL
.endp

.proc keyb_read
   ldx #OS_KEYB_POLL
   jsr OS_CALL
   
   lda KEY_PRESSED
   rts
.endp

.proc screen_position
   mwa DISPLAY_START VRAM_TO_RAM
   jmp screen_position_offset
.endp

.proc screen_position_attrib
   mwa ATTRIB_START VRAM_TO_RAM
   jmp screen_position_offset
.endp

.proc screen_position_offset
   stx screen_pos_x
   sty screen_pos_y

   mwa #0 screen_offset
   cpy #0
   beq calc_x
calc_y:   
   adw screen_offset #40
   dey
   bne calc_y
calc_x:

   txa
   clc
   adc screen_offset
   sta screen_offset
   scc
   inc screen_offset+1
  
   jsr lib_vramw_to_ram
   adw RAM_TO_VRAM screen_offset
   rts
screen_offset: .word 0   
.endp

.proc screen_print_at
   jsr screen_position
   jmp screen_print
.endp

.proc screen_print
   lda #0
   sta offset_string
   sta offset_vram
next_char:
   ldy offset_string
   lda (SRC_ADDR), y
   beq print_end
   
   ldy offset_vram
   sta (RAM_TO_VRAM), y
   inc offset_vram
   inc offset_string
   
   inc screen_pos_x         ; check right margin for line wrap / stop
   lda screen_pos_x
   cmp screen_margin_right
   bne next_char
   
   lda screen_line_no_wrap  ; right margin reached. Stop if no wrap
   bne print_end

   inc screen_pos_y         ; check bottom margin 
   ldy screen_pos_y
   cpy screen_margin_bottom
   beq print_end
   
   ldx screen_margin_left   ; recalculate vram address for next line inside margins
   jsr screen_position
   mva #0 offset_vram
   beq next_char
print_end
   rts
offset_vram   .word 0
offset_string .word 0    
.endp

.proc screen_clear
   lda #0
   jmp screen_fill
.endp

.proc screen_fill
   sta screen_fill_byte
   ldx screen_margin_left
   ldy screen_margin_top
   jsr screen_position
   jmp screen_fill_internal
.endp

.proc screen_fill_attrib
   sta screen_fill_byte
   ldx screen_margin_left
   ldy screen_margin_top
   jsr screen_position_attrib
   jmp screen_fill_internal
.endp

.local screen_fill_internal
   lda screen_margin_bottom
   sec
   sbc screen_margin_top
   sta fill_y
   
   lda screen_margin_right
   sec
   sbc screen_margin_left
   sta fill_x
   sta save_x

fill_next_line:
   ldy #0
   lda screen_fill_byte
fill_line:   
   sta (RAM_TO_VRAM), y
   iny
   dec fill_x
   bne fill_line

   dec fill_y
   sne
   rts
   
   adw RAM_TO_VRAM #40
   lda save_x
   sta fill_x
   jmp fill_next_line
save_x  .byte 0
fill_x: .byte 0
fill_y: .byte 0
.endl

.proc screen_scroll_up
   ldx screen_margin_left
   ldy screen_margin_top
   jsr screen_position
   
   mwa RAM_TO_VRAM SRC_ADDR
   adw SRC_ADDR #40

   lda screen_margin_right
   sec
   sbc screen_margin_left
   sta scroll_width
   
   lda screen_margin_bottom
   sec
   sbc screen_margin_top
   sta scroll_height

copy_next_row
   ldy #0
copy_row   
   lda (SRC_ADDR), y
   sta (RAM_TO_VRAM), y
   iny
   cpy scroll_width
   bne copy_row
   adw SRC_ADDR #40
   adw RAM_TO_VRAM #40
   dec scroll_height
   bne copy_next_row
   rts
scroll_width  .byte 0
scroll_height .byte 0   
.endp

.proc screen_scroll_down
   ldx screen_margin_left
   ldy screen_margin_bottom
   dey
   jsr screen_position
   
   mwa RAM_TO_VRAM SRC_ADDR
   sbw SRC_ADDR #40

   lda screen_margin_right
   sec
   sbc screen_margin_left
   sta scroll_width
   
   lda screen_margin_bottom
   sec
   sbc screen_margin_top
   sta scroll_height

copy_next_row
   ldy #0
copy_row   
   lda (SRC_ADDR), y
   sta (RAM_TO_VRAM), y
   iny
   cpy scroll_width
   bne copy_row
   sbw SRC_ADDR #40
   sbw RAM_TO_VRAM #40
   dec scroll_height
   bne copy_next_row
   rts
scroll_width  .byte 0
scroll_height .byte 0   
.endp


screen_fill_byte .byte 0

screen_line_no_wrap:  .byte 0
screen_margin_left:   .byte 0
screen_margin_right:  .byte 0
screen_margin_top:    .byte 0
screen_margin_bottom: .byte 0

screen_pos_x:  .byte 0
screen_pos_y:  .byte 0

file_handle: .byte 0