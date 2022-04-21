
    icl 'include/symbols.asm'
   
	org $FFFA

	.word nmi
	.word boot
	.word irq

EMBEDDED_XEX_START = $e000

	org OS_CALL
init:
	pha
	txa
	asl
	tax
	mwa os_vector_table,x OS_VECTOR
	pla
	jmp (OS_VECTOR)

boot:

; disable Chroni and all interrupts
    sei
    lda #0
    sta VSTATUS
    sta CHRONI_ENABLED

; set default interrupt handlers
    jsr interrupts_init

    mwa #palette SRC_ADDR
    jsr gfx_upload_palette

    mwa #charset SRC_ADDR
    jsr gfx_upload_font

	lda #0
	jsr gfx_set_video_mode

    lda EMBEDDED_XEX_START
    and EMBEDDED_XEX_START+1
    cmp #255
    bne run_embedded_boot_code
    jsr run_embedded_xex

run_embedded_boot_code:
	jmp BOOTADDR

os_vector_table
	.word gfx_set_video_mode
	.word copy_block
	.word copy_block_with_params
	.word mem_set_bytes
	.word ram2vram
	.word vram2ram
	.word gfx_vram_set
	.word keyb_poll
	.word storage_dir_open
	.word storage_dir_read
	.word storage_dir_close
	.word storage_file_open
	.word storage_file_read_byte
	.word storage_file_read_block
	.word storage_file_close
	.word gfx_upload_palette
	.word gfx_display_clear
	.word gfx_attrib_clear

    icl 'interrupts.asm'
    icl 'graphics.asm'
    icl 'storage.asm'
    icl 'serial.asm'
    icl 'keyboard.asm'
    icl 'text.asm'
    icl 'ram_vram.asm'
    icl 'libs/embedded_xex_loader.asm'

palette:
    icl 'data/palette_atari_ntsc.asm'
charset:
	ins 'data/charset_atari.bin'

end_of_rom:
    .byte 0
