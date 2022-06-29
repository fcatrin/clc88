#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "emu.h"
#include "cpu.h"
#include "cpuexec.h"
#include "screen.h"
#include "chroni.h"

#define LOGTAG "CHRONI"
#ifdef TRACE_CHRONI
#define TRACE
#endif
#include "trace.h"

#define BYTE_L(word) ((word) & 0xff)
#define BYTE_H(word) ((word) >> 8)
#define VRAM_PTR(addr)  ((VRAM_BYTE(addr) + (VRAM_BYTE(addr+1) << 8)) << 1)
#define VRAM_DATA(addr) (vram[(addr) & 0xFFFF])
#define VRAM_BYTE(addr) (((addr) & 1 ? (VRAM_DATA((addr)>>1) >> 8) : VRAM_DATA((addr)>>1)) & 0xff)

#define VRAM_MAX 64*1024
#define PALETTE_SIZE 256

UINT16 vram[VRAM_MAX];
UINT16 palette[PALETTE_SIZE];

#define PAGE_SIZE       0x4000
#define PAGE_SHIFT      14
#define PAGE_SHIFT_HIGH (PAGE_SHIFT-8)
#define PAGE_BASE(x)    (x << PAGE_SHIFT)

static UINT32 vram_write_address;
static UINT32 vram_write_address_aux;

static UINT16 scanline_interrupt;
static UINT32 offset;

static UINT16 dl;
static UINT16 lms = 0;
static UINT16 attribs = 0;
static UINT16 ypos, xpos, memscan;

UINT16 dl_pos;
UINT16 dl_scanlines;
UINT16 dl_mode_scanlines;
UINT8  dl_mode_scanline;
UINT16 dl_mode_pitch;
UINT16 dl_instruction;
UINT8  dl_mode;
bool   dl_narrow;
bool   dl_scroll;

UINT16 dl_mode_data_addr;
UINT16 dl_mode_attr_addr;
UINT16 dl_row_wrap;

UINT8 dl_scroll_width;
UINT8 dl_scroll_height;
UINT8 dl_scroll_left;
UINT8 dl_scroll_top;
UINT8 dl_scroll_fine_x;
UINT8 dl_scroll_fine_y;

static UINT16 border_color;

#define CHARSET_PAGE 1024
static UINT8  charset;
static UINT16 sprites;

// this is an RGB565 -> RGB888 conversion array for emulation only
static UINT8 rgb565[0x10000 * 3];
static UINT8 pixel_color_r;
static UINT8 pixel_color_g;
static UINT8 pixel_color_b;

#define AUTOINC_VADDR_KEEP 0x00
#define AUTOINC_VADDR_INC  0x01
#define AUTOINC_VADDR_DEC  0x03
#define AUTOINC_VADDR_AUX_KEEP 0x00
#define AUTOINC_VADDR_AUX_INC  0x04
#define AUTOINC_VADDR_AUX_DEC  0x0C
#define AUTOINC_KEEP  (AUTOINC_VADDR_KEEP | AUTOINC_VADDR_AUX_KEEP)
#define AUTOINC_INC   (AUTOINC_VADDR_INC | AUTOINC_VADDR_AUX_INC)
#define AUTOINC_DEC   (AUTOINC_VADDR_DEC | AUTOINC_VADDR_AUX_DEC)

static UINT8 status;
static UINT8 autoinc;

static UINT8 clock_multiplier;
static UINT8 clock_multipliers[] = {1, 2, 4, 8};

static int debug_skip_frames = 20;

static void do_scanline(UINT16 width);
static void process_dl();

void chroni_reset() {
    status = 0;
    dl = 0;
    charset = 0;
    sprites = 0;
    scanline_interrupt = 0;
    clock_multiplier = clock_multipliers[0];

    autoinc = AUTOINC_INC;

    srand(time(NULL));
}

UINT16 chroni_vram_read(UINT16 addr) {
    return VRAM_DATA(addr);
}

