BIOS_ROOT=../asm/6502/os
BIOS_SRC=$(BIOS_ROOT)/rom.asm
BIOS_XEX=../bin/fpga_rom.xex
BIOS_INCLUDES= \
	$(BIOS_ROOT)/interrupts.asm \
	$(BIOS_ROOT)/graphics.asm \
	$(BIOS_ROOT)/storage.asm \
	$(BIOS_ROOT)/serial.asm \
	$(BIOS_ROOT)/keyboard.asm \
	$(BIOS_ROOT)/text.asm \
	$(BIOS_ROOT)/ram_vram.asm \
	$(BIOS_ROOT)/libs/embedded_xex_loader.asm \
	$(BIOS_ROOT)/data/palette_atari_ntsc.asm \
	$(BIOS_ROOT)/data/charset_atari.bin

ALL:  fonts_convert fpga_rom_build
	rm -rf ../rtl/incremental_db
	./fpga_rom_build

fpga_rom_build : fpga_rom_build.c ${BIOS_XEX}
	gcc fpga_rom_build.c -o fpga_rom_build

fonts_convert : fonts/convert
	cd fonts && ./convert && cp binary/* ../../res/fonts/

fonts/convert : fonts/convert.c
	gcc fonts/convert.c -o fonts/convert


${BIOS_XEX} : ${BIOS_SRC} ${BIOS_INCLUDES}
	mads ${BIOS_SRC} -o:${BIOS_XEX} -l
	
clean:
	rm -f fpga_rom_build ${BIOS_XEX}