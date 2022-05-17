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

#define VRAM_WORD(addr) (WORD(VRAM_DATA(addr), VRAM_DATA(addr+1)))
#define VRAM_PTR(addr) (VRAM_WORD(addr) << 1)
#define VRAM_PTR_LONG(addr) (VRAM_WORD(addr) + ((vram[addr+2] & 1) << 16))
#define VRAM_DATA(addr) (vram[(addr) & 0x1FFFF])

#define VRAM_MAX 128*1024
#define PALETTE_SIZE 256

UINT8  vram[VRAM_MAX];
UINT16 palette[PALETTE_SIZE];

#define PAGE_SIZE       0x4000
#define PAGE_SHIFT      14
#define PAGE_SHIFT_HIGH (PAGE_SHIFT-8)
#define PAGE_BASE(x)    (x << PAGE_SHIFT)

static UINT32 vram_write_address;
static UINT32 vram_write_address_aux;

static UINT16 scanline_interrupt;
static UINT8  page;
static UINT32 offset;

static UINT32 dl;
static UINT16 lms = 0;
static UINT16 attribs = 0;
static UINT16 ypos, xpos, memscan;

int dl_pos;
int dl_scanlines;
int dl_pitch;
UINT8 dl_instruction;
UINT8 dl_mode;
UINT8 dl_line;

static UINT16 border_color;
static UINT32 subpals;

#define CHARSET_PAGE 1024
static UINT8  charset;
static UINT32 sprites;

static UINT32 tileset_small;
static UINT32 tileset_big;

// this is an RGB565 -> RGB888 conversion array for emulation only
static UINT8 rgb565[0x10000 * 3];
static UINT8 pixel_color_r;
static UINT8 pixel_color_g;
static UINT8 pixel_color_b;

#define STATUS_VBLANK         0x80
#define STATUS_HBLANK         0x40
#define STATUS_IS_EMULATOR    0x20
#define STATUS_ENABLE_CHRONI  0x10
#define STATUS_ENABLE_SPRITES 0x08
#define STATUS_ENABLE_INTS    0x04

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

static UINT8 vscroll;
static UINT8 hscroll;

static UINT8 clock_multiplier;
static UINT8 clock_multipliers[] = {1, 2, 4, 8};

static void do_scanline();

void chroni_reset() {
	status = 0;
	dl = 0;
	charset = 0;
	sprites = 0;
	tileset_small = 0;
	vscroll = 0;
	hscroll = 0;
	scanline_interrupt = 0;
	clock_multiplier = clock_multipliers[0];

	autoinc = AUTOINC_INC;

	srand(time(NULL));
}

void chroni_vram_write(UINT16 index, UINT8 value) {
	LOGV(LOGTAG, "vram write %04X = %02X", index, value);
	VRAM_DATA(PAGE_BASE(page) + index) = value;
}

UINT8 chroni_vram_read(UINT16 index) {
	return VRAM_DATA(PAGE_BASE(page) + index);
}

UINT8 chroni_vram_read_linear(UINT32 index) {
	return VRAM_DATA(index & 0x1FFFF);
}

static void reg_addr_low(UINT32 *reg, UINT8 value) {
	*reg = (*reg & 0xFFFE00) | (value << 1);
}

