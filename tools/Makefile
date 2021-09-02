MIF=../rtl/compy/rom.mif
BIOS_SRC=../res/fpga_rom.asm
BIOS_XEX=../res/fpga_rom.xex

ALL:  ${MIF}

${MIF} : fpga_rom_build
	./fpga_rom_build


fpga_rom_build : fpga_rom_build.c ${BIOS_XEX}
	gcc fpga_rom_build.c -o fpga_rom_build

${BIOS_XEX} : ${BIOS_SRC}
	mads ${BIOS_SRC} -o:${BIOS_XEX}
	
clean:
	rm -f fpga_rom_build ${BIOS_XEX}