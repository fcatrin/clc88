block_start   = $C8 ; ROS0
block_end     = $CA ; ROS2
block_src     = $CC ; ROS4

.proc run_embedded_xex
    mwa #$e000 block_src
next_block:
    jsr emb_xex_get_byte
    sta block_start
    sta EXECADDR        ; use block start as default exec address
    jsr emb_xex_get_byte
    sta block_start+1
    sta EXECADDR+1
    and block_start
    cmp #$ff
    beq next_block

    jsr emb_xex_get_byte
    sta block_end
    jsr emb_xex_get_byte
    sta block_end+1
   
next_byte:
    jsr emb_xex_get_byte
    ldy #0
    sta (block_start), y

    cpw block_start block_end
    beq block_complete

    inw block_start
    jmp next_byte
   
block_complete:
    cpw #EXECADDR+1 block_end
    bne next_block
    jsr emb_xex_exec
    jmp next_block
.endp

.proc emb_xex_get_byte
    ldy #0
    lda (block_src), y
    inw block_src
    rts
.endp

.proc emb_xex_exec
    jmp (EXECADDR)
.endp