static void reg_addr_high(UINT32 *reg, UINT8 value) {
	*reg = (*reg & 0x001FF) | (value << 9);
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

	LOGV(LOGTAG, "chroni reg write: 0x%04X = 0x%02X", index, value);
	switch (index) {
	case 0:
		reg_addr_low(&dl, value);
		break;
	case 1:
		reg_addr_high(&dl, value);
		break;
	case 2:
		charset = value;
		break;
	case 4:
		palette_index = value;
		palette_value_state = 0;
		break;
	case 5:
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
		vram_write_address = (vram_write_address & 0x1FF00) | value;
		break;
	case 0x07:
		vram_write_address = (vram_write_address & 0x100FF) | (value << 8);
		break;
	case 0x08:
		vram_write_address = (vram_write_address & 0x0FFFF) | ((value & 1) << 16);
		break;
	case 0x09:
		vram[vram_write_address] = value;
		vaddr_autoinc();
		break;
	case 0x0a:
		vram_write_address_aux = (vram_write_address_aux & 0x1FF00) | value;
		break;
	case 0x0b:
		vram_write_address_aux = (vram_write_address_aux & 0x100FF) | (value << 8);
		break;
	case 0x0c:
		vram_write_address_aux = (vram_write_address_aux & 0x0FFFF) | ((value & 1) << 16);
		break;
	case 0x0d:
		vram[vram_write_address_aux] = value;
		vaddr_aux_autoinc();
		break;
	case 0x0e:
		page = value & 0x07;
		break;
	case 0x11:
		CPU_HALT();
		break;
	case 0x12:
		status = (status & 0xC0) | (value & 0x3F);
		break;
	case 0x14:
		reg_addr_low(&sprites, value);
		break;
	case 0x15:
		reg_addr_high(&sprites, value);
		break;
	case 0x16:
		reg_addr_low(&tileset_small, value);
		break;
	case 0x17:
		reg_addr_high(&tileset_small, value);
		break;
	case 0x18:
		reg_addr_low(&tileset_big, value);
		break;
	case 0x19:
		reg_addr_high(&tileset_big, value);
		break;
	case 0x1a:
		reg_low(&border_color, value);
		break;
	case 0x1b:
		reg_high(&border_color, value);
		break;
	case 0x20:
		hscroll = value;
		break;
	case 0x21:
		vscroll = value;
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
		vram_write_address = (vram_write_address & 0x1FE00) | (value << 1);
		break;
	case 0x27:
		vram_write_address = (vram_write_address & 0x001FF) | (value << 9);
		break;
	case 0x28:
		vram_write_address_aux = (vram_write_address_aux & 0x1FE00) | (value << 1);
		break;
	case 0x29:
		vram_write_address_aux = (vram_write_address_aux & 0x001FF) | (value << 9);
		break;
	case 0x2a:
		autoinc = value;
		break;
	}
}

