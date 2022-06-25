#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <math.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <emu.h>

#define BUFFER_SIZE 0x100000

UINT8 buffer[BUFFER_SIZE];
UINT8 compressed[BUFFER_SIZE];

int index_in;
int index_out;

#define IMAGE_WIDTH  320
#define IMAGE_HEIGHT 240
#define IMAGE_BYTE_SIZE (IMAGE_WIDTH*IMAGE_HEIGHT/2)

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

INT8 get_value(int index, int nibble) {
    if (index >= 20) {
        return -1;
    }
    UINT8 data = buffer[index];
    if (nibble == 0) {
        return data & 0xf;
    } else {
        return data >> 4;
    }
}


/* Image is separated in two fields, off and even pixels
 * Each field is compressed as RLE using this format:
 * 1) if bit 7 == 0, bits 6-0 are the length of raw data following
 *    pixels are packed by nibbles
 *    Example: $1, $2, $3, $4, $5 will be written as $04, $21, $43, $05
 * 2) if bit 7 == 1, bits 6-4 are the length of equal data minus one
 *    following is the data to be repeated in bits 3-0
 *    Example $3, $3, $3, $3, $3 will be written as $d3
 */

void compress_rle(int nibble) {
    INT8 prev = get_value(index_in, nibble);
    INT8 next = get_value(index_in+1, nibble);
    if (prev != next) {
        UINT8 last = next;
        int equals = 0;
        int non_equals = 0;
        // step over random info until 3 equal nibbles are found
        for(; non_equals<120; non_equals++) {
            INT8 current = get_value(index_in + non_equals, nibble);
            if (current < 0) break;
            if (current == last) {
                equals++;
                if (equals == 3) break;
            } else {
                equals = 0;
            }
            last = current;
        }
        // transfer non-equal data
        if (equals == 3) non_equals-=equals;
        compressed[index_out++] = non_equals + 1;
        UINT8 data = 0;
        for(int i=0; i<non_equals; i++) {
            INT8 value = get_value(index_in++, nibble);
            if (i % 2 == 0) {
                data = value;
                compressed[index_out++] = value;
            } else {
                data = data | (value << 4);
                compressed[index_out-1] = data;
            }
        }
    } else {
        int equals = 0;
        for(; equals<8; equals++) {
            INT8 current = get_value(index_in + equals, nibble);
            if (current!=prev || current < 0) break;
        }
        UINT8 block = 0x80 | ((equals-1) << 4) || prev;
        compressed[index_out++] = block;
    }
}

int compress() {
    index_in = 0;
    index_out = 4;

    INT8 current;
    do {
        compress_rle(0);
        current = get_value(index_in, 0);
    } while (current >= 0);

    int last_0 = index_out;
/*
    do {
        compress_rle(1);
        current = get_value(index_in, 1);
    } while (current >= 0);
*/
    int last_1 = index_out;
    compressed[0] = last_0 & 0xff;
    compressed[1] = last_0 >> 8;
    compressed[2] = last_1 & 0xff;
    compressed[3] = last_1 >> 8;
    return last_1;
}

void dump_asm_image(char *path) {
    char file_path[2048];
    sprintf(file_path, "%s/image.asm", path);
    FILE *f = fopen(file_path, "w");

    int size = compress();

    fprintf(f, "pixel_data:");
    for(int i=0; i< size; i++) {
        UINT8 data = compressed[i];
        if ((i % 20) == 0) fprintf(f, "\n    .byte ");
        else fprintf(f, ", ");
        fprintf(f, "$%02x", data);
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