UINT16 *chroni_registers_read() {
    static UINT16 registers[8];
    registers[0] = dl;
    registers[1] = lms;
    registers[2] = attribs;
    registers[3] = vram_write_address >> 1;
    registers[4] = vram_write_address_aux >> 1;
    registers[5] = ((vram_write_address & 1) << 8 ) | (vram_write_address_aux & 1);
    registers[6] = status;
    registers[7] = charset << 9;
    return registers;
}

static void reg_low(UINT16 *reg, UINT8 value) {
    *reg = (*reg & 0xFF00) | (value);
}

static void reg_high(UINT16 *reg, UINT8 value) {
    *reg = (*reg & 0x00FF) | (value << 8);
}

void vaddr_autoinc() {
    if (autoinc & AUTOINC_VADDR_INC) {
        vram_write_address++;
    } else if (autoinc & AUTOINC_VADDR_DEC) {
        vram_write_address--;
    }
    vram_write_address = vram_write_address & 0x1FFFF;
}

void vaddr_aux_autoinc() {
    if (autoinc & AUTOINC_VADDR_AUX_INC) {
        vram_write_address_aux++;
    } else if (autoinc & AUTOINC_VADDR_AUX_DEC) {
        vram_write_address_aux--;
    }
    vram_write_address_aux = vram_write_address_aux & 0x1FFFF;
}

void chroni_register_write(UINT8 index, UINT8 value) {
    static int    palette_value_state;
    static UINT8  palette_index;
    static UINT16 palette_value;

    UINT16 current_value;

    LOGV(LOGTAG, "chroni reg write: 0x%04X = 0x%02X", index, value);
    switch (index) {
    case 0x00:
        reg_low(&dl, value);
        break;
    case 0x01:
        reg_high(&dl, value);
        break;
    case 0x02:
        charset = value;
        break;
    case 0x04:
        palette_index = value;
        palette_value_state = 0;
        break;
    case 0x05:
        if (palette_value_state == 0) {
            palette_value = (palette_value & 0xFF00) | value;
            palette_value_state = 1;
        } else {
            palette_value = (palette_value & 0x00FF) | (value << 8);

            palette[palette_index++] = palette_value;
            palette_value_state = 0;
        }
        break;
    case 0x06:
        vram_write_address = (vram_write_address & 0x1FE00) | (value << 1);
        break;
    case 0x07:
        vram_write_address = (vram_write_address & 0x001FF) | (value << 9);
        break;
    case 0x08:
        vram_write_address_aux = (vram_write_address_aux & 0x1FE00) | (value << 1);
        break;
    case 0x09:
        vram_write_address_aux = (vram_write_address_aux & 0x001FF) | (value << 9);
        break;
    case 0x0a:
        current_value = vram[vram_write_address>>1];
        vram[vram_write_address>>1] = (vram_write_address & 1) ?
                ((current_value & 0x00ff) | ((value & 0xff) << 8)) :
                ((current_value & 0xff00) | (value & 0xff));
        vaddr_autoinc();
        break;
    case 0x0b:
        current_value = vram[vram_write_address_aux>>1];
        vram[vram_write_address_aux>>1] = (vram_write_address_aux & 1) ?
                ((current_value & 0x00ff) | ((value & 0xff) << 8)) :
                ((current_value & 0xff00) | (value & 0xff));
        vaddr_aux_autoinc();
        break;
    case 0x11:
        CPU_HALT();
        break;
    case 0x12:
        status = (status & 0xC0) | (value & 0x3F);
        break;
    case 0x14:
        reg_low(&sprites, value);
        break;
    case 0x15:
        reg_high(&sprites, value);
        break;
    case 0x1a:
        reg_low(&border_color, value);
        break;
    case 0x1b:
        reg_high(&border_color, value);
        break;
    case 0x22:
        reg_low(&scanline_interrupt, value);
        break;
    case 0x23:
        reg_high(&scanline_interrupt, value);
        break;
    case 0x24:
        clock_multiplier = clock_multipliers[value & 0x03];
        break;
    case 0x26:
        vram_write_address = (vram_write_address & 0x1FF00) | value;
        break;
    case 0x27:
        vram_write_address = (vram_write_address & 0x100FF) | (value << 8);
        break;
    case 0x28:
        vram_write_address = (vram_write_address & 0x0FFFF) | ((value & 1) << 16);
        break;
    case 0x2a:
        vram_write_address_aux = (vram_write_address_aux & 0x1FF00) | value;
        break;
    case 0x2b:
        vram_write_address_aux = (vram_write_address_aux & 0x100FF) | (value << 8);
        break;
    case 0x2c:
        vram_write_address_aux = (vram_write_address_aux & 0x0FFFF) | ((value & 1) << 16);
        break;
    case 0x2e:
        autoinc = value;
        break;
    }
}