UINT8 chroni_register_read(UINT8 index) {
	switch(index) {
	case 0x06 : return (vram_write_address & 0x000FF);
	case 0x07 : return (vram_write_address & 0x0FF00) >> 8;
	case 0x08 : return (vram_write_address & 0x10000) >> 16;
	case 0x09 : {
		UINT8 value = vram[vram_write_address];
		vaddr_autoinc();
		return value;
	}
	case 0x0a : return (vram_write_address_aux & 0x000FF);
	case 0x0b : return (vram_write_address_aux & 0x0FF00) >> 8;
	case 0x0c : return (vram_write_address_aux & 0x10000) >> 16;
	case 0x0d : {
		UINT8 value = vram[vram_write_address_aux];
		vaddr_aux_autoinc();
		return value;
	}
	case 0x10 : return ypos;
	case 0x1a : return (border_color & 0x00ff);
	case 0x1b : return border_color >> 8;
	case 0x12 : return status | STATUS_IS_EMULATOR;
	case 0x20 : return hscroll;
	case 0x21 : return vscroll;
	case 0x25 : return rand() & 0xFF;
	case 0x26 : return ((vram_write_address+1) & 0x001FF) >> 1;
	case 0x27 : return ((vram_write_address+1) & 0x01E00) >> (8+1);
	case 0x28 : return ((vram_write_address_aux+1) & 0x001FF) >> 1;
	case 0x29 : return ((vram_write_address_aux+1) & 0x01E00) >> (8+1);
	case 0x2a : return autoinc;
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
		sprite_scanlines[s] = SPRITE_SCAN_INVALID; // asume invalid sprite for this scan
		if (!(status & STATUS_ENABLE_SPRITES)) continue;

		UINT16 sprite_attrib = VRAM_DATA(sprites + SPRITES_ATTR + s*2);
		if ((sprite_attrib & SPRITE_ATTR_ENABLED) == 0) continue;

		int sprite_y = VRAM_WORD(sprites + SPRITES_Y + s*2) - 16;

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

		int sprite_x = (VRAM_WORD(sprites + SPRITES_X + s*2) - 24) * 2;

		int sprite_pixel_x = xpos/2 - sprite_x;
		if (sprite_pixel_x < 0) continue; // not yet
		if (sprite_pixel_x >=16) { // not anymore
			sprite_scanlines[s] = SPRITE_SCAN_INVALID;
			continue;
		}

		int sprite_pointer = VRAM_PTR(sprites + s*2);

		sprite_data = VRAM_DATA(sprite_pointer
				+ (sprite_scanline << 3)
				+ (sprite_pixel_x  >> 1));
		sprite_data = (sprite_pixel_x & 1) == 0 ?
				sprite_data >> 4 :
				sprite_data & 0xF;
		if (sprite_data == 0) continue;

		UINT16 sprite_attrib = VRAM_DATA(sprites + SPRITES_ATTR + s*2);
		int sprite_palette = sprite_attrib & 0x0F;

		dot_color = VRAM_DATA(sprites + SPRITES_COLOR + sprite_palette*16 + sprite_data);
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

static void do_scan_text_attribs(bool use_hscroll, bool use_vscroll, UINT8 pitch, UINT8 line, bool cols80) {
	LOGV(LOGTAG, "do_scan_text_attribs line %d", line);

	UINT8 row;
	UINT8 bit;
	UINT8 foreground, background;

	int pixel_offset = use_hscroll ? (hscroll & 0x3F) : 0;
	int scan_offset  = use_vscroll ? (vscroll & 0x3F) : 0;
	int line_offset  = (line + scan_offset) & 7;
	int char_offset  = (pixel_offset >> 3) + ((line + scan_offset) >> 3) * pitch;

	int width = cols80 ? SCREEN_XRES : (SCREEN_XRES/2);

	for(int i=0; i<width; i++) {
		if (i  == 0 || (pixel_offset & 7) == 0) {
			LOGV(LOGTAG, "do_scan_text_attribs char_offset: %d", char_offset);

			UINT8 attrib = VRAM_DATA(attribs + char_offset);
			background = (attrib & 0xF0) >> 4;
			foreground = attrib & 0x0F;

			UINT8 c = VRAM_DATA(lms + char_offset);
			row = VRAM_DATA(charset * CHARSET_PAGE + c*8 + line_offset);

			bit = 0x80 >> (pixel_offset & 7);

			char_offset++;
		}


		put_pixel(offset, row & bit ? foreground : background);
		if (!cols80) {
			put_pixel(offset, row & bit ? foreground : background);
		}

		pixel_offset++;
		bit >>= 1;
	}
}

static void do_scan_text_attribs_double(UINT8 pitch, UINT8 line) {
	LOGV(LOGTAG, "do_scan_text_attribs double line %d", line);

	UINT8 row;
	UINT8 foreground, background;

    int scan_offset  = 0;
    int line_offset  = (line + scan_offset) & 7;
    int char_offset  = ((line + scan_offset) >> 3) * pitch;

	bool first = TRUE;
	for(int i=0; i<SCREEN_XRES/2; i++) {
		if (i % 0x10 == 0) {
			UINT8 attrib = VRAM_DATA(attribs + char_offset);
			background = (attrib & 0xF0) >> 4;
			foreground = attrib & 0x0F;

			UINT8 c = VRAM_DATA(lms + char_offset);
			row = VRAM_DATA(charset * CHARSET_PAGE + c*8 + line_offset);
			char_offset++;
		}

		put_pixel(offset, row & 0x80 ? foreground : background);
		put_pixel(offset, row & 0x80 ? foreground : background);
		if (!first) row <<= 1;
		first = !first;
	}
}

static void do_scan_tile_wide_2bpp(UINT8 line) {
	LOGV(LOGTAG, "do_scan_tile_wide_2bpp line %d", line);

	UINT8  subpal = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	int tile_offset = 0;
	for(int i=0; i<SCREEN_XRES/2; i++) {
		if ((i & 7) == 0) {
			subpal = VRAM_DATA(attribs + tile_offset);

			UINT8 tile = VRAM_DATA(lms + tile_offset);
			pixel_data = VRAM_DATA(tileset_small + tile*8 + line);
			tile_offset++;
		}

		if ((i & 1) == 0) {
			pixel   = (pixel_data   & 0xC0) >> 6;
			pixel_data <<= 2;
		}

		UINT8 color = VRAM_DATA(subpals + subpal*4 + pixel);

		put_pixel(offset, color);
		put_pixel(offset, color);
	}
}

static void do_scan_tile_wide_4bpp(UINT8 line) {
	LOGV(LOGTAG, "do_scan_tile_wide_4bpp line %d", line);

	UINT8  subpal = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	UINT8  tile = 0;
	UINT8  tile_data;
	int tile_offset = 0;
	for(int i=0; i<SCREEN_XRES/2; i++) {
		if ((i & 31) == 0) {
			subpal = VRAM_DATA(attribs + tile_offset);
			tile    = VRAM_DATA(lms + tile_offset);
			tile_data = 0;

			tile_offset++;
		}

		if ((i & 3) == 0) {
			pixel_data = VRAM_DATA(tileset_big + tile*128 + line*8 + tile_data);
			tile_data++;
		}

		if ((i & 1) == 0) {
			pixel   = (pixel_data & 0xF0) >> 4;
			pixel_data <<= 4;
		}

		UINT8 color = VRAM_DATA(subpals + subpal*16 + pixel);

		put_pixel(offset, color);
		put_pixel(offset, color);
	}
}

static void do_scan_tile_4bpp(UINT8 line) {
	LOGV(LOGTAG, "do_scan_tile_wide_4bpp line %d", line);

	UINT8  subpal = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	UINT8  tile = 0;
	UINT8  tile_data;
	int tile_offset = 0;
	for(int i=0; i<SCREEN_XRES/2; i++) {
		if ((i & 15) == 0) {
			subpal = VRAM_DATA(attribs + tile_offset);
			tile    = VRAM_DATA(lms + tile_offset);
			tile_data = 0;

			tile_offset++;
		}

		if ((i & 1) == 0) {
			pixel_data = VRAM_DATA(tileset_big + tile*128 + line*8 + tile_data);
			tile_data++;
		}

		pixel   = (pixel_data & 0xF0) >> 4;
		pixel_data <<= 4;

		UINT8 color = VRAM_DATA(subpals + subpal*16 + pixel);

		put_pixel(offset, color);
		put_pixel(offset, color);
	}
}


static void do_scan_pixels_2bpp() {
	LOGV(LOGTAG, "do_scan_pixels_2bpp line");

	UINT8  subpal = 0;
	UINT8  palette_data = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	UINT16 pixel_data_offset = 0;
	for(int i=0; i<SCREEN_XRES/2; i++) {
		if ((i & 3) == 0) {
			LOGV(LOGTAG, "vram offset: %05X pixel:%05X attrib:%05X",
					pixel_data_offset, lms+pixel_data_offset, attribs+pixel_data_offset);
			palette_data = VRAM_DATA(attribs + pixel_data_offset);
			pixel_data = VRAM_DATA(lms + pixel_data_offset);
			pixel_data_offset++;
		}

		pixel  = (pixel_data   & 0xC0) >> 6;
		subpal = (palette_data & 0xC0) >> 4;

		pixel_data <<= 2;
		palette_data <<= 2;

		UINT8 color = VRAM_DATA(subpals + subpal + pixel);
		LOGV(LOGTAG, "vram data subpals:%05X subpal:%04X pixel:%02X color:%02X",
			subpals, subpal, pixel, color);

		put_pixel(offset, color);
		put_pixel(offset, color);

	}
}


static void do_scan_pixels_4bpp() {
	LOGV(LOGTAG, "do_scan_pixels_4bpp line");

	UINT8  subpal = 0;
	UINT8  palette_data = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	UINT16 pixel_data_offset = 0;
	for(int i=0; i<SCREEN_XRES/2; i++) {
		if ((i & 1) == 0) {
			LOGV(LOGTAG, "vram offset: %05X pixel:%05X attrib:%05X",
					pixel_data_offset, lms+pixel_data_offset, attribs+pixel_data_offset);
			palette_data = VRAM_DATA(attribs + pixel_data_offset);
			pixel_data = VRAM_DATA(lms + pixel_data_offset);
			pixel_data_offset++;
		}

		pixel  = (pixel_data   & 0xF0) >> 4;
		subpal = (palette_data & 0xF0);

		pixel_data   <<= 4;
		palette_data <<= 4;

		UINT8 color = VRAM_DATA(subpals + subpal + pixel);
		LOGV(LOGTAG, "vram data subpals:%05X subpal:%04X pixel:%02X color:%02X",
			subpals, subpal, pixel, color);

		put_pixel(offset, color);
		put_pixel(offset, color);
	}
}

static void do_scan_pixels_wide_2bpp() {
	LOGV(LOGTAG, "do_scan_pixels_wide_2bpp line");

	UINT8  subpal = 0;
	UINT8  palette_data = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	UINT16 pixel_data_offset = 0;
	for(int i=0; i<SCREEN_XRES/2; i++) {
		if ((i & 7) == 0) {
			LOGV(LOGTAG, "vram offset: %05X pixel:%05X attrib:%05X",
					pixel_data_offset, lms+pixel_data_offset, attribs+pixel_data_offset);
			palette_data = VRAM_DATA(attribs + pixel_data_offset);
			pixel_data = VRAM_DATA(lms + pixel_data_offset);
			pixel_data_offset++;
		}

		if ((i & 1) == 0) {
			pixel  = (pixel_data   & 0xC0) >> 6;
			subpal = (palette_data & 0xC0) >> 2;

			pixel_data <<= 2;
			palette_data <<= 2;
		}

		UINT8 color = VRAM_DATA(subpals + subpal + pixel);
		LOGV(LOGTAG, "vram data subpals:%05X subpal:%04X pixel:%02X color:%02X",
			subpals, subpal, pixel, color);

		put_pixel(offset, color);
		put_pixel(offset, color);

	}
}

static void do_scan_pixels_wide_4bpp() {
	LOGV(LOGTAG, "do_scan_pixels_wide_4bpp line");

	UINT8  subpal = 0;
	UINT8  palette_data = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	UINT16 pixel_data_offset = 0;
	for(int i=0; i<SCREEN_XRES/2; i++) {
		if ((i & 3) == 0) {
			LOGV(LOGTAG, "vram offset: %05X pixel:%05X attrib:%05X",
					pixel_data_offset, lms+pixel_data_offset, attribs+pixel_data_offset);
			palette_data = VRAM_DATA(attribs + pixel_data_offset);
			pixel_data = VRAM_DATA(lms + pixel_data_offset);
			pixel_data_offset++;
		}

		if ((i & 1) == 0) {
			pixel  = (pixel_data   & 0xF0) >> 4;
			subpal = (palette_data & 0xF0);

			pixel_data   <<= 4;
			palette_data <<= 4;
		}

		UINT8 color = VRAM_DATA(subpals + subpal + pixel);
		LOGV(LOGTAG, "vram data subpals:%05X subpal:%04X pixel:%02X color:%02X",
			subpals, subpal, pixel, color);

		put_pixel(offset, color);
		put_pixel(offset, color);
	}
}

static void do_scan_pixels_1bpp() {
	LOGV(LOGTAG, "do_scan_pixels_1bpp line");

	UINT8  subpal = 0;
	UINT8  palette_data = 0;
	UINT8  pixel = 0;
	UINT8  pixel_data = 0;
	UINT16 pixel_data_offset = 0;
	for(int i=0; i<SCREEN_XRES/2; i++) {
		if ((i & 7) == 0) {
			LOGV(LOGTAG, "vram offset: %05X pixel:%05X attrib:%05X",
					pixel_data_offset, lms+pixel_data_offset, attribs+pixel_data_offset);
			palette_data = VRAM_DATA(attribs + pixel_data_offset);
			pixel_data = VRAM_DATA(lms + pixel_data_offset);
			pixel_data_offset++;
		}

		pixel  = (pixel_data   & 0x80) >> 7;
		subpal = (palette_data & 0x80) >> 6;

		pixel_data   <<= 1;
		palette_data <<= 1;

		UINT8 color = VRAM_DATA(subpals + subpal + pixel);
		LOGV(LOGTAG, "vram data subpals:%05X subpal:%04X pixel:%02X color:%02X",
			subpals, subpal, pixel, color);

		put_pixel(offset, color);
		put_pixel(offset, color);
	}
}

static UINT8 bytes_per_scan[] = {
		0, 0, 80, 40,
		20, 20, 40, 40,
		80, 80, 40, 80,
		160, 40, 10, 20
};

static UINT8 lines_per_mode[] = {
		0, 0, 8, 8,
		8, 16, 1, 2,
		1, 2, 1, 1,
		1, 8, 16, 16
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
	if (is_output_scanline_visible()) {
		do_border(offset, SCREEN_XBORDER);
	}
	LOGV(LOGTAG, "chroni_scanline_back_porch complete output_scanline:%d ypos:%d", output_scanline, ypos);
}

void chroni_scanline_display() {
	status &= (255 - STATUS_HBLANK);
	cpuexec_nmi(0);

	if (is_output_scanline_visible()) {
		if (is_output_scanline_border()) {
			do_border(offset, SCREEN_XRES);
		} else {
			do_scanline();
		}
	}
	LOGV(LOGTAG, "chroni_scanline_display complete output_scanline:%d ypos:%d", output_scanline, ypos);
}

void chroni_scanline_front_porch() {
	if (is_output_scanline_visible()) {
		do_border(offset, SCREEN_XBORDER);

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
		dl_pos++;
		if (dl_instruction == 0x41) {
			dl_pos--;
		} else {
			dl_mode = dl_instruction & 0x0F;
			if (dl_mode == 0) {
				dl_scanlines = 1 + ((dl_instruction & 0x70) >> 4);
				LOGV(LOGTAG, "DL do_scan_blank lines %d", dl_scanlines);
			} else if (dl_instruction & 64) {
				lms     = VRAM_PTR(dl + dl_pos);
				dl_pos+=2;
				attribs = VRAM_PTR(dl + dl_pos);
				dl_pos+=2;
				LOGV(LOGTAG, "DL LMS %04X ATTR %04X", lms, attribs);

				dl_scanlines = lines_per_mode[dl_mode] - 1;
				dl_pitch = bytes_per_scan[dl_mode];
				dl_line = 0;
			} else {
				dl_scanlines = lines_per_mode[dl_mode] - 1;
			}
		}
	}
}


static void do_scanline() {
	if (!(status & STATUS_ENABLE_CHRONI)) return;

	process_dl();

	if (dl_instruction == 0x41 || dl_mode == 0) {
		do_border(offset, SCREEN_XRES);
	} else {
		switch(dl_mode) {
			case 0x2: do_scan_text_attribs(FALSE, FALSE, dl_pitch, dl_line, TRUE); break;
			case 0x3: do_scan_text_attribs(FALSE, FALSE, dl_pitch, dl_line, FALSE); break;
			case 0x4: do_scan_text_attribs_double(dl_pitch, dl_line); break;
			case 0x5: do_scan_text_attribs_double(dl_pitch, dl_line >> 1); break;
			case 0x6: do_scan_pixels_wide_2bpp(); break;
			case 0x7: do_scan_pixels_wide_2bpp(); break;
			case 0x8: do_scan_pixels_wide_4bpp(); break;
			case 0x9: do_scan_pixels_wide_4bpp(); break;
			case 0xA: do_scan_pixels_1bpp(); break;
			case 0xB: do_scan_pixels_2bpp(); break;
			case 0xC: do_scan_pixels_4bpp(); break;
			case 0xD: do_scan_tile_wide_2bpp(dl_line); break;
			case 0xE: do_scan_tile_wide_4bpp(dl_line); break;
			case 0xF: do_scan_tile_4bpp(dl_line); break;
		}

		dl_line++;
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

