MIF=rtl/compy/rom.mif

ALL: fpga_rom


fpga_rom : ${MIF}

${MIF} : fpga_rom_mif

fpga_rom_mif : fpga_rom_build.c
	gcc fpga_rom_build.c -o fpga_rom_build
	
clean:
	rm -f fpga_rom_build