UINT8 chroni_register_read(UINT8 index) {
	switch(index) {
    case 0x06 : return ((vram_write_address+1) & 0x001FF) >> 1;
    case 0x07 : return ((vram_write_address+1) & 0x01E00) >> (8+1);
    case 0x08 : return ((vram_write_address_aux+1) & 0x001FF) >> 1;
    case 0x09 : return ((vram_write_address_aux+1) & 0x01E00) >> (8+1);
    case 0x0a : {
        UINT8 value = VRAM_BYTE(vram_write_address);
        vaddr_autoinc();
        return value;
    }
    case 0x0b : {
        UINT8 value = VRAM_BYTE(vram_write_address_aux);
        vaddr_aux_autoinc();
        return value;
    }
    case 0x10 : return ypos;
    case 0x1a : return (border_color & 0x00ff);
    case 0x1b : return border_color >> 8;
    case 0x12 : return status | STATUS_IS_EMULATOR;
    case 0x25 : return rand() & 0xFF;
    case 0x26 : return (vram_write_address & 0x000FF);
    case 0x27 : return (vram_write_address & 0x0FF00) >> 8;
    case 0x28 : return (vram_write_address & 0x10000) >> 16;
    case 0x2a : return (vram_write_address_aux & 0x000FF);
    case 0x2b : return (vram_write_address_aux & 0x0FF00) >> 8;
    case 0x2c : return (vram_write_address_aux & 0x10000) >> 16;
    case 0x2e : return autoinc;
    }
    return 0;
}


static inline void set_pixel_color_rgb(UINT16 pixel_color_rgb565) {
    pixel_color_r = rgb565[pixel_color_rgb565*3 + 0];
    pixel_color_g = rgb565[pixel_color_rgb565*3 + 1];
    pixel_color_b = rgb565[pixel_color_rgb565*3 + 2];
}

static inline void set_pixel_color(UINT8 color) {
    UINT16 pixel_color_rgb565 = palette[color];
    set_pixel_color_rgb(pixel_color_rgb565);
}

#define SPRITE_ATTR_ENABLED 0x10
#define SPRITE_SCAN_INVALID 0xFF

#define SPRITES_MAX   32
#define SPRITES_X     (SPRITES_MAX * 2)
#define SPRITES_Y     (SPRITES_MAX * 2 + SPRITES_X)
#define SPRITES_ATTR  (SPRITES_MAX * 2 + SPRITES_Y)
#define SPRITES_COLOR (SPRITES_MAX * 2 + SPRITES_ATTR)

static UINT8 sprite_scanlines[SPRITES_MAX];

static void do_scan_start() {
    /*
    * check all sprites and write the scan to be drawn
    * assume that the sprite will not be drawn
    */
    for(int s=0; s < SPRITES_MAX; s++) {
        sprite_scanlines[s] = SPRITE_SCAN_INVALID; // assume invalid sprite for this scan
        if (!(status & STATUS_ENABLE_SPRITES)) continue;

        UINT16 sprite_attrib = VRAM_BYTE(sprites + SPRITES_ATTR + s*2);
        if ((sprite_attrib & SPRITE_ATTR_ENABLED) == 0) continue;

        int sprite_y = VRAM_DATA(sprites + SPRITES_Y + s*2) - 16;

        int sprite_scanline = ypos - sprite_y;
        if (sprite_scanline< 0 || sprite_scanline >=16) continue;
        sprite_scanlines[s] = sprite_scanline;
    }
}

