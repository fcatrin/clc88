#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[]) {
	for(int i=0; i<256; i++) {

		int r = 256-i;
		int g = (128+i)/2;
		int b = i;

		if (g<0) g = 0;
		if (b<0) b = 0;

		int nr = r * 32 / 256;
		int ng = g * 64 / 256;
		int nb = b * 32 / 256;

		int rgb565 = (nr) << 11 | (ng <<5) | nb;

		printf("    .word $%04x\n", rgb565);
		// printf("    .word $%04x\n", rgb565);

	}
}
