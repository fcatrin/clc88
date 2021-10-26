MIF=../rtl/compy/rom.mif
BIOS_SRC=../asm/fpga/rom.asm
BIOS_XEX=../asm/fpga/rom.xex
INCLUDE1=../asm/fpga/symbols.asm
INCLUDE2=../asm/fpga/text.asm
INCLUDE3=../asm/fpga/graphics.asm
INCLUDE4=../asm/fpga/demos/text_mode_attrib.asm
INCLUDE5=../asm/fpga/demos/m6502_test.asm
INCLUDE6=../asm/fpga/demos/cpu_speed.asm
INCLUDE7=../asm/fpga/demos/timers.asm

ALL:  ${MIF}

${MIF} : fpga_rom_build
	./fpga_rom_build

INCLUDES=${INCLUDE1} ${INCLUDE2} ${INCLUDE3} ${INCLUDE4} ${INCLUDE5} \
	 ${INCLUDE6} ${INCLUDE7}

fpga_rom_build : fpga_rom_build.c ${BIOS_XEX}
	gcc fpga_rom_build.c -o fpga_rom_build

${BIOS_XEX} : ${BIOS_SRC} ${INCLUDES}
	mads ${BIOS_SRC} -o:${BIOS_XEX} -l
	
clean:
	rm -f fpga_rom_build ${BIOS_XEX}