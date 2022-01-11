   icl '../os/symbols.asm'

block_start   = $C8 ; ROS0
block_end     = $CA ; ROS2

   org BOOTADDR

.proc xex_load
   jsr serial_init
next_block:   
   jsr xex_get_byte
   sta block_start
   sta EXECADDR        ; use block start as default exec address
   jsr xex_get_byte
   sta block_start+1
   sta EXECADDR+1
   and block_start
   cmp #$ff
   beq next_block
   
   jsr xex_get_byte
   sta block_end
   jsr xex_get_byte
   sta block_end+1
   
next_byte:
   jsr xex_get_byte
   ldy #0
   sta (block_start), y
   
   cpw block_start block_end
   beq block_complete
   
   inw block_start
   jmp next_byte
   
block_complete:
   cpw #EXECADDR+1 block_end
   bne next_block
   jsr xex_exec
   jmp next_block
.endp
   
.proc xex_get_byte
   jsr serial_get
   bmi xex_exec
   rts
.endp

.proc xex_exec
   jmp (EXECADDR)
.endp

   icl '../os/serial.asm'
