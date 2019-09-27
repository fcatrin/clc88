.proc storage_dir_open
; Open Dir
; in:  dirname at SRC_ADDR
; out: dir handle at STORAGE_DIR_HANDLE
; out: dir size   at STORAGE_DIR_SIZE

   lda #ST_CMD_DIR_OPEN
   jsr storage_write
   
   ldy #0
send_dirname:   
   lda (SRC_ADDR), y
   beq @+ 
   jsr storage_write
   iny
   bne send_dirname
@: 
   lda #0
   jsr storage_write
   
; Proceed with command  
   
   jsr storage_proceed
   
   jsr storage_read ; length of response. Ignored for now
   jsr storage_read ; result of the operation
   cmp #ST_RET_SUCCESS
   beq read_dir_data
   
   lda #0               ; on failure return Hanle = $FF
   sta ST_DIR_LENGTH
   sta ST_DIR_LENGTH+1
   
   lda #$FF
   sta ST_DIR_HANDLE
   rts
read_dir_data:   
   jsr storage_read ; dir handle
   sta ST_DIR_HANDLE
   jsr storage_read ; dir length
   sta ST_DIR_LENGTH
   jsr storage_read
   sta ST_DIR_LENGTH+1
   rts
   
   rts
.endp

.proc storage_dir_close
   lda #ST_CMD_DIR_CLOSE
   jsr storage_write
   lda ST_DIR_HANDLE
   jsr storage_write
   jsr storage_proceed
   lda #$FF
   sta ST_DIR_HANDLE
   rts
.endp

.proc storage_dir_read
   lda #ST_CMD_DIR_READ
   jsr storage_write
   
   lda ST_DIR_HANDLE
   jsr storage_write
   
   lda ST_DIR_INDEX
   jsr storage_write
   lda ST_DIR_INDEX+1
   jsr storage_write
   
   jsr storage_proceed
   jsr storage_read ; length of response. Ignored for now
   jsr storage_read
   cmp #ST_RET_SUCCESS
   beq read_entry
   
   lda #$FF           ; on failure return file type = $FF
   sta ST_FILE_TYPE
   rts

read_entry:
   jsr storage_read ; is dir
   sta ST_FILE_TYPE

   ldx #0
read_entry_size:       ; 32 bits for entry size
   jsr storage_read 
   sta ST_FILE_SIZE, x
   inx
   cpx #4
   bne read_entry_size

   ldx #0
read_date:              ; 8 bytes per date. Format is YYYYMMDD
   jsr storage_read 
   sta ST_FILE_DATE, x
   inx
   cpx #08
   bne read_date

   ldx #0
read_time:              ; 6 bytes per time. Format is HHMMSS
   jsr storage_read 
   sta ST_FILE_TIME, x
   inx
   cpx #6
   bne read_time

   ldx #0
copy_name:              ; file name ends with 0. Max size = 128 bytes including the final 0
   jsr storage_read
   cmp #0
   beq name_ends
   sta ST_FILE_NAME, x
   inx
   cpx #127
   bne copy_name
   lda #0
name_ends:
   sta ST_FILE_NAME, x
   
   inw ST_DIR_INDEX
   rts
.endp


.proc storage_file_open
; Open File
; in:  mode in A
; in:  filename at SRC_ADDR
; out: file handle in A or $FF if error

   tax
   lda #ST_CMD_OPEN
   jsr storage_write
   
   txa
   jsr storage_write
   
   ldy #0
send_filename:   
   lda (SRC_ADDR), y
   beq @+ 
   jsr storage_write
   iny
   bne send_filename
@: 
   lda #0
   jsr storage_write

; Proceed with command  
   jsr storage_proceed
   
   jsr storage_read ; length of response. Ignored at this time
   jsr storage_read ; result of the operation
   cmp #ST_RET_SUCCESS
   beq get_file_handle
   
   lda #$ff
   rts
get_file_handle:   
   jsr storage_read ; file handle
   rts
.endp

.proc storage_file_read_byte
   tax
   lda #ST_CMD_READ_BYTE
   jsr storage_write
   txa
   jsr storage_write
   
   jsr storage_proceed
   jsr storage_read ; length of response. Ignored at this time
   jsr storage_read
   tax
   cmp #ST_RET_SUCCESS
   beq read_byte
   rts
read_byte:
   jsr storage_read
   rts
.endp

.proc storage_file_close
   tax
   lda #ST_CMD_CLOSE
   jsr storage_write
   txa
   jsr storage_write
   jmp storage_proceed
.endp

.proc storage_write
   stx ROS0
@:
   ldx ST_WRITE_ENABLE
   bne @-
   sta ST_WRITE_DATA
   ldx #$FF
   stx ST_WRITE_ENABLE
   
   ldx ROS0
   rts
.endp 

.proc storage_read
@:
   stx ROS0
   ldx ST_READ_ENABLE
   bne @-
   lda ST_READ_DATA
   ldx #$FF
   stx ST_READ_ENABLE
   ldx ROS0   
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
