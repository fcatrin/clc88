#include <stdio.h>
#include <string.h>

static int addr = 0;

static void dump(const char *filename) {
	FILE *f = fopen(filename, "rb");
	if (!f) return;

	char buffer[100];
	int c;
	while (fread(&c, 1, 1, f)){
		printf("%d : %02X;\n", addr, c);
		addr++;
	};
	fclose(f);
}

int main(int argc, char *argv[]) {
	dump("../res/charset.bin");
	dump("../res/chroni_test_text.txt");
}
