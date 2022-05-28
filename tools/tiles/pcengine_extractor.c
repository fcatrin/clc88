#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <emu.h>

#define VRAM_SIZE 0x10000
#define SAT_SIZE 0x100
#define PALETTE_SIZE 0x200
#define COLOR_CODES 0x10

#define SCREEN_WIDTH  32
#define SCREEN_HEIGHT 29
#define SCREEN_SIZE (SCREEN_WIDTH * SCREEN_HEIGHT * 64)
#define SCREEN_PIXEL_WIDTH  (SCREEN_WIDTH * 8)
#define SCREEN_PIXEL_HEIGHT (SCREEN_HEIGHT * 8)

UINT16 vram[VRAM_SIZE];
UINT16 sat[SAT_SIZE];
UINT32 palette[PALETTE_SIZE];
UINT16 color[PALETTE_SIZE];

UINT32 screen[SCREEN_SIZE];

UINT32 tiles_palette_final[PALETTE_SIZE / 2];
UINT8  tiles_palette_codes[COLOR_CODES];
UINT8  tiles_palette_size;
UINT32 sprites_palette_final[PALETTE_SIZE / 2];
UINT8  sprites_palette_codes[COLOR_CODES];
UINT8  sprites_palette_size;

void init() {
    for(int i=0; i<PALETTE_SIZE / 2; i++) {
        tiles_palette_codes[i]   = 0xff;
        sprites_palette_codes[i] = 0xff;
    }
    tiles_palette_size   = 0;
    sprites_palette_size = 0;
}

UINT8 get_palette_code(int color_code, UINT8 *palette_codes, UINT8 *palette_size) {
    int size = *palette_size;

    int i = 0;
    for(; i<size; i++) {
        if (palette_codes[i] == color_code) return i;
    }

    palette_codes[size++] = color_code;
    *palette_size = size;

    return i;
}