static void do_scan_end() {}

static inline PAIR do_sprites() {
    UINT8 dot_color   = 0;
    UINT8 sprite_data = 0;
    for(int s=SPRITES_MAX-1; s>=0 && (status & STATUS_ENABLE_SPRITES); s--) {
        UINT8 sprite_scanline = sprite_scanlines[s];
        if (sprite_scanline == SPRITE_SCAN_INVALID) continue;

        int sprite_x = (VRAM_DATA(sprites + SPRITES_X + s*2) - 24) * 2;

        int sprite_pixel_x = xpos/2 - sprite_x;
        if (sprite_pixel_x < 0) continue; // not yet
        if (sprite_pixel_x >=16) { // not anymore
            sprite_scanlines[s] = SPRITE_SCAN_INVALID;
            continue;
        }

        int sprite_pointer = VRAM_PTR(sprites + s*2);

        sprite_data = VRAM_BYTE(sprite_pointer
                        + (sprite_scanline << 3)
                        + (sprite_pixel_x  >> 1));
        sprite_data = (sprite_pixel_x & 1) == 0 ?
        sprite_data >> 4 :
        sprite_data & 0xF;
        if (sprite_data == 0) continue;

        UINT16 sprite_attrib = VRAM_BYTE(sprites + SPRITES_ATTR + s*2);
        int sprite_palette = sprite_attrib & 0x0F;

        dot_color = VRAM_BYTE(sprites + SPRITES_COLOR + sprite_palette*16 + sprite_data);
        break;
    }

    PAIR result;
    result.b.l = dot_color;
    result.b.h = sprite_data;
    return result;
}

static void inline put_pixel(int offset, UINT8 color) {
    PAIR sprite = do_sprites();
    UINT8 dot_color = sprite.b.h == 0 ? color : sprite.b.l;

    set_pixel_color(dot_color);
    screen[offset + xpos*3 + 0] = pixel_color_r;
    screen[offset + xpos*3 + 1] = pixel_color_g;
    screen[offset + xpos*3 + 2] = pixel_color_b;
    xpos++;
}

static void inline put_pixel_rgb(int offset, UINT16 rgb_color) {
    PAIR sprite = do_sprites();
    if (sprite.b.h == 0) {
        set_pixel_color_rgb(rgb_color);
    } else {
        set_pixel_color(sprite.b.l);
    }
    screen[offset + xpos*3 + 0] = pixel_color_r;
    screen[offset + xpos*3 + 1] = pixel_color_g;
    screen[offset + xpos*3 + 2] = pixel_color_b;
    xpos++;
}

static void inline do_border(int offset, int size) {
    UINT16 color = (status & STATUS_ENABLE_CHRONI) ? border_color : 0;
    for(int i=0; i<size; i++) {
        put_pixel_rgb(offset, color);
    }
}

static void do_scan_text_attribs(UINT16 width, UINT8 line, bool cols80) {
    LOGV(LOGTAG, "do_scan_text_attribs lms:%04x attr:%04x line:%d\n", lms, attribs, line);

    UINT8 row;
    UINT8 bit;
    UINT8 foreground, background;

    int line_offset  = line & 7;
    int scan_width = cols80 ? width : (width/2);
    int pixel_offset = dl_scroll_fine_x;

    UINT32 char_origin = dl_mode_data_addr << 1;
    UINT32 attr_origin = dl_mode_attr_addr << 1;

    UINT32 char_addr = char_origin;
    UINT32 attr_addr = attr_origin;
    UINT8  line_wrap = 0xff;
    if (dl_scroll) {
        char_addr += dl_scroll_left;
        attr_addr += dl_scroll_left;
        line_wrap = dl_scroll_width - dl_scroll_left - 1;
    }

    for(int i=0; i<scan_width; i++) {
        if (i  == 0 || pixel_offset == 0) {
            LOGV(LOGTAG, "do_scan_text_attribs char:%04x attr:%04x\n", char_addr, attr_addr);

            UINT8 attrib = VRAM_BYTE(attr_addr);
            background = (attrib & 0xF0) >> 4;
            foreground = attrib & 0x0F;

            UINT8 c = VRAM_BYTE(char_addr);
            row = VRAM_BYTE(charset * CHARSET_PAGE + (c<<3) + line_offset);

            bit = 0x80 >> pixel_offset;

            if (line_wrap > 0) {
                attr_addr++;
                char_addr++;
                line_wrap--;
            } else {
                char_addr = char_origin;
                attr_addr = attr_origin;
                line_wrap = dl_scroll_width - 1;
            }
        }

        put_pixel(offset, row & bit ? foreground : background);
        if (!cols80) {
            put_pixel(offset, row & bit ? foreground : background);
        }

        pixel_offset = (pixel_offset + 1) & 7;
        bit >>= 1;
    }
}

