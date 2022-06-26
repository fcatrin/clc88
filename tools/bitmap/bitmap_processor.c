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
    if (index >= IMAGE_BYTE_SIZE) {
        return -1;
    }
    UINT8 data = buffer[index * 2 + nibble];
    // printf("data[%d] = %02x\n", index, data);
    return data;
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
    printf("block start %02x == %02x on index %d\n", prev, next, index_in);
    if (prev != next) {
        printf("using raw encoding...\n");
        UINT8 last = next;
        int equals = 0;
        int non_equals = 0;
        // step over random info until 3 equal nibbles are found
        for(; non_equals<8; non_equals++) {
            INT8 current = get_value(index_in + non_equals, nibble);
            printf("current = %02x on index %d\n", current, index_in + non_equals);
            if (current < 0) break;
            if (current == last) {
                equals++;
                if (equals == 2) {
                    printf("found 2 equals, stop\n");
                    break;
                }
            } else {
                equals = 0;
            }
            last = current;
        }
        // transfer non-equal data
        if (equals == 2) non_equals-=equals;
        printf("raw data length: %d\n", non_equals);
        // compressed[index_out++] = non_equals;
        // printf("compressed[%d] = %02x\n", index_out-1, non_equals);
        UINT8 data = (non_equals-1) << 4;
        index_out++;
        for(int i=0; i<non_equals; i++) {
            INT8 value = get_value(index_in++, nibble);
            printf("adding %02x from index %d\n", value, index_in-1);
            if (i % 2 == 0) {
                data = data | value;
                compressed[index_out-1] = data;
            } else {
                data = value << 4;
                compressed[index_out++] = data;
            }
            printf("compressed[%d] = %02x\n", index_out-1, data);
        }
    } else {
        printf("using length encoding...\n");
        int equals = 0;
        for(; equals<8; equals++) {
            INT8 current = get_value(index_in, nibble);
            printf("current = %02x on index %d\n", current, index_in);
            if (current!=prev || current < 0) break;
            index_in++;
        }
        printf("equals data length: %d\n", equals);
        UINT8 block = 0x80 | ((equals-1) << 4) | prev;
        compressed[index_out++] = block;
        printf("compressed[%d] = %02x\n", index_out-1, block);
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
    index_in = 0;

    do {
        compress_rle(1);
        current = get_value(index_in, 1);
    } while (current >= 0);

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
        if ((i % 16) == 0) fprintf(f, "\n    .byte ");
        else fprintf(f, ", ");
        fprintf(f, "$%02x", data);
    }
    fprintf(f, "\n");
    fclose(f);
}


UINT16 rgb2rgb565(UINT8 r, UINT8 g, UINT8 b) {

    r >>= 3;
    g >>= 2;
    b >>= 3;

    return (r << 11) | (g << 5) | b;
}

void override_palette(int index, int rgb) {
    UINT8 r = (rgb & 0x00ff0000) >> 16;
    UINT8 g = (rgb & 0x0000ff00) >> 8;
    UINT8 b = (rgb & 0x000000ff);

    int base = index*3;
    buffer[base] = r;
    buffer[base+1] = g;
    buffer[base+2] = b;
}

void override_palette_keen() {
    override_palette(0, 0x0D0D18);  // black space
    override_palette(1, 0x772925);  // robot and logo shadows
    override_palette(2, 0x2E407F);  // background behind the robot / eyes
    override_palette(3, 0x77275F);  // shirt dark
    override_palette(4, 0xA22B29);  // robot red top
    override_palette(5, 0x9B372F);  // hair dark color
    override_palette(6, 0x223067);  // dark dither on background
    override_palette(7, 0x9D2D24);  // robot light red
    override_palette(8, 0xB65E91);  // shirt highlight
    override_palette(9, 0x195F90);  // blue background
    override_palette(10, 0xB94659); // robot highlights
    override_palette(11, 0xDBAC7A); // face shadows
    override_palette(12, 0x739939); // helmet bars
    override_palette(13, 0xB76994); // robot buttons highlights
    override_palette(14, 0xFDB933); // main helmet color
    override_palette(15, 0xE6DBBA); // face
}

void dump_asm_palette(char *path) {
    char file_path[2048];
    sprintf(file_path, "%s/palette.asm", path);
    printf("out %s\n", file_path);
    FILE *f = fopen(file_path, "w");

    // override_palette_keen();

    fprintf(f, "palette:");
    for(int i=0; i < 16; i++) {
        UINT8 data_r = buffer[i*3];
        UINT8 data_g = buffer[i*3+1];
        UINT8 data_b = buffer[i*3+2];
        UINT16 value = rgb2rgb565(data_r, data_g, data_b);

        if ((i % 8) == 0) fprintf(f, "\n    .word ");
        else fprintf(f, ", ");
        fprintf(f, "$%04x", value);
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

    sprintf(path, "input/%s.pal", image_name);
    if (!load_bin(path, buffer, sizeof(buffer))) return EXIT_FAILURE;

    sprintf(path, "output/%s", image_name);
    dump_asm_palette(path);

    return EXIT_SUCCESS;
}
