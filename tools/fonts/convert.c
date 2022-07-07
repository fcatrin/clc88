#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>

#define MEM_SIZE 0x10000
uint8_t rom[MEM_SIZE];

static void load(FILE *f, int addr, int size, int dups) {
	int skip = 1;
	uint8_t c = 0;
	while (size > 0 && addr < MEM_SIZE && fread(&c, 1, 1, f)){
		skip = 1 - skip;
		if (skip && dups) continue;

		rom[addr++] = (uint8_t)c;
		size--;
	}
}

static void load_bin(char *filename, int addr, int dups) {
	printf("Convert font %s -> ", filename);
	FILE *f = fopen(filename, "rb");
	if (!f) {
		fprintf(stderr, "Error opening %s: %s\n", filename, strerror(errno));
		return;
	}
	load(f, addr, MEM_SIZE, dups);
	fclose(f);
}

static void save_bin(char *filename, int base_addr) {
    printf("%s\n", filename);
	FILE *f = fopen(filename, "wb");
	fwrite(&rom[base_addr], 1, 0x400, f);
	fclose(f);
}

void atascii_copy(int src_addr, int dst_addr) {
	for(int i=0; i<0x100; i++) {
		rom[dst_addr + i] = rom[src_addr + i];
	}
}

void atascii2ascii(int src_addr, int dst_addr) {
	// ascii font is
	// SPC, symbols at 000
	// SPC, ! " etc at 100
	// @ A B C  etc at 200
	// (c) a b  etc at 300
	atascii_copy(src_addr + 0x000, dst_addr + 0x100);
	atascii_copy(src_addr + 0x100, dst_addr + 0x200);
	atascii_copy(src_addr + 0x200, dst_addr + 0x000);
	atascii_copy(src_addr + 0x300, dst_addr + 0x300);
	for(int i=0; i<8; i++) rom[dst_addr + i] = 0;
}

int main(int argc, char *argv[]) {
	load_bin("source/charset_atari.bin", 0xE000, 0);
	save_bin("binary/charset_atari.bin", 0xE000);

	load_bin("source/charset_topaz_a500.bin", 0xE000, 1);
	save_bin("binary/charset_topaz_a500.bin", 0xE000);

	load_bin("source/charset_topaz_a1200.bin", 0xE000, 1);
	save_bin("binary/charset_topaz_a1200.bin", 0xE000);

	load_bin("source/charset_topaz_plus_a500.bin", 0xE000, 1);
	save_bin("binary/charset_topaz_plus_a500.bin", 0xE000);

	load_bin("source/charset_topaz_plus_a1200.bin", 0xE000, 1);
	save_bin("binary/charset_topaz_plus_a1200.bin", 0xE000);

	load_bin("source/charset_ascrnet.bin", 0xD000, 0);
	atascii2ascii(0xD000, 0xE000);
	save_bin("binary/charset_ascrnet.bin", 0xE000);

	load_bin("source/charset_tims.bin", 0xE000, 0);
	atascii2ascii(0xD000, 0xE000);
	save_bin("binary/charset_tims.bin", 0xE000);

}