static void do_scan_tile_4bpp(UINT16 width, UINT8 line) {
    LOGV(LOGTAG, "do_scan_tile_4bpp line %d", line);

    UINT8  tile_color;
    UINT16 tile_data;

    UINT8  pixel_offset = dl_scroll_fine_x;
    UINT16 pixel_data = 0;
    UINT32 tile_origin = dl_mode_data_addr;
    UINT16 tile_addr   = dl_mode_data_addr;

    UINT8  line_wrap = 0;
    if (dl_scroll) {
        tile_addr += dl_scroll_left;
        line_wrap  = dl_scroll_width - dl_scroll_left - 1;
    }

    UINT16 line_offset = (line & 7) << 1;
    for(int i=0; i<width/2; i++) { // for each pixel
        if (i == 0 || pixel_offset == 0) {
            UINT16 tile = VRAM_DATA(tile_addr);

            tile_color = (tile & 0xf000) >> 12;
            tile_data  = (tile & 0x0fff) << 4;

            if (line_wrap > 0) {
                tile_addr++;
                line_wrap--;
            } else {
                tile_addr = tile_origin;
                line_wrap = dl_scroll_width - 1;
            }
        }

        if (i == 0 || (pixel_offset & 3) == 0) {
            pixel_data = VRAM_DATA(tile_data + (pixel_offset >> 2) + line_offset);
            pixel_data >>= 4 * (pixel_offset & 3);
        } else {
            pixel_data >>= 4;
        }

        UINT8 pixel = (pixel_data & 0xF);
        UINT8 color = (tile_color << 4) | pixel;

        put_pixel(offset, color);
        put_pixel(offset, color);

        pixel_offset = (pixel_offset + 1) & 7;
    }
}

static void do_scan_bitmap_4bpp(UINT16 width, UINT8 line) {
    UINT8  pixel_offset = 0;
    UINT16 pixel_addr = dl_mode_data_addr;
    UINT16 pixel_data = 0;
    UINT8  bitmap_color = 0;

    for(int i=0; i<width/2; i++) { // for each pixel
        if ((pixel_offset & 3) == 0) {
            pixel_data = VRAM_DATA(pixel_addr);
            pixel_addr++;
        }

        UINT8 pixel = (pixel_data & 0xF);
        pixel_data >>= 4;

        UINT8 color = (bitmap_color << 4) | pixel;

        put_pixel(offset, color);
        put_pixel(offset, color);

        pixel_offset = (pixel_offset + 1) & 3;
    }
}


static UINT8 words_per_scan[] = {
    0, 40, 20, 32, 80
};

static UINT8 words_per_scan_narrow[] = {
    0, 32, 16, 32, 64
};

static UINT8 lines_per_mode[] = {
    0, 8, 8, 8, 1
};

// scanlines are drawn as follows:
// 11 - SCREEN_YBORDER skipped
// SCREEN_YBORDER drawn as full border
// 240 lines max drawn normally
// SCREEN_YBORDER drawn as full border
// 11 - SCREEN_YBORDER skipped

