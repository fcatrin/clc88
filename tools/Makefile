MIF=../rtl/compy/rom.mif
BIOS_SRC=../asm/fpga/rom.asm
BIOS_XEX=../asm/fpga/rom.xex
INCLUDE1=../asm/fpga/symbols.asm
INCLUDE2=../asm/fpga/screen.asm

ALL:  ${MIF}

${MIF} : fpga_rom_build
	./fpga_rom_build


fpga_rom_build : fpga_rom_build.c ${BIOS_XEX}
	gcc fpga_rom_build.c -o fpga_rom_build

${BIOS_XEX} : ${BIOS_SRC} ${INCLUDE1} ${INCLUDE2}
	mads ${BIOS_SRC} -o:${BIOS_XEX} -l
	
clean:
	rm -f fpga_rom_build ${BIOS_XEX}