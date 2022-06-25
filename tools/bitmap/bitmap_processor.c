#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <math.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <emu.h>

#define BUFFER_SIZE 0x100000

UINT16 buffer[BUFFER_SIZE];

UINT16 image_width  = 320;
UINT16 image_height = 200;

void init() {
}

bool load_bin(const char *filename, void *data, size_t size) {

    FILE *f = fopen(filename, "rb");
    if (!f) {
        char error_message[4096];
        sprintf(error_message, "Cannot open %s", filename);
        perror(error_message);
        return FALSE;
    }

    fread(data, size, 1, f);
    fclose(f);
    return TRUE;
}

void dump_asm_image(char *path) {
    char file_path[2048];
    sprintf(file_path, "%s/image.asm", path);
    FILE *f = fopen(file_path, "w");

    int pitch = image_width / 2;

    fprintf(f, "pixel_data_size:\n    .word $%04x\n", pitch * image_height);
    fprintf(f, "pixel_data:\n");
    for(int y = 0; y < image_height; y++) {
        for(int x = 0; x < pitch ; x++) {
            UINT16 pixel_data_src = buffer[x + y * pitch];
            UINT8  pixel_data = ((pixel_data_src & 0xf00) >> 4) | (pixel_data_src & 0xf);


            if ((x % 20) == 0) fprintf(f, "\n    .byte ");
            else if (x>0) fprintf(f, ", ");
            fprintf(f, "$%02x", pixel_data);
        }
        fprintf(f, " // row %d\n", y);
    }
    fprintf(f, "\n");
    fclose(f);
}

int main(int argc, const char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s image_name\n", argv[0]);
        return EXIT_FAILURE;
    }

    init();

    char path[1024];
    const char *image_name = argv[1];

    sprintf(path, "input/%s", image_name);
    if (!load_bin(path, buffer, sizeof(buffer))) return EXIT_FAILURE;

    sprintf(path, "output/%s", image_name);
    printf("mkdir %s", path);
    mkdir(path, 0755);

    dump_asm_image(path);

    return EXIT_SUCCESS;
}