#define SCANLINES_TOTAL 262
#define SCANLINES_DISPLAY 240
#define SCANLINES_BLANK ((SCANLINES_TOTAL - SCANLINES_DISPLAY) / 2)
#define SCANLINES_BLANK_TOP (SCANLINES_BLANK - SCREEN_YBORDER)

int output_scanline;

void chroni_frame_start() {
    status |= STATUS_VBLANK; // make sure to start first frame with vblank flag on
    output_scanline = 0;
    memscan = 0;
    ypos = 0;

    dl_pos = 0;
    dl_scanlines = 0;
}

void chroni_frame_end() {
    if (debug_skip_frames > 0) debug_skip_frames--;
}

bool chroni_frame_is_complete() {
    return output_scanline == SCANLINES_TOTAL;
}

bool is_output_scanline_visible() {
    return output_scanline >= SCANLINES_BLANK_TOP && output_scanline < (SCANLINES_TOTAL - SCANLINES_BLANK_TOP);
}

bool is_output_scanline_border() {
    return output_scanline < SCANLINES_BLANK || output_scanline > (SCANLINES_TOTAL - SCANLINES_BLANK);
}

void chroni_scanline_back_porch() {
    do_scan_start();

    status |= STATUS_HBLANK; // make sure to start first scanline with hblank flag on

    offset = memscan * screen_pitch;
    xpos = 0;
    if (!is_output_scanline_border()) {
        process_dl();
    }
    if (is_output_scanline_visible()) {
        do_border(offset, dl_narrow ? SCREEN_XBORDER_NARROW : SCREEN_XBORDER);
    }
    LOGV(LOGTAG, "chroni_scanline_back_porch complete output_scanline:%d ypos:%d", output_scanline, ypos);
}

void chroni_scanline_display() {
    status &= (255 - STATUS_HBLANK);
    cpuexec_nmi(0);

    LOGV(LOGTAG, "display scanline:%d mode_scanline:%d\n", output_scanline, dl_mode_scanline);

    if (is_output_scanline_visible()) {
        UINT16 width = dl_narrow ? SCREEN_XRES_NARROW : SCREEN_XRES;
        if (is_output_scanline_border()) {
            do_border(offset, width);
        } else {
            do_scanline(width);
        }
    }
    LOGV(LOGTAG, "chroni_scanline_display complete output_scanline:%d ypos:%d", output_scanline, ypos);
}

void chroni_scanline_front_porch() {
    if (is_output_scanline_visible()) {
        do_border(offset, dl_narrow ? SCREEN_XBORDER_NARROW : SCREEN_XBORDER);

        if (!is_output_scanline_border()) ypos++;
        memscan++;
    }

    bool is_vblank_start = output_scanline == (SCANLINES_BLANK + SCANLINES_DISPLAY);
    if (is_vblank_start) {
        status |= STATUS_VBLANK;
    } else {
        status |= STATUS_HBLANK;
    }

    bool is_hblank_interrupt = output_scanline == (SCANLINES_BLANK + scanline_interrupt);

    CPU_RESUME();
    if ((is_hblank_interrupt || is_vblank_start) && (status & STATUS_ENABLE_INTS)) {
        if (is_vblank_start) {
            LOGV(LOGTAG, "fire VBI at output_scanline:%d ypos:%d", output_scanline, ypos);
        } else {
            LOGV(LOGTAG, "fire DLI at output_scanline:%d ypos:%d", output_scanline, ypos);
        }
        cpuexec_nmi(1);
    }

    do_scan_end();

    LOGV(LOGTAG, "chroni_scanline_front_porch complete output_scanline:%d ypos:%d", output_scanline, ypos);

    output_scanline++;
}

