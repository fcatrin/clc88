#include <stdio.h>
#include <string.h>

static int addr = 0;

static void dump(FILE *fout, const char *filename, int dups) {
	FILE *f = fopen(filename, "rb");
	if (!f) return;

	int c = 0;
	int line = 0;
	int skip = 1;
	while (fread(&c, 1, 1, f)){
		skip = 1 - skip;
		if (skip && dups) continue;
		fprintf(fout, "%d : %02X;\n", addr, c);
		addr++;
		if (line++ == 1023) break;
	};
	fclose(f);
}

int main(int argc, char *argv[]) {
	FILE *f = fopen("../rtl/compy/rom.mif", "wb");
	fprintf(f, "WIDTH=8;\n");
	fprintf(f, "DEPTH=1092;\n");
	fprintf(f, "\n");
	fprintf(f, "ADDRESS_RADIX=UNS;\n");
	fprintf(f, "DATA_RADIX=HEX;\n");
	fprintf(f, "\n");
	fprintf(f, "CONTENT BEGIN\n");

	// dump(f, "../res/fonts/charset_topaz_a500.bin", 1);
	// dump(f, "../res/fonts/charset_topaz_a1200.bin", 1);
	dump(f, "../res/fonts/charset_topaz_plus_a500.bin", 1);
	// dump(f, "../res/fonts/charset_topaz_plus_a1200.bin", 1);
	// dump("../res/charset_atari.bin", 0);
	dump(f, "../res/chroni_test_text.txt", 0);

	fprintf(f, "END\n");
	fclose(f);
}
