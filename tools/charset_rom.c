#include <stdio.h>
#include <string.h>
#include <ctype.h>

static int addr = 0;

static int to_printable_char(char c);
static char *to_printable_pixels(int c);

static void dump(FILE *fout, const char *filename, int dups, int is_font) {
	FILE *f = fopen(filename, "rb");
	if (!f) return;

	int c = 0;
	int line = 0;
	int skip = 1;
	while (fread(&c, 1, 1, f)){
		skip = 1 - skip;
		if (skip && dups) continue;

		char comment[200];
		if (is_font) {
			sprintf(comment, "%s", to_printable_pixels(c));
		} else {
			sprintf(comment, "%c", to_printable_char(c));
		}

		fprintf(fout, "%d : %02X; -- %s\n", addr, c, comment);

		addr++;
		if (line++ == 1023) break;
	};
	fclose(f);
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

int main(int argc, char *argv[]) {
	FILE *f = fopen("../rtl/compy/rom.mif", "wb");
	fprintf(f, "WIDTH=8;\n");
	fprintf(f, "DEPTH=1098;\n");
	fprintf(f, "\n");
	fprintf(f, "ADDRESS_RADIX=UNS;\n");
	fprintf(f, "DATA_RADIX=HEX;\n");
	fprintf(f, "\n");
	fprintf(f, "CONTENT BEGIN\n");

	// dump(f, "../res/fonts/charset_topaz_a500.bin", 1);
	// dump(f, "../res/fonts/charset_topaz_a1200.bin", 1);
	dump(f, "../res/fonts/charset_topaz_plus_a500.bin", 1, 1);
	// dump(f, "../res/fonts/charset_topaz_plus_a1200.bin", 1);
	// dump("../res/charset_atari.bin", 0);
	dump(f, "../res/chroni_test_text.txt", 0, 0);
	dump(f, "../res/boot_code.bin", 0, 0);

	fprintf(f, "END\n");
	fclose(f);
}
