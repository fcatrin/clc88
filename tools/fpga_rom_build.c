#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>

#define MEM_SIZE 0x10000
uint8_t rom[MEM_SIZE];

static int to_printable_char(char c);
static char *to_printable_pixels(int c);

static void load(FILE *f, int dups, int addr, int size) {
	int skip = 1;
	uint8_t c = 0;
	while (size > 0 && addr < MEM_SIZE && fread(&c, 1, 1, f)){
		skip = 1 - skip;
		if (skip && dups) continue;

		rom[addr++] = (uint8_t)c;
		size--;
	}
}

static void load_bin(char *filename, int addr) {
	FILE *f = fopen(filename, "rb");
	if (!f) {
		fprintf(stderr, "Error opening %s: %s\n", filename, strerror(errno));
		return;
	}

	load(f, 0, addr, MEM_SIZE);
	fclose(f);
}

static void load_xex(char *filename) {
	uint8_t buffer[2];

	FILE *f = fopen(filename, "rb");
	if (!f) {
		fprintf(stderr, "Error opening %s: %s\n", filename, strerror(errno));
		return;
	}

	int n=0;
	while((n = fread(buffer, 2, 1, f))) {
		if ((buffer[0] & buffer[1]) == 0xFF) {
			continue;
		}
		unsigned int offset = buffer[0] + (buffer[1] << 8);
		fread(buffer, 2, 1, f);
		unsigned int size = buffer[0] + (buffer[1] << 8) - offset + 1;
		printf("reading offset %04X size: %04X\n", offset, size);

		load(f, 0, offset, size);
	}

	fclose(f);

}

static void dump(FILE *fout, int addr) {
	int line = 0;
	for(int i=addr; i<0x10000; i++) {
		uint8_t c = rom[addr];

		char comment[200];
		sprintf(comment, "%c %s", to_printable_char(c), to_printable_pixels(c));

		fprintf(fout, "%04X : %02X; -- %s\n", addr, c, comment);

		addr++;
	}
}

static int to_printable_char(char c) {
	if (isdigit(c) || isalpha(c)) {
		return c;
	}
	return ' ';
}

static char *to_printable_pixels(int c) {
	static char buffer[9];
	int n = 128;
	for(int i=0; i<8; i++) {
		buffer[i] = (c & n) ? 'O' : '.';
		n >>= 1;
	}
	buffer[8] = 0;
	return buffer;
}

static void create_mif(char *filename, int base_addr) {
	int size = MEM_SIZE - base_addr;

	FILE *f = fopen("../rtl/compy/rom.mif", "wb");
	fprintf(f, "WIDTH=8;\n");
	fprintf(f, "DEPTH=%d;\n", size);
	fprintf(f, "\n");
	fprintf(f, "ADDRESS_RADIX=HEX;\n");
	fprintf(f, "DATA_RADIX=HEX;\n");
	fprintf(f, "\n");
	fprintf(f, "CONTENT BEGIN\n");

	dump(f, base_addr);

	fprintf(f, "END\n");
	fclose(f);

}

int main(int argc, char *argv[]) {
	load_bin("../res/fonts/charset_atari.bin",            0xE000);
	load_bin("../res/fonts/charset_topaz_a500.bin",       0xE400);
	load_bin("../res/fonts/charset_topaz_a1200.bin",      0xE800);
	load_bin("../res/fonts/charset_topaz_plus_a500.bin",  0xEC00);
	load_bin("../res/fonts/charset_topaz_plus_a1200.bin", 0xEC00);
	load_xex("../res/fpga_rom.xex");

	create_mif("../rtl/compy/rom.mif", 0xE000);
}
