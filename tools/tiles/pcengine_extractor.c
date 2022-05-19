#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <emu.h>

#define VRAM_SIZE 0x10000
#define SAT_SIZE 0x100
#define PALETTE_SIZE 0x200

UINT16 vram[VRAM_SIZE];
UINT16 sat[SAT_SIZE];
UINT32 palette[PALETTE_SIZE];

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

void save_tile(int tile_index, UINT16 color, UINT8* tile) {
    UINT32 rgb[64];
    for(int i=0; i<16; i++) {
        printf("palette index %04x = %08x\n", color*16 +i, palette[color * 16 + i]);
    }

    for(int i=0; i<32; i++) {
        UINT8 pixel_0 = tile[i*2 + 0];
        UINT8 pixel_1 = tile[i*2 + 1];
        printf("tile:%02x pixel:%02x px0:%02x px1:%02x\n", tile_index, i, pixel_0, pixel_1);

        UINT32 rgb_0 = palette[color * 16 + pixel_0];
        UINT32 rgb_1 = palette[color * 16 + pixel_1];
        printf("tile:%02x pixel:%02x rgb0:%08x rgb1:%08x pal_index_0:%04x pal_index_1:%04x\n", tile_index, i, rgb_0, rgb_1,
        color * 16 + pixel_0,
        color * 16 + pixel_1
        );
        rgb[i*2 + 0] = rgb_0;
        rgb[i*2 + 1] = rgb_1;
    }

    char filename[1024];
    sprintf(filename, "data/tile_%04x.rgb", tile_index);
    FILE *f = fopen(filename, "wb");
    fwrite(rgb, sizeof(rgb), 1, f);
    fclose(f);
}

void dump_screen_tile(int tile_index, UINT16 color, UINT16 address) {
    UINT8 tile[64];
    printf("dump_screen_tile %02x color:%02x address:%04x\n", tile_index, color, address);
    for(int row=0; row<8; row++) {
        UINT16 plane01 = vram[address + row];
        UINT16 plane23 = vram[address + row + 8];
        printf("  row %d plane01:%04x plane02:%04x\n", row, plane01, plane23);

        UINT16 bitmask_h = 128 << 8;
        UINT16 bitmask_l = 128;
        for(int bit=0; bit<8; bit++) {
            tile[row*8 + bit] =
                ((plane01 & bitmask_h) ? 1 : 0) * 8 +
                ((plane01 & bitmask_l) ? 1 : 0) * 4 +
                ((plane23 & bitmask_h) ? 1 : 0) * 2 +
                ((plane23 & bitmask_l) ? 1 : 0) * 1;
            printf("    tile row:%d bit:%d = %02x bm_h:%04x bm_l:%04x\n", row, bit, tile[row*8 + bit], bitmask_h, bitmask_l);
            bitmask_h >>= 1;
            bitmask_l >>= 1;
        }
    }

    save_tile(tile_index, color, tile);
}

void dump_screen_tiles() {
    for(int i=0; i<3; i++) {
        UINT16 bat_value = vram[i];
        UINT16 color   = bat_value >> 12;
        UINT16 address = (bat_value & 0xFFF) << 4;
        dump_screen_tile(i, color, address);
    }
}

void fix_palette() {
    for(int i=0; i<PALETTE_SIZE; i++) {
        UINT32 entry = palette[i];
        UINT32 fixed = 0xff000000 |
            (entry & 0x0000ff) << 16 |
            (entry & 0x00ff00) |
            (entry & 0xff0000) >> 16;
        palette[i] = fixed;
    }
}

int main(int argc, const char *argv[]) {
    if (argc < 4) {
        printf("Usage: %s vram.bin sat.bin color_table.bin\n", argv[0]);
        return EXIT_FAILURE;
    }
    if (!load_bin(argv[1], vram, sizeof(vram))) return EXIT_FAILURE;
    if (!load_bin(argv[2], sat, sizeof(sat))) return EXIT_FAILURE;
    if (!load_bin(argv[3], palette, sizeof(palette))) return EXIT_FAILURE;

    fix_palette();

    for(int i = 0; i<PALETTE_SIZE; i++) {
        printf("palette[%04x] = %08x\n", i, palette[i]);
    }

    dump_screen_tiles();

    return EXIT_SUCCESS;
}
