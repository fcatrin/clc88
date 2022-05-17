#include "stdio.h"
#include "errno.h"
#include "png.h"
#include "emu.h"

bool load_image_png(const char *filename) {
    FILE *f;
    int width, height;

    f = fopen(filename, "rb");
    if (!f) {
        perror("Cannot open png file");
        return FALSE;
    }

    UINT8 sig[8];

    fread(sig, 1, 8, f);
    if (!png_check_sig(sig, 8)) {
        fprintf(stderr, "Not a PNG image\n");
        return FALSE;
    }

    return TRUE;
}

int main(int argc, const char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s pngfile\n", argv[0]);
        return 0;
    }
    load_image_png(argv[1]);
    return 1;
}