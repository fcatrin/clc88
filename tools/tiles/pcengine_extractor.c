#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <emu.h>

#define VRAM_SIZE 0x10000
#define SAT_SIZE 0x100
#define PALETTE_SIZE 0x200

#define SCREEN_WIDTH  32
#define SCREEN_HEIGHT 29
#define SCREEN_SIZE (SCREEN_WIDTH * SCREEN_HEIGHT * 64)

UINT16 vram[VRAM_SIZE];
UINT16 sat[SAT_SIZE];
UINT32 palette[PALETTE_SIZE];
UINT16 color[PALETTE_SIZE];

UINT32 screen[SCREEN_SIZE];

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

void save_rgb(char *filename, UINT32* rgb, size_t size) {
    FILE *f = fopen(filename, "wb");
    fwrite(rgb, size, 1, f);
    fclose(f);
}

void save_tile(char *out_dir, UINT16 color, UINT16 address, UINT32* tile) {
    mkdir(out_dir, 0755);

    char filename[1024];
    sprintf(filename, "%s/tile_%04x_%02x.rgb", out_dir, address >> 4, color);
    save_rgb(filename, tile, 64*sizeof(UINT32));
}

void save_screen(char *out_dir) {
    char filename[1024];
    sprintf(filename, "%s/screen.rgb", out_dir);
    save_rgb(filename, screen, SCREEN_SIZE*sizeof(UINT32));
}

UINT32 *dump_screen_tile(char *out_dir, UINT16 color, UINT16 address) {
    UINT8 tile[64];
    printf("dump_screen_tile color:%02x address:%04x\n", color, address);
    for(int row=0; row<8; row++) {
        UINT16 plane01 = vram[address + row];
        UINT16 plane23 = vram[address + row + 8];
        printf("  row %d plane01: %04x plane23: %04x\n", row, plane01, plane23);

        UINT16 bitmask_h = 128 << 8;
        UINT16 bitmask_l = 128;
        for(int bit=0; bit<8; bit++) {
            tile[row*8 + bit] =
                ((plane01 & bitmask_h) ? 1 : 0) * 1 +
                ((plane01 & bitmask_l) ? 1 : 0) * 2 +
                ((plane23 & bitmask_h) ? 1 : 0) * 4 +
                ((plane23 & bitmask_l) ? 1 : 0) * 8;
            printf("    tile row:%d bit:%d = %02x bm_h:%04x bm_l:%04x\n", row, bit, tile[row*8 + bit], bitmask_h, bitmask_l);
            bitmask_h >>= 1;
            bitmask_l >>= 1;
        }
    }

    static UINT32 rgb[64];
    for(int i=0; i<16; i++) {
        printf("palette index %04x = %08x\n", color*16 +i, palette[color * 16 + i]);
    }

    for(int i=0; i<32; i++) {
        UINT8 pixel_0 = tile[i*2 + 0];
        UINT8 pixel_1 = tile[i*2 + 1];
        printf("tile:%04x pixel:%02x px0:%02x px1:%02x\n", address >> 4, i, pixel_0, pixel_1);

        UINT32 rgb_0 = palette[color * 16 + pixel_0];
        UINT32 rgb_1 = palette[color * 16 + pixel_1];
        printf("tile:%04x pixel:%02x rgb0:%08x rgb1:%08x pal_index_0:%04x pal_index_1:%04x\n", address >> 4, i, rgb_0, rgb_1,
        color * 16 + pixel_0,
        color * 16 + pixel_1
        );
        rgb[i*2 + 0] = rgb_0;
        rgb[i*2 + 1] = rgb_1;
    }

    return rgb;
}

void screen_put(int x, int y, UINT32 *tile) {
    UINT32 address = x * 8 + y * 8 * SCREEN_WIDTH * 8;
    printf("screen put %dx%d at %04x\n", x, y, address);
    for(int row = 0; row < 8; row++) {
        for(int col = 0; col < 8; col++) {
            UINT32 pixel = tile[row * 8 + col];
            screen[address + col + row * SCREEN_WIDTH*8] = pixel;
        }
    }
}

void dump_screen_tiles(char *out_dir) {
    for(int y=0; y<SCREEN_HEIGHT; y++) {
        for(int x=0; x<SCREEN_WIDTH; x++) {
            UINT16 bat_value = vram[x + y*SCREEN_WIDTH*2];
            UINT16 color   = bat_value >> 12;
            UINT16 address = (bat_value & 0xFFF) << 4;

            UINT32 *tile = dump_screen_tile(out_dir, color, address);
            save_tile(out_dir, color, address, tile);
            screen_put(x, y, tile);
        }
    }
}

void fix_palette() {
    for(int i=0; i<PALETTE_SIZE; i++) {
        UINT16 entry = color[i];
        UINT16 blue  = 36 * (entry  & 0x007);
        UINT16 red   = 36 * ((entry & 0x038) >> 3);
        UINT16 green = 36 * ((entry & 0x1c0) >> 6);

        UINT32 fixed = 0xff000000 |
            blue  << 16 |
            green << 8 |
            red   << 0;
        palette[i] = fixed;
    }
}

int main(int argc, const char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s dump_name\n", argv[0]);
        return EXIT_FAILURE;
    }

    const char *dump_dir = argv[1];
    char path[1024];

    sprintf(path, "data/%s/vram.bin", dump_dir);
    if (!load_bin(path, vram, sizeof(vram))) return EXIT_FAILURE;

    sprintf(path, "data/%s/sat.bin", dump_dir);
    if (!load_bin(path, sat, sizeof(sat))) return EXIT_FAILURE;

    sprintf(path, "data/%s/color.bin", dump_dir);
    if (!load_bin(path, color, sizeof(color))) return EXIT_FAILURE;

    fix_palette();

    for(int i = 0; i<PALETTE_SIZE; i++) {
        printf("palette[%04x] = %08x\n", i, palette[i]);
    }

    sprintf(path, "data/%s/tiles", dump_dir);
    mkdir(path, 0755);
    dump_screen_tiles(path);
    save_screen(path);

    return EXIT_SUCCESS;
}