void register_palette(UINT32 *palette_final, UINT8 *palette_codes, UINT8 *palette_size, int color_code, int palette_base) {
    UINT8 new_color_code = get_palette_code(color_code, palette_codes, palette_size);
    printf("register palette color code %02x on new color code %02x\n", color_code, new_color_code);
    for(int i=0; i<16; i++) {
        palette_final[new_color_code * 16 + i] = palette[color_code * 16 + i + palette_base];
    }
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

void save_sprite(char *out_dir, UINT16 color, UINT16 address, UINT32* tile, UINT16 cols, UINT16 rows) {
    mkdir(out_dir, 0755);

    char filename[1024];
    sprintf(filename, "%s/sprite_%04x_%02x_%dx%d.rgb", out_dir, address >> 5, color, cols, rows);
    save_rgb(filename, tile, 256*sizeof(UINT32)*cols*rows);
}

void save_screen(char *out_dir) {
    char filename[1024];
    sprintf(filename, "%s/screen.rgb", out_dir);
    save_rgb(filename, screen, SCREEN_SIZE*sizeof(UINT32));
}

UINT32 *dump_screen_tile(char *out_dir, UINT16 color, UINT16 address) {

    register_palette(tiles_palette_final, tiles_palette_codes, &tiles_palette_size, color, 0);

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
                ((plane01 & bitmask_l) ? 1 : 0) * 1 +
                ((plane01 & bitmask_h) ? 1 : 0) * 2 +
                ((plane23 & bitmask_l) ? 1 : 0) * 4 +
                ((plane23 & bitmask_h) ? 1 : 0) * 8;
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

UINT32 *dump_screen_sprite(char *out_dir, UINT16 color, UINT16 address) {
    register_palette(sprites_palette_final, sprites_palette_codes, &sprites_palette_size, color, 0x100);

    UINT8 sprite[256];
    for(int row=0; row<16; row++) {
        UINT16 sg0 = vram[address + row];
        UINT16 sg1 = vram[address + row + 16];
        UINT16 sg2 = vram[address + row + 32];
        UINT16 sg3 = vram[address + row + 48];

        UINT32 bitmask = 32768;
        for(int bit=0; bit<16; bit++) {
            sprite[row*16 + bit] =
                ((sg0 & bitmask) ? 1 : 0) * 1 +
                ((sg1 & bitmask) ? 1 : 0) * 2 +
                ((sg2 & bitmask) ? 1 : 0) * 4 +
                ((sg3 & bitmask) ? 1 : 0) * 8;
            bitmask >>= 1;
        }
    }

    static UINT32 rgb[256];
    for(int i=0; i<256; i++) {
        UINT8  pixel     = sprite[i];
        UINT32 pixel_rgb = palette[color * 16 + pixel + 0x100];
        rgb[i] = pixel == 0 ? 0 : pixel_rgb;
    }

    return rgb;
}


void screen_put_tile(int x, int y, UINT32 *tile) {
    UINT32 address = x * 8 + y * 8 * SCREEN_WIDTH * 8;
    printf("screen put %dx%d at %04x\n", x, y, address);
    for(int row = 0; row < 8; row++) {
        for(int col = 0; col < 8; col++) {
            UINT32 pixel = tile[row * 8 + col];
            screen[address + col + row * SCREEN_WIDTH*8] = pixel;
        }
    }
}

void draw(UINT32 *buffer, UINT32 *graphic, UINT16 width, UINT16 height, INT16 x, INT16 y, UINT16 buffer_width, UINT16 buffer_height) {
    int ry = y;
    for(int row = 0; row < height; row++) {
        int rx = x;
        for(int col = 0; col < width; col++) {
            if (rx < 0 || ry < 0 || rx >= buffer_width || ry > buffer_height) continue;

            UINT32 address = rx + ry * buffer_width;
            UINT32 pixel = graphic[row * width + col];
            // printf("write pixel (%d, %d) => (%d, %d) address:%d\n", col, row, rx, ry, address);
            if (pixel) buffer[address] = pixel;

            rx++;
        }
        ry++;
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
            screen_put_tile(x, y, tile);
        }
    }
}

void dump_screen_sprites(char *out_dir) {
    for(int i=0; i<64; i++) {
        UINT16 y = sat[i*4 + 0];
        UINT16 x = sat[i*4 + 1];
        UINT16 address = (sat[i*4 + 2] >> 1) & 0x3ff;
        UINT16 flags   = sat[i*4 + 3];
        UINT16 color   = flags & 0x0f;
        UINT8 cgx = (flags >> 8) & 1;
        UINT8 cgy = (flags >> 12) & 3;
        printf("sprite %04x  x:%04x y:%04x color:%02x address:%04x cgx:%x gcy:%x\n", i, x, y, color, address, cgx, cgy);
        UINT16 cols = cgx == 0 ? 1 : 2;
        UINT16 rows = cgy == 0 ? 1 : (cgy == 1 ? 2 : 4);

        if (address == 0) continue;

        int sprite_size_pixel = cols * rows * 16 * 16;
        UINT32 sprite[sprite_size_pixel];
        memset(sprite, 0, sprite_size_pixel * sizeof(UINT32));
        UINT16 data_address = address;
        for(int col = 0; col < cols; col++) {
            if (cols == 2) data_address = (data_address & 0x3fe) | col;
            for(int row = 0; row < rows; row++) {
                if (rows > 1) data_address = (data_address & 0x3f9) | (row << 1);
                UINT32 *graphic = dump_screen_sprite(out_dir, color, data_address << 6);
                draw(sprite, graphic, 16, 16, col*16, row*16, cols*16, rows*16);

                // data_address += 1;
            }
        }

        save_sprite(out_dir, color, address, sprite, cols, rows);
        draw(screen, sprite, cols*16, rows*16, x - 32, y - 64, SCREEN_PIXEL_WIDTH, SCREEN_PIXEL_HEIGHT);
    }
}

UINT16 argb2rgb565(UINT32 rgb) {
    UINT8 r = (rgb & 0x00ff0000) >> 16;
    UINT8 g = (rgb & 0x0000ff00) >> 8;
    UINT8 b = (rgb & 0x000000ff);

    r >>= 3;
    g >>= 2;
    b >>= 3;

    return (r << 11) | (g << 5) | b;
}

void dump_asm_palette(FILE *f, char *name, UINT32 *palette_final, UINT8 *palette_codes, UINT8 palette_size) {
    fprintf(f, "%s_palette_size: .byte $%02x\n", name, palette_size * 16);
    fprintf(f, "%s_palette:\n", name);
    for(int entries = 0; entries < palette_size; entries++) {
        fprintf(f, "    .word ");
        for(int i=0; i<16; i++) {
            UINT32 entry = palette_final[entries * 16 + i];
            UINT16 rgb565 = argb2rgb565(entry);

            if (i>0) fprintf(f, ", ");
            fprintf(f, "$%04x", rgb565);
        }
        fprintf(f, "\n");
    }
    fprintf(f, "\n");
}

void dump_asm_palettes(char *path) {
    char file_path[2048];
    sprintf(file_path, "%s/palette.asm", path);
    FILE *f = fopen(file_path, "w");
    dump_asm_palette(f, "tiles", tiles_palette_final,     tiles_palette_codes,   tiles_palette_size);
    dump_asm_palette(f, "sprites", sprites_palette_final, sprites_palette_codes, sprites_palette_size);
    fclose(f);
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

    init();

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
    dump_screen_sprites(path);
    save_screen(path);

    sprintf(path, "data/%s/asm", dump_dir);
    mkdir(path, 0755);

    dump_asm_palettes(path);

    return EXIT_SUCCESS;
}
