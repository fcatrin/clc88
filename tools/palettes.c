#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[]) {
	FILE *f = fopen("../res/palettes/atari800_ntsc.txt", "rt");
	if (!f) return 1;

	char buffer[100];
	do {
		fscanf(f, "%s", buffer);
		// printf("%s", buffer);

		if (strlen(buffer) != 6) continue;

		unsigned int n = 0;
		sscanf(buffer, "%x", &n);

		int r = (n & 0xFF0000) >> 16;
		int g = (n & 0x00FF00) >>  8;
		int b = (n & 0x0000FF);

		int nr = r * 32 / 256;
		int ng = g * 64 / 256;
		int nb = b * 32 / 256;

		int rgb565 = (nr) << 11 | (ng <<5) | nb;

		printf("    .word $%04x\n", rgb565);
		printf("    .word $%04x\n", rgb565);

	} while (!feof(f));

	fclose(f);
}
