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

size_t image_size;
size_t palette_size;

void init() {
}

bool load_bin(const char *filename, void *data, size_t size, size_t *size_read) {

    FILE *f = fopen(filename, "rb");
    if (!f) {
        char error_message[4096];
        sprintf(error_message, "Cannot open %s", filename);
        perror(error_message);
        return FALSE;
    }

    *size_read = fread(data, 1, size, f);
    printf("%lu bytes read\n", *size_read);
    fclose(f);
    return TRUE;
}

INT16 get_value(int index, int field) {
    if (index*2 >= image_size) {
        return -1;
    }
    INT8 data = buffer[index * 2 + field];
    INT16 result = data < 0 ? (data+256) : data;
    return result;
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

void compress_rle16(int field) {
    INT8 prev = get_value(index_in, field);
    INT8 next = get_value(index_in+1, field);
    printf("block start %02x == %02x on index %d\n", prev, next, index_in);
    if (prev != next) {
        printf("using raw encoding...\n");
        UINT8 last = next;
        int equals = 0;
        int non_equals = 0;
        // step over random info until 3 equal nibbles are found
        for(; non_equals<8; non_equals++) {
            INT8 current = get_value(index_in + non_equals, field);
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
            INT8 value = get_value(index_in++, field);
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
            INT8 current = get_value(index_in, field);
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

/* Image is separated in two fields, off and even pixels
 * Each field is compressed as RLE using this format:
 * 1) if bit 7 == 0, bits 6-0 are the length of raw data following minus one
 * 2) if bit 7 == 1, bits 6-0 are the length of repeated data minus one
 *    following is the data to be repeated
 *    Example $23, $23, $23, $23, $23 will be written as $1423
 */


void compress_rle256(int field) {
    INT16 prev = get_value(index_in, field);
    INT16 next = get_value(index_in+1, field);
    printf("block start %02x == %02x on index %d\n", prev, next, index_in);
    if (prev != next) {
        printf("using raw encoding...\n");
        INT16 last = next;
        int equals = 0;
        int non_equals = 0;
        // step over random info until 3 equal nibbles are found
        for(; non_equals<128; non_equals++) {
            INT16 current = get_value(index_in + non_equals, field);
            printf("current = %02x on index %d\n", current, index_in + non_equals);
            if (current < 0) break;
            if (current == last) {
                equals++;
                if (equals == 3) {
                    printf("found 3 equals, stop\n");
                    break;
                }
            } else {
                equals = 0;
            }
            last = current;
        }
        // transfer non-equal data
        if (equals == 3) non_equals-=equals;
        printf("raw data length: %d\n", non_equals);
        // compressed[index_out++] = non_equals;
        // printf("compressed[%d] = %02x\n", index_out-1, non_equals);
        UINT8 data = non_equals-1;
        compressed[index_out++] = data;
        for(int i=0; i<non_equals; i++) {
            INT16 value = get_value(index_in++, field);
            compressed[index_out++] = value;
            printf("compressed[%d] = %02x\n", index_out-1, value);
        }
    } else {
        printf("using length encoding...\n");
        int equals = 0;
        for(; equals<128; equals++) {
            INT16 current = get_value(index_in, field);
            printf("current = %02x on index %d\n", current, index_in);
            if (current!=prev || current < 0) break;
            index_in++;
        }
        printf("equals data length: %d\n", equals);
        INT16 block = 0x80 | (equals-1);
        compressed[index_out++] = block;
        compressed[index_out++] = prev;
        printf("compressed[%d] = %02x\n", index_out-2, block);
        printf("compressed[%d] = %02x\n", index_out-1, prev);
    }
}


int compress(int colors) {
    index_in = 0;
    index_out = 4;

    INT16 current;
    do {
        if (colors == 16) compress_rle16(0);
        else compress_rle256(0);
        current = get_value(index_in, 0);
    } while (current >= 0);

    int last_0 = index_out;
    index_in = 0;

    do {
        if (colors == 16) compress_rle16(1);
        else compress_rle256(1);
        current = get_value(index_in, 1);
    } while (current >= 0);

    // write header
    int last_1 = index_out;
    compressed[0] = last_0 & 0xff; // size of field 0
    compressed[1] = last_0 >> 8;
    compressed[2] = last_1 & 0xff; // size of field 1
    compressed[3] = last_1 >> 8;
    return last_1;
}

void dump_asm_image(char *path, int colors) {
    char file_path[2048];
    sprintf(file_path, "%s/image.asm", path);
    FILE *f = fopen(file_path, "w");

    int size = compress(colors);

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

int debug_lines = 5;

void dump_bin_image(char *path, int colors) {
    char file_path[2048];
    sprintf(file_path, "%s/image.bin", path);
    FILE *f = fopen(file_path, "w");

    if (colors == 256) {
        fwrite(buffer, 1, image_size, f);
    } else {
        for(int i=0; i<image_size; i+=2) {
            UINT8 value = (buffer[i+1] << 4) | buffer[i];
            compressed[i/2] = value;
        }
        fwrite(compressed, 1, image_size/2, f);
    }

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

void dump_asm_palette(char *path, int colors) {
    char file_path[2048];
    sprintf(file_path, "%s/palette.asm", path);
    printf("out %s\n", file_path);
    FILE *f = fopen(file_path, "w");

    // override_palette_keen();

    fprintf(f, "palette:");
    for(int i=0; i < colors; i++) {
        UINT8 data_r = buffer[i*3];
        UINT8 data_g = buffer[i*3+1];
        UINT8 data_b = buffer[i*3+2];
        UINT16 value = rgb2rgb565(data_r, data_g, data_b);

        if ((i % 16) == 0) fprintf(f, "\n    .word ");
        else fprintf(f, ", ");
        fprintf(f, "$%04x", value);
    }
    fprintf(f, "\n");
    fclose(f);
}

void dump_bin_palette(char *path, int colors) {
    char file_path[2048];
    sprintf(file_path, "%s/palette.bin", path);
    printf("out %s\n", file_path);
    FILE *f = fopen(file_path, "w");

    for(int i=0; i < colors; i++) {
        UINT8 data_r = buffer[i*3];
        UINT8 data_g = buffer[i*3+1];
        UINT8 data_b = buffer[i*3+2];
        UINT16 value = rgb2rgb565(data_r, data_g, data_b);
        fwrite(&value, 1, sizeof(UINT16), f);
    }
    fclose(f);
}

int main(int argc, const char *argv[]) {
    if (argc < 3) {
        printf("Usage: %s 16|256 image_name\n", argv[0]);
        return EXIT_FAILURE;
    }

    init();

    char path[1024];
    const char *image_name = argv[2];
    int colors = atoi(argv[1]);
    if (colors != 16 && colors != 256) {
        printf("Invalid number of colors. Must be 16 or 256");
        return EXIT_FAILURE;
    }

    sprintf(path, "input/%s", image_name);
    if (!load_bin(path, buffer, sizeof(buffer), &image_size)) return EXIT_FAILURE;

    sprintf(path, "output/%s", image_name);
    printf("mkdir %s\n", path);
    mkdir(path, 0755);

    dump_asm_image(path, colors);
    dump_bin_image(path, colors);

    sprintf(path, "input/%s.pal", image_name);
    if (!load_bin(path, buffer, sizeof(buffer), &palette_size)) return EXIT_FAILURE;

    sprintf(path, "output/%s", image_name);
    dump_asm_palette(path, colors);
    dump_bin_palette(path, colors);


    return EXIT_SUCCESS;
}