static void process_dl() {
    if (dl_scanlines > 0) {
        dl_scanlines--;
    } else {
        dl_instruction = VRAM_DATA(dl + dl_pos);
        dl_scroll      = (dl_instruction & 0x2000) ? 1 : 0;
        dl_narrow      = (dl_instruction & 0x1000) ? 1 : 0;
        dl_mode        = (dl_instruction & 0x0f00) >> 8;
        dl_scanlines   = (dl_instruction & 0x00ff) - 1;
        LOGV(LOGTAG, "read dl mode:%02x scanlines:%d scroll:%s\n", dl_mode, dl_scanlines, dl_scroll ? "true" : "false");
        if (dl_mode == 0x0f) {
            dl_scanlines = 0;
        } else if (dl_mode != 0) {
            dl_pos++;
            lms = VRAM_DATA(dl + dl_pos++);
            if (dl_mode < 3) {
                attribs = VRAM_DATA(dl + dl_pos++);
                LOGV(LOGTAG, "DL LMS %04X ATTR %04X", lms, attribs);
            }
            dl_mode_scanlines = lines_per_mode[dl_mode] - 1;
            dl_mode_scanline = 0;
            if (dl_scroll) {
                UINT16 scroll_window = VRAM_DATA(dl + dl_pos++);
                dl_scroll_width  = BYTE_L(scroll_window);
                dl_scroll_height = BYTE_H(scroll_window);

                UINT16 scroll_position = VRAM_DATA(dl + dl_pos++);
                dl_scroll_left = BYTE_L(scroll_position);
                dl_scroll_top  = BYTE_H(scroll_position);

                UINT16 scroll_fine = VRAM_DATA(dl + dl_pos++);
                dl_scroll_fine_x = BYTE_L(scroll_fine) & 7;
                dl_scroll_fine_y = BYTE_H(scroll_fine) & 7;

                dl_mode_pitch = dl_scroll_width / (dl_mode == 3 ? 1 : 2);

                UINT16 first_row_offset = dl_mode_pitch * dl_scroll_top;
                dl_mode_data_addr = lms     + first_row_offset;
                dl_mode_attr_addr = attribs + first_row_offset;
                dl_row_wrap = dl_scroll_height - dl_scroll_top - 1;
                dl_mode_scanline = dl_scroll_fine_y;
            } else {
                dl_row_wrap = 0xffff;
                dl_mode_data_addr = lms;
                dl_mode_attr_addr = attribs;
                dl_mode_pitch = dl_narrow ? words_per_scan_narrow[dl_mode] : words_per_scan[dl_mode];
            }
        }
    }
}

static void do_scanline(UINT16 width) {
    if (!(status & STATUS_ENABLE_CHRONI)) return;

    LOGV(LOGTAG, "do scanline:%d of %d\n", dl_mode_scanline, dl_mode_scanlines);
    if (dl_mode == 0 || dl_mode == 0xf) {
        do_border(offset, width);
    } else {
        switch(dl_mode) {
        case 0x1: do_scan_text_attribs(width, dl_mode_scanline, TRUE); break;
        case 0x2: do_scan_text_attribs(width, dl_mode_scanline, FALSE); break;
        case 0x3: do_scan_tile_4bpp(width, dl_mode_scanline); break;
        case 0x4: do_scan_bitmap_4bpp(width, dl_mode_scanline); break;
        }

        if (dl_mode_scanline++ == dl_mode_scanlines) {
            if (dl_row_wrap > 0) {
                dl_mode_data_addr  += dl_mode_pitch;
                dl_mode_attr_addr  += dl_mode_pitch;
                dl_row_wrap--;
            } else {
                dl_mode_data_addr = lms;
                dl_mode_attr_addr = attribs;
                dl_row_wrap = dl_scroll_height - 1;
            }
            dl_mode_scanline = 0;
        }
    }
}

static void init_rgb565_table() {
    for(int c=0; c<0x10000; c++) {
        UINT8 r = ((c & 0xF800) >> 11) * (256 / 32);
        UINT8 g = ((c & 0X07E0) >> 5)  * (256 / 64);
        UINT8 b = (c & 0X001F) * (256 / 32);

        rgb565[c*3 + 0] = b;
        rgb565[c*3 + 1] = g;
        rgb565[c*3 + 2] = r;
    }
}

void chroni_init() {
    trace_enabled = TRUE;
    init_rgb565_table();
    chroni_reset();
}

