#include <stdio.h>
#include <string.h>

static int addr = 0;

static void dump(const char *filename, int dups) {
	FILE *f = fopen(filename, "rb");
	if (!f) return;

	int c = 0;
	int line = 0;
	int skip = 1;
	while (fread(&c, 1, 1, f)){
		skip = 1 - skip;
		if (skip && dups) continue;
		printf("%d : %02X;\n", addr, c);
		addr++;
		if (line++ == 1023) break;
	};
	fclose(f);
}

int main(int argc, char *argv[]) {
	printf("WIDTH=8;\n");
	printf("DEPTH=1092;\n");
	printf("\n");
	printf("ADDRESS_RADIX=UNS;\n");
	printf("DATA_RADIX=HEX;\n");
	printf("\n");
	printf("CONTENT BEGIN\n");

	dump("../res/charset_topaz.bin", 1);
	// dump("../res/charset_atari.bin", 0);
	dump("../res/chroni_test_text.txt", 0);

	printf("END\n");
}
