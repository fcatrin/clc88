#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <emu.h>
#include "readpng.h"

typedef struct {
    ulg width, height;
    uch *data;
} image_t;

image_t *load_image_png(FILE *f) {
    static image_t image;

    int init_result = readpng_init(f, &image.width, &image.height);
    if (!init_result) {
        fprintf(stderr, "Invalid PNG file (%d)", init_result);
        return NULL;
    }

    double LUT_exponent = 1-0;
    double CRT_exponent = 2.2;
    double display_exponent = LUT_exponent * CRT_exponent;

    int channels;
    unsigned long rowBytes;
    image.data = readpng_get_image(display_exponent, &channels, &rowBytes);

    readpng_cleanup(FALSE);
    return &image;
}

image_t *load_image_png_filename(const char *filename) {
    FILE *f;

    f = fopen(filename, "rb");
    if (!f) {
        perror("Cannot open png file");
        return NULL;
    }

    image_t *result = load_image_png(f);
    fclose(f);

    return result;
}

int main(int argc, const char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s pngfile\n", argv[0]);
        return EXIT_FAILURE;
    }
    image_t *image = load_image_png_filename(argv[1]);
    if (image==NULL) return EXIT_FAILURE;

    printf("Image size %lux%lu", image->width, image->height);
    free(image->data);

    return EXIT_SUCCESS;
